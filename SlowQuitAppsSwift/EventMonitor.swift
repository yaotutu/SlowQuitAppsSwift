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
    /// 外部注入的回调, 在检测到 Cmd+Q 时调用。
    var onCmdQPressed: (() -> Void)?

    init() {}

    /// 启动监听流程: 创建 CGEventTap 并挂到 RunLoop。
    func start() {
        setupEventTap()
    }

    /// 停止监听: 移除 RunLoopSource 并失效 tap。
    func stop() {
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
        let mask = CGEventMask(1 << keyDownValue)

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
        // 读取此次按键的 Unicode 字符, 支持大小写判断。
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)

        let key = String(utf16CodeUnits: chars, count: length)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // 判断 Command 键是否按下。
        let flags = event.flags
        let commandPressed = (flags.rawValue & CGEventFlags.maskCommand.rawValue) == CGEventFlags.maskCommand.rawValue

        if key.lowercased() == "q" && commandPressed {
            NSLog("🎯 检测到 Cmd+Q! 调用回调...")
            onCmdQPressed?()
        }

        return Unmanaged.passRetained(event)
    }
}
