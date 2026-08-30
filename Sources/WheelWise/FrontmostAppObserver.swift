import AppKit

/// 跟踪前台应用 Bundle ID，供“忽略列表”判断。在主线程观察，加锁读出。
final class FrontmostAppObserver {
    private let lock = NSLock()
    private var _bundleID: String?
    private var observer: NSObjectProtocol?

    var bundleID: String? {
        lock.lock()
        defer { lock.unlock() }
        return _bundleID
    }

    func start() {
        capture()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.capture()
        }
    }

    private func capture() {
        let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        lock.lock()
        _bundleID = id
        lock.unlock()
    }
}
