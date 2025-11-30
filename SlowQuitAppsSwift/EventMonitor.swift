import Foundation
import Cocoa

/// CGEventTap 的回调入口, Apple 的 API 要求使用 C 函数。
private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        NSLog("❌ [EventTapCallback] refcon 为 nil!")
        return Unmanaged.passRetained(event)
    }

    let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return monitor.handleEvent(event: event)
}

/// 负责创建/销毁 CGEventTap 的工具类型, 对外暴露 Cmd+Q 回调。
class EventMonitor {

    /// 系统提供的事件 tap 端口, 用于拦截键盘事件。
    private var eventTap: CFMachPort?
    /// RunLoopSource 将 Mach 端口连接到当前 RunLoop。
    private var runLoopSource: CFRunLoopSource?
    /// 按住 Cmd+Q 开始时的回调。
    var onCmdQHoldStart: (() -> Void)?
    /// 提前松开 Cmd+Q, 取消退出的回调。
    var onCmdQHoldCancel: (() -> Void)?
    /// 长按 5 秒完成后触发的回调。
    var onCmdQHoldComplete: (() -> Void)?
    /// 是否正在拦截 Cmd+Q。
    private var isCmdQActive = false
    /// 计时器在 5 秒后触发, 发出真正的 Cmd+Q。
    private var holdTimer: DispatchSourceTimer?
    /// 是否正在发送模拟 Cmd+Q, 防止再次触发监听逻辑。
    private var isSimulatingCmdQ = false
    /// 当前长按阈值 (秒), 可动态调整。
    var holdDuration: TimeInterval
    /// Q 键的虚拟键值。
    private let qKeyCode: CGKeyCode = 12

    init(holdDuration: TimeInterval = 1.0) {
        self.holdDuration = holdDuration
    }

    /// 启动监听流程: 创建 CGEventTap 并挂到 RunLoop。
    func start() {
        setupEventTap()
    }

    /// 停止监听: 移除 RunLoopSource 并失效 tap。
    func stop() {
        holdTimer?.cancel()
        holdTimer = nil
        isCmdQActive = false

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

    }

    /// 真正创建 CGEventTap 的地方。
    private func setupEventTap() {
        let keyDownValue = CGEventType.keyDown.rawValue
        let keyUpValue = CGEventType.keyUp.rawValue
        let flagsChangedValue = CGEventType.flagsChanged.rawValue
        let mask = CGEventMask((1 << keyDownValue) | (1 << keyUpValue) | (1 << flagsChangedValue))

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,  // 修复: 使用正确的 tap 位置
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        if let eventTap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

            if let runLoopSource = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            } else {
                NSLog("❌ [EventMonitor] 无法创建 runLoopSource")
            }

            CGEvent.tapEnable(tap: eventTap, enable: true)
        } else {
            NSLog("❌ [EventMonitor] CGEventTap 创建失败!")
            NSLog("📍 [EventMonitor] 可能的原因:")
            NSLog("   - 缺少辅助功能权限")
            NSLog("   - 另一个应用已经占用了相同的事件监听")
            NSLog("   - 系统安全策略限制")
            print("❌ 监听器启动失败")
        }

    }

    /// 回调函数把事件交给此方法, 在这里判断是否为 Cmd+Q。
    func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
        let type = event.type
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let commandPressed = (flags.rawValue & CGEventFlags.maskCommand.rawValue) == CGEventFlags.maskCommand.rawValue

        if type == .flagsChanged {
            if isSimulatingCmdQ {
                return Unmanaged.passRetained(event)
            }
            if isCmdQActive && !commandPressed {
                cancelCmdQHold()
            }
            return Unmanaged.passRetained(event)
        }

        if keyCode == Int64(qKeyCode) && (commandPressed || type == .keyUp) {
            if isSimulatingCmdQ {
                return Unmanaged.passRetained(event)
            }
            if type == .keyDown {
                if !isCmdQActive {
                    beginCmdQHold()
                }
                return nil
            }

            if type == .keyUp {
                if isCmdQActive {
                    cancelCmdQHold()
                }
                return nil
            }
        }

        return Unmanaged.passRetained(event)
    }

    /// 启动 5 秒计时并通知外界更新 UI。
    private func beginCmdQHold() {
        isCmdQActive = true
        onCmdQHoldStart?()

        holdTimer?.cancel()
        holdTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        holdTimer?.schedule(deadline: .now() + holdDuration)
        holdTimer?.setEventHandler { [weak self] in
            self?.completeCmdQHold()
        }
        holdTimer?.resume()
    }

    /// 用户松开 Cmd+Q, 取消退出。
    private func cancelCmdQHold() {
        holdTimer?.cancel()
        holdTimer = nil
        isCmdQActive = false
        onCmdQHoldCancel?()
    }

    /// 按住超过 5 秒, 向系统重新发送一次 Cmd+Q, 真正触发退出。
    private func completeCmdQHold() {
        guard isCmdQActive else { return }
        holdTimer?.cancel()
        holdTimer = nil
        isCmdQActive = false
        onCmdQHoldComplete?()
        sendSyntheticCmdQ()
    }

    /// 通过 CGEvent 模拟一次 Cmd+Q, 让前台 App 真正收到退出事件。
    private func sendSyntheticCmdQ() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        isSimulatingCmdQ = true

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: qKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: qKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isSimulatingCmdQ = false
        }
    }
}
