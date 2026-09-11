import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var allowTerminate = false

    private var menuBarManager: MenuBarManager!
    private var keepAliveWindow: NSWindow!
    private var autoStartTimer: Timer? // 必须保存引用，否则 ARC 会释放

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager()

        // 使用屏幕外的透明窗口维持菜单栏应用生命周期
        let keepAlive = NSWindow(
            contentRect: NSRect(x: -5000, y: -5000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        keepAlive.level = .normal
        keepAlive.isOpaque = false
        keepAlive.backgroundColor = .clear
        keepAlive.ignoresMouseEvents = true
        keepAlive.orderFront(nil)
        keepAliveWindow = keepAlive

        requestAccessibilityPermissionIfNeeded()

        // 命令行参数比 UserDefaults 更适合处理毛玻璃结束后的自动重启
        if CommandLine.arguments.contains("-autoRestart") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                TimerManager.shared.start()
            }
        }

        // 启动后自动开始，便于当前产品流程直接进入工作计时
        let timer = Timer(timeInterval: 2, repeats: false) { _ in
            TimerManager.shared.start()
        }
        RunLoop.main.add(timer, forMode: .common)
        autoStartTimer = timer
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard !AXIsProcessTrusted() else { return }
            self?.showAccessibilityPermissionAlert()
        }
    }

    private func showAccessibilityPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "自动暂停媒体需要辅助功能权限。请在系统设置中允许 StandUp.app 使用辅助功能。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        guard let settingsURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(settingsURL)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Self.allowTerminate ? .terminateNow : .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
