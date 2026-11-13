// 处理应用启动与退出，并初始化菜单栏控制器和必要的系统权限流程。
import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var allowTerminate = false

    private var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager()

        let timer = TimerManager.shared
        timer.scheduleAutomaticStart()

        if timer.isAutoPauseEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Self.requestMediaPermissionIfNeeded()
            }
        }
    }

    static func quit() {
        allowTerminate = true
        NSApp.terminate(nil)
    }

    static func requestMediaPermissionIfNeeded() {
        guard TimerManager.shared.isAutoPauseEnabled, !AXIsProcessTrusted() else { return }
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "自动暂停媒体需要辅助功能权限。请在系统设置中允许 StandUp.app 使用辅助功能。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let settingsURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(settingsURL)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Self.allowTerminate ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        TimerManager.shared.prepareToTerminate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 菜单栏应用在没有窗口时继续运行，无需额外创建保活窗口。
        false
    }
}
