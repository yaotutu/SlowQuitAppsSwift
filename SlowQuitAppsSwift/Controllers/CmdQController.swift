import Foundation
import AppKit
import ApplicationServices

/// 统一管理辅助功能授权、CGEventTap、以及全局圆环 overlay。
@MainActor
final class CmdQController: ObservableObject {

    @Published var isMonitoring = false
    @Published var hasAccessibilityPermission = false
    @Published var holdDuration: TimeInterval = 1.0 {
        didSet {
            eventMonitor?.holdDuration = holdDuration
        }
    }

    private var eventMonitor: EventMonitor?
    private let holdOverlayController = HoldOverlayWindowController()

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
