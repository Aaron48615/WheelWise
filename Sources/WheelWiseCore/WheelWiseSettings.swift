import Foundation

/// 设置项。UserDefaults 本身线程安全，可在事件 tap 线程直接读取。
public final class WheelWiseSettings {
    public enum Key {
        public static let enabled = "enabled"
        public static let reverseVertical = "reverseVertical"
        public static let reverseHorizontal = "reverseHorizontal"
        public static let smoothScrolling = "smoothScrolling"
        public static let scrollSpeed = "scrollSpeed"
        public static let magicMouseMode = "magicMouseMode"
        public static let ignoredApps = "ignoredApps"
    }

    /// 系统全局“自然滚动”开关（滚动方向设置页里的那一项）。
    public static var systemNaturalScrollingEnabled: Bool {
        let value = CFPreferencesCopyAppValue(
            "com.apple.swipescrolldirection" as CFString,
            kCFPreferencesAnyApplication
        )
        return value as? Bool ?? true
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get { defaults.object(forKey: Key.enabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    public var reverseVertical: Bool {
        get { defaults.object(forKey: Key.reverseVertical) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.reverseVertical) }
    }

    public var reverseHorizontal: Bool {
        get { defaults.object(forKey: Key.reverseHorizontal) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.reverseHorizontal) }
    }

    public var smoothScrolling: Bool {
        get { defaults.object(forKey: Key.smoothScrolling) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.smoothScrolling) }
    }

    /// 滚动速度倍率，1.0 为系统原生速度。
    public var scrollSpeed: Double {
        get { defaults.object(forKey: Key.scrollSpeed) as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: Key.scrollSpeed) }
    }

    /// 实验性：把 Magic Mouse 的连续滚动也当作滚轮反转。
    public var magicMouseMode: Bool {
        get { defaults.object(forKey: Key.magicMouseMode) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.magicMouseMode) }
    }

    /// 忽略列表：这些 Bundle ID 为前台应用时不做任何改写。
    public var ignoredApps: [String] {
        get { defaults.stringArray(forKey: Key.ignoredApps) ?? [] }
        set { defaults.set(newValue, forKey: Key.ignoredApps) }
    }
}
