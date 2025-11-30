//
//  ContentView.swift
//  SlowQuitAppsSwift
//
//  Created by yaotutu on 2025/11/28.
//

import SwiftUI
import AppKit
import ApplicationServices

/// 主界面, 展示辅助功能权限状态并提供 Cmd+Q 监听控制。
struct ContentView: View {

    /// 事件监听器实例, 通过 CGEventTap 监控全局 Cmd+Q。
    @State private var eventMonitor: EventMonitor?
    /// 当前是否已经开启监听。
    @State private var isMonitoring = false
    /// 是否拥有辅助功能授权。
    @State private var hasAccessibilityPermission = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isMonitoring ? "keyboard" : "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("SlowQuitAppsSwift")
                .font(.title2)
            Text(statusMessage)
                .font(.callout)
                .foregroundColor(hasAccessibilityPermission ? .green : .orange)

            if hasAccessibilityPermission {
                monitoringControls
            } else {
                permissionInstructions
            }
        }
        .padding()
        .onAppear {
            checkAccessibilityPermission()
        }
    }

    /// 当权限已授予时显示的开始/停止按钮与提示。
    private var monitoringControls: some View {
        VStack(spacing: 8) {
            if isMonitoring {
                Button("停止监听") {
                    stopMonitoring()
                }
            } else {
                Button("开始监听") {
                    startMonitoring()
                }
            }
            Text("拥有辅助功能权限，Cmd+Q 事件将被拦截用于自定义延迟逻辑。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }

    /// 当权限缺失时显示的说明与操作按钮。
    private var permissionInstructions: some View {
        VStack(spacing: 8) {
            Text("需要在 系统设置 → 隐私与安全性 → 辅助功能 中勾选 SlowQuitAppsSwift。")
                .font(.footnote)
                .multilineTextAlignment(.center)

            Button("请求辅助功能权限") {
                requestAccessibilityPermission()
            }

            Button("重新检测权限") {
                checkAccessibilityPermission()
            }

            Button("打开辅助功能设置") {
                openAccessibilitySettings()
            }
        }
    }

    private var statusMessage: String {
        if hasAccessibilityPermission {
            return isMonitoring ? "监听 Cmd+Q 中..." : "可以开始监听 Cmd+Q"
        }
        return "等待授权辅助功能权限"
    }

    /// 静默检测是否已授权辅助功能权限, 没有提示框。
    private func checkAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [promptKey: NSNumber(value: false)] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityPermission = granted

        if !granted {
            stopMonitoring()
        }
    }

    /// 主动请求系统弹出辅助功能授权提示框。
    private func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [promptKey: NSNumber(value: true)] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            checkAccessibilityPermission()
        }
    }

    /// 快捷打开系统的「隐私与安全性 → 辅助功能」设置页面。
    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// 启动 EventMonitor 监听, 仅在已授权且尚未启动时执行。
    private func startMonitoring() {
        guard hasAccessibilityPermission else {
            return
        }
        guard !isMonitoring else {
            return
        }

        eventMonitor = EventMonitor()

        // 设置回调
        eventMonitor?.onCmdQPressed = {
            NSLog("🎯 [ContentView] Cmd+Q 回调被触发! TODO: 添加延迟逻辑")
        }

        NSLog("📍 [ContentView] 准备启动 EventMonitor...")
        // 开始监听
        eventMonitor?.start()
        isMonitoring = true

        NSLog("✅ [ContentView] EventMonitor 启动完成! isMonitoring=\(isMonitoring)")
        NSLog("📍 [ContentView] 现在可以测试 Cmd+Q 了，查看调试输出")
    }

    /// 停止 EventMonitor, 清理资源并重置状态。
    private func stopMonitoring() {
        guard isMonitoring else {
            eventMonitor = nil
            return
        }

        eventMonitor?.stop()
        eventMonitor = nil
        isMonitoring = false
    }
}

#Preview {
    ContentView()
}
