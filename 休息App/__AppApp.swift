import SwiftUI
import AppKit

class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover
    
    override init() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 460)
        popover.behavior = .transient
        
        super.init()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // 优先用 SF Symbol，加载失败则用文字兜底
            if let img = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: nil) {
                button.image = img
            } else {
                button.title = "🌙"
                button.font = NSFont.systemFont(ofSize: 14)
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        popover.contentViewController = NSHostingController(rootView: ContentView())
    }
    
    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                NSApp.activate(ignoringOtherApps: true)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var allowTerminate = false
    
    private var menuBarManager: MenuBarManager!
    private var keepAliveWindow: NSWindow!
    private var autoStartTimer: Timer?  // 必须保存引用，否则 ARC 会释放
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager()
// 保活窗口
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
        self.keepAliveWindow = keepAlive

        // 检测自动重启（毛玻璃结束后自我重启）
        // 检测命令行参数 -autoRestart（比 UserDefaults 更可靠，无刷盘延迟）
        if CommandLine.arguments.contains("-autoRestart") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                TimerManager.shared.start()
            }
        }
        
        // 2秒后自动启动（测试用）
        let timer = Timer(timeInterval: 2, repeats: false) { _ in
            TimerManager.shared.start()
        }
        RunLoop.main.add(timer, forMode: .common)
        autoStartTimer = timer
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.allowTerminate {
            return .terminateNow
        }
        return .terminateCancel
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

@main
struct __AppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            Color.clear
                .frame(width: 0, height: 0)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
