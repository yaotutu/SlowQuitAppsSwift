import Foundation
import Combine
import AppKit
import ApplicationServices

/// 统一管理辅助功能授权、CGEventTap、以及全局圆环 overlay。
@MainActor
final class CmdQController: ObservableObject {

    @Published var isMonitoring = false
    @Published var hasAccessibilityPermission = false
    @Published var holdDuration: TimeInterval {
        didSet {
            preferences.holdDuration = holdDuration
            eventMonitor?.holdDuration = holdDuration
        }
    }
    @Published var displayOverlay: Bool {
        didSet {
            preferences.displayOverlay = displayOverlay
            if !displayOverlay {
                holdOverlayController.forceHide()
            }
        }
    }
    @Published var bundleIdentifiers: [String] {
        didSet {
            preferences.bundleIdentifiers = bundleIdentifiers
        }
    }
    @Published var invertList: Bool {
        didSet {
            preferences.invertList = invertList
        }
    }

    private let preferences: PreferencesManager
    private var eventMonitor: EventMonitor?
    private let holdOverlayController = HoldOverlayWindowController()

    init(preferences: PreferencesManager = .shared) {
        self.preferences = preferences
        self.holdDuration = preferences.holdDuration
        self.displayOverlay = preferences.displayOverlay
        self.bundleIdentifiers = preferences.bundleIdentifiers
        self.invertList = preferences.invertList
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

    func reportPermissionStatus() -> (granted: Bool, message: String) {
        let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [promptKey: NSNumber(value: false)] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        let message = granted ? "辅助功能权限已授予。" : "缺少权限，请在“隐私与安全性 → 辅助功能”中勾选 SlowQuitAppsSwift。"
        return (granted, message)
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
        monitor.shouldHandleCmdQ = { [weak self] in
            return self?.shouldHandleCmdQ() ?? true
        }
        monitor.onCmdQHoldStart = { [weak self] in
            guard let self = self else { return }
            if self.displayOverlay {
                self.holdOverlayController.startHold(duration: self.holdDuration)
            }
        }
        monitor.onCmdQHoldCancel = { [weak self] in
            guard let self = self else { return }
            if self.displayOverlay {
                self.holdOverlayController.cancelHold()
            }
        }
        monitor.onCmdQHoldComplete = { [weak self] in
            guard let self = self else { return }
            if self.displayOverlay {
                self.holdOverlayController.completeHold()
            }
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

    private func shouldHandleCmdQ() -> Bool {
        let identifiers = bundleIdentifiers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !identifiers.isEmpty else {
            return true
        }
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return true
        }
        if invertList {
            // 黑名单模式: 只有列表内的应用才延迟
            return identifiers.contains(where: { $0.caseInsensitiveCompare(bundleID) == .orderedSame })
        } else {
            // 白名单: 列表内的是豁免, 其他都延迟
            return !identifiers.contains(where: { $0.caseInsensitiveCompare(bundleID) == .orderedSame })
        }
    }

    func updateBundleIdentifier(at index: Int, with value: String) {
        guard bundleIdentifiers.indices.contains(index) else { return }
        bundleIdentifiers[index] = value
    }

    func removeBundleIdentifiers(at offsets: IndexSet) {
        bundleIdentifiers = bundleIdentifiers.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map { $0.element }
    }

    func addEmptyBundleIdentifier() {
        bundleIdentifiers.append("")
    }

    func addFrontmostApplication() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        guard bundleID != Bundle.main.bundleIdentifier else { return }
        if !bundleIdentifiers.contains(where: { $0.caseInsensitiveCompare(bundleID) == .orderedSame }) {
            bundleIdentifiers.append(bundleID)
        }
    }
}
