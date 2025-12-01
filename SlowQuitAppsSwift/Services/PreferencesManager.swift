import Foundation

/// 负责管理用户偏好设置, 目前提供长按时长与圆环可见性。
final class PreferencesManager {

    static let shared = PreferencesManager()

    private enum Keys {
        static let holdDuration = "com.yaotutu.sqa.holdDuration"
        static let displayOverlay = "com.yaotutu.sqa.displayOverlay"
        static let bundleList = "com.yaotutu.sqa.bundleList"
        static let invertList = "com.yaotutu.sqa.invertList"
    }

    private let defaults: UserDefaults
    private let defaultHoldDuration: TimeInterval = 1.0

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.holdDuration: defaultHoldDuration,
            Keys.displayOverlay: true,
            Keys.bundleList: [String](),
            Keys.invertList: false
        ])
    }

    var holdDuration: TimeInterval {
        get {
            let value = defaults.double(forKey: Keys.holdDuration)
            return value > 0 ? value : defaultHoldDuration
        }
        set {
            defaults.set(newValue, forKey: Keys.holdDuration)
        }
    }

    var displayOverlay: Bool {
        get {
            if defaults.object(forKey: Keys.displayOverlay) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.displayOverlay)
        }
        set {
            defaults.set(newValue, forKey: Keys.displayOverlay)
        }
    }

    var bundleIdentifiers: [String] {
        get {
            return defaults.stringArray(forKey: Keys.bundleList) ?? []
        }
        set {
            defaults.set(newValue, forKey: Keys.bundleList)
        }
    }

    var invertList: Bool {
        get {
            defaults.bool(forKey: Keys.invertList)
        }
        set {
            defaults.set(newValue, forKey: Keys.invertList)
        }
    }
}
