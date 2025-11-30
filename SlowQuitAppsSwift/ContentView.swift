//
//  ContentView.swift
//  SlowQuitAppsSwift
//
//  Created by yaotutu on 2025/11/28.
//

import SwiftUI
import Combine
import AppKit
import ApplicationServices

/// 菜单栏触发的唯一设置界面, 控制辅助功能授权与 Cmd+Q 监听状态。
struct ContentView: View {

    @ObservedObject var controller: CmdQController

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: controller.isMonitoring ? "keyboard" : "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("SlowQuitAppsSwift")
                .font(.title2)
            Text(statusMessage)
                .font(.callout)
                .foregroundColor(controller.hasAccessibilityPermission ? .green : .orange)

            if controller.hasAccessibilityPermission {
                monitoringControls
            } else {
                permissionInstructions
            }

            Divider()
            Button("退出 SlowQuitAppsSwift") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }

    /// 权限已授予时的操作区。
    private var monitoringControls: some View {
        VStack(spacing: 8) {
            if controller.isMonitoring {
                Button("停止监听") {
                    controller.stopMonitoring()
                }
            } else {
                Button("开始监听") {
                    controller.startMonitoring()
                }
            }
            Text("拥有辅助功能权限，Cmd+Q 事件将被拦截用于自定义延迟逻辑。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("长按时长: \(controller.holdDuration, specifier: "%.1f") 秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $controller.holdDuration, in: 0.5...5, step: 0.5)
            }
        }
    }

    /// 权限缺失时的引导操作。
    private var permissionInstructions: some View {
        VStack(spacing: 8) {
            Text("需要在 系统设置 → 隐私与安全性 → 辅助功能 中勾选 SlowQuitAppsSwift。")
                .font(.footnote)
                .multilineTextAlignment(.center)

            Button("请求辅助功能权限") {
                controller.requestAccessibilityPermission()
            }

            Button("重新检测权限") {
                controller.checkAccessibilityPermission()
            }

            Button("打开辅助功能设置") {
                controller.openAccessibilitySettings()
            }
        }
    }

    private var statusMessage: String {
        if controller.hasAccessibilityPermission {
            return controller.isMonitoring ? "监听 Cmd+Q 中..." : "可以开始监听 Cmd+Q"
        }
        return "等待授权辅助功能权限"
    }
}

#Preview {
    ContentView(controller: CmdQController())
}

// MARK: - Cmd+Q 控制器

/// 统一管理辅助功能授权、CGEventTap、以及全局圆环 overlay。
@MainActor
final class CmdQController: ObservableObject {

    @Published var isMonitoring = false
    @Published var hasAccessibilityPermission = false

    private var eventMonitor: EventMonitor?
    private let holdOverlayController = HoldOverlayWindowController()
    @Published var holdDuration: TimeInterval = 1.0 {
        didSet {
            eventMonitor?.holdDuration = holdDuration
        }
    }

    init() {
        DispatchQueue.main.async {
            self.checkAccessibilityPermission(autoStart: true)
        }
    }

    func checkAccessibilityPermission(autoStart: Bool = false) {
        let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [promptKey: NSNumber(value: false)] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityPermission = granted

        if granted {
            if autoStart || isMonitoring {
                startMonitoring()
            }
        } else {
            stopMonitoring()
        }
    }

    func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [promptKey: NSNumber(value: true)] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.checkAccessibilityPermission(autoStart: true)
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func startMonitoring() {
        guard hasAccessibilityPermission else { return }
        guard !isMonitoring else { return }

        let monitor = EventMonitor(holdDuration: holdDuration)
        monitor.onCmdQHoldStart = { [weak self] in
            guard let self = self else { return }
            self.holdOverlayController.startHold(duration: self.holdDuration)
        }
        monitor.onCmdQHoldCancel = { [weak self] in
            self?.holdOverlayController.cancelHold()
        }
        monitor.onCmdQHoldComplete = { [weak self] in
            self?.holdOverlayController.completeHold()
        }

        monitor.start()
        eventMonitor = monitor
        isMonitoring = true
    }

    func stopMonitoring() {
        eventMonitor?.stop()
        eventMonitor = nil
        isMonitoring = false
        holdOverlayController.forceHide()
    }
}

// MARK: - 全局圆环 Overlay 控制

@MainActor
private final class HoldOverlayState: ObservableObject {
    @Published var progressRatio: Double = 0
    @Published var durationText: String = ""
}

private struct HoldOverlayView: View {
    @ObservedObject var state: HoldOverlayState

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 148, height: 148)
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)

            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 8)
                .frame(width: 140, height: 140)

            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(state.progressRatio, 1))))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.orange, .red, .pink]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 140, height: 140)

            VStack(spacing: 4) {
                Text("按住 Cmd+Q")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                Text(state.durationText)
                    .font(.title2.monospacedDigit())
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
        .padding(12)
    }
}

@MainActor
final class HoldOverlayWindowController: ObservableObject {

    private let state = HoldOverlayState()
    private lazy var hostingController = NSHostingController(rootView: HoldOverlayView(state: state))
    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 144, height: 144),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 144, height: 144)
        panel.contentViewController = hostingController
        return panel
    }()

    private var progressTimer: Timer?
    private var holdStartDate: Date?
    private var holdDuration: TimeInterval = 1.0

    func startHold(duration: TimeInterval) {
        holdDuration = duration
        holdStartDate = Date()
        state.progressRatio = 0
        state.durationText = String(format: "%.1f 秒", duration)
        showPanelIfNeeded()
        startTimer()
    }

    func cancelHold() {
        hidePanel()
    }

    func completeHold() {
        state.progressRatio = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.hidePanel()
        }
    }

    func forceHide() {
        hidePanel()
    }

    private func showPanelIfNeeded() {
        updatePanelFrame()
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func hidePanel() {
        progressTimer?.invalidate()
        progressTimer = nil
        holdStartDate = nil
        state.progressRatio = 0
        panel.orderOut(nil)
    }

    private func startTimer() {
        progressTimer?.invalidate()
        let timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in
            self?.handleTick()
        }
        progressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleTick() {
        guard let start = holdStartDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        if holdDuration > 0 {
            state.progressRatio = min(1, elapsed / holdDuration)
            let remaining = max(0, holdDuration - elapsed)
            state.durationText = String(format: "%.1f 秒", remaining)
        } else {
            state.progressRatio = 1
            state.durationText = "0.0 秒"
        }
        updatePanelFrame()
    }

    private func updatePanelFrame() {
        let cursor = NSEvent.mouseLocation
        let size = panel.frame.size
        let targetScreen = NSScreen.screens.first { NSMouseInRect(cursor, $0.frame, false) } ?? NSScreen.main

        guard let screen = targetScreen else { return }
        let origin = CGPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        )

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
