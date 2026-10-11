import SwiftUI

@main
struct StandUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 菜单栏界面由 AppDelegate 管理，启动时不创建参与调度中心的空窗口。
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
