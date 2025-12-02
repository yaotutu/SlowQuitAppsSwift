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
    @Published var needsPermissionRestartAdvice = false // 标记 UI 是否需要提示用户“授权后必须重启”，以便在系统仍报告未授权时给出正确反馈

    private let preferences: PreferencesManager // 保存用户偏好设置的单例，确保控制器能读取并写入设置
    private var eventMonitor: EventMonitor? // 负责监听 Cmd+Q 事件的事件监控器，可根据权限状态启动或停止
    private let holdOverlayController = HoldOverlayWindowController() // 用于显示长按提示圆环的窗口控制器
    private var awaitingPermissionRestart = false // 标记是否正等待辅助功能权限授予后触发自动重启
    private var permissionPollingTimer: Timer? // 轮询辅助功能权限状态的定时器引用，便于在结束时取消
    private var permissionPollingStartDate: Date? // 记录开始轮询的时间，用来判断是否超过超时时间
    private let permissionPollingTimeout: TimeInterval = 120 // 轮询辅助功能权限的最长持续时间（秒），避免长期占用资源
    private var hasObservedInitialPermissionState = false // 标记是否记录过初始的权限状态，避免首次检测就误触发自动重启
    private var hasHandledPermissionGainThisSession = false // 记录本次会话是否已经处理过“从无权限到有权限”的状态变化，防止重复提示

    init(preferences: PreferencesManager = .shared) {
        self.preferences = preferences
        self.holdDuration = preferences.holdDuration
        self.displayOverlay = preferences.displayOverlay
        self.bundleIdentifiers = preferences.bundleIdentifiers
        self.invertList = preferences.invertList
        DispatchQueue.main.async {
            self.checkAccessibilityPermission(autoStart: true) // App 启动后立即检测权限，必要时自动启动事件监听
        }
    }

    deinit {
        permissionPollingTimer?.invalidate() // 控制器销毁时确保定时器失效，防止循环引用
    }

    func checkAccessibilityPermission(autoStart: Bool = false) {
        let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String // 取出用于提示系统弹窗的 key
        let options = [promptKey: NSNumber(value: false)] as CFDictionary // 构造无需弹窗的查询参数，仅检测当前授权状态
        let granted = AXIsProcessTrustedWithOptions(options) // 通过 Accessibility API 查询当前是否已授权
        let previousPermissionState = hasAccessibilityPermission // 保存旧状态以便判断是否发生从未授权到已授权的变化
        let hasCompletedInitialSnapshot = hasObservedInitialPermissionState // 记录是否已经完成过一次权限快照，避免刚启动时误判
        hasAccessibilityPermission = granted // 更新外部可观察的授权状态
        if !hasObservedInitialPermissionState { // 首次执行检测时需要记录初始状态，避免误触发后续逻辑
            hasObservedInitialPermissionState = true // 首次执行检测后即视为已记录初始状态
        }

        if granted {
            stopPermissionPollingTimer() // 一旦获授权就停止轮询，避免不必要的资源开销
            if hasCompletedInitialSnapshot && !previousPermissionState && !hasHandledPermissionGainThisSession { // 仅在会话中检测到从未授权变为授权、且尚未处理过时触发
                hasHandledPermissionGainThisSession = true // 记录已经处理，防止重复弹窗
                awaitingPermissionRestart = false // 权限已就绪，不再需要继续等待标记
                needsPermissionRestartAdvice = false // 因为即将自动重启，因此不再需要在 UI 中显示提醒
                informUserAndRestartForPermissionChange() // 通知用户并自动重启使权限立即生效
            }
            if autoStart || isMonitoring {
                startMonitoring() // 在已授权的情况下，根据参数自动启动 Cmd+Q 监控
            }
        } else {
            stopMonitoring() // 尚未授权时确保停止事件监听，避免无效的 event tap
            hasHandledPermissionGainThisSession = false // 一旦权限丢失就允许后续再次触发权限获得的提示
            if awaitingPermissionRestart, let startDate = permissionPollingStartDate { // 若正在等待授权结果且有开始时间，则计算是否超时
                let elapsed = Date().timeIntervalSince(startDate) // 计算轮询持续时间
                if elapsed > permissionPollingTimeout {
                    awaitingPermissionRestart = false // 超时后停止等待，避免一直提示重启
                    stopPermissionPollingTimer() // 清理定时器，防止内存泄漏
                    needsPermissionRestartAdvice = false // 超时后移除提示，避免 UI 长期显示“等待重启”
                }
            }
        }
    }

    func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String // 取出提示 key 以触发系统弹窗
        let options = [promptKey: NSNumber(value: true)] as CFDictionary // 构造允许系统提示的参数，方便用户授权
        if !hasAccessibilityPermission {
            awaitingPermissionRestart = true // 仅在缺失权限时才设置等待重启标记
            startPermissionPollingTimer() // 启动轮询机制，以便在用户完成授权后立刻捕捉状态变化
        }
        _ = AXIsProcessTrustedWithOptions(options) // 请求系统弹出辅助功能授权提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { // 1.5 秒后再次检测，可覆盖用户立即点击“允许”的场景
            self.checkAccessibilityPermission(autoStart: true) // 在用户可能快速授权的情况下先做一次复检
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
        if !hasAccessibilityPermission { // 只有在缺少权限时才需要开启等待和轮询，避免不必要的资源消耗
            awaitingPermissionRestart = true // 用户即将前往系统设置授予权限，提前进入等待状态
            startPermissionPollingTimer() // 开始轮询以在授权后立刻响应
            needsPermissionRestartAdvice = true // UI 显示提示，明确告诉用户授权后需要让应用重新启动
        }
        NSWorkspace.shared.open(url)
    }

    func restartAfterManualPermissionConfirmation() {
        guard needsPermissionRestartAdvice else { return } // 仅当 UI 正在提示需要重启时才响应手动操作
        awaitingPermissionRestart = false // 用户已经主动要求重启，不再需要等待标记
        needsPermissionRestartAdvice = false // 隐藏 UI 提示，避免重复显示
        restartApplicationToApplyPermission() // 直接重启应用以刷新辅助功能权限
    }

    private func startPermissionPollingTimer() {
        permissionPollingTimer?.invalidate() // 启动前先停掉旧定时器，确保只存在一次轮询
        permissionPollingStartDate = Date() // 记录轮询起始时间，用于超时判断
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in // 创建一个每秒执行的定时器闭包以便持续检测
            guard let self = self else { return } // 防止控制器释放后仍访问 self
            Task { @MainActor in // 确保在 MainActor 上调用检测逻辑，与 UI 状态保持一致
                self.checkAccessibilityPermission(autoStart: true) // 每秒复检，以便在授权后即时跟进
            }
        }
        RunLoop.main.add(timer, forMode: .common) // 将定时器加入主运行循环，确保 UI 空闲时也能触发
        permissionPollingTimer = timer // 保存引用，方便后续停止
    }

    private func stopPermissionPollingTimer() {
        permissionPollingTimer?.invalidate() // 停止定时器事件
        permissionPollingTimer = nil // 清空引用以释放资源
        permissionPollingStartDate = nil // 重置开始时间，下一次轮询可重新计时
    }

    private func informUserAndRestartForPermissionChange() {
        let alert = NSAlert() // 创建提示框告知用户应用需要重启
        alert.messageText = "辅助功能权限已就绪，需要重启 SlowQuitAppsSwift" // 说明权限已生效但需要重新启动
        alert.informativeText = "macOS 仅会在应用重新启动后为其注入新的辅助功能权限，立即重新启动可确保 Cmd+Q 延迟立即可用。" // 提供原因，避免用户困惑
        alert.addButton(withTitle: "立即重启") // 提供明确操作按钮
        alert.runModal() // 同步展示提示，等待用户确认
        restartApplicationToApplyPermission() // 在用户确认后重启应用
    }

    private func restartApplicationToApplyPermission() {
        stopPermissionPollingTimer() // 重启前先停止轮询，避免新实例重复提示
        let bundleURL = Bundle.main.bundleURL // 获取当前应用的 bundle 路径以便重启
        let configuration = NSWorkspace.OpenConfiguration() // 构造启动配置以便重新拉起自身
        configuration.activates = true // 设置为前台启动，让用户看到应用已重新打开
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in // 请求系统重新拉起当前应用的全新实例
            if let error = error {
                NSLog("自动重启 SlowQuitAppsSwift 失败: \(error.localizedDescription)") // 记录失败原因，便于日志定位
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // 延迟数百毫秒再退出，避免新旧实例抢占前台
                NSApp?.terminate(nil) // 启动新实例后稍作延迟再退出当前进程，确保不会并存
            }
        }
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
