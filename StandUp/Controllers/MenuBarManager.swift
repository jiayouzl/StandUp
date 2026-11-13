// 创建菜单栏状态项，并管理主界面弹出窗口的显示与尺寸。
import AppKit
import SwiftUI

final class MenuBarManager: NSObject {
    private static let popoverWidth: CGFloat = 320
    private static let preferredPopoverHeight: CGFloat = 600
    private static let minimumPopoverHeight: CGFloat = 360
    private static let screenVerticalMargin: CGFloat = 24

    private let statusItem: NSStatusItem
    private let popover: NSPopover

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        popover.contentSize = NSSize(
            width: Self.popoverWidth,
            height: Self.preferredPopoverHeight
        )
        popover.behavior = .transient

        super.init()

        if let button = statusItem.button {
            // 优先使用 SF Symbol，加载失败时用文字兜底
            if let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "StandUp") {
                button.image = image
            } else {
                button.title = "⏱"
                button.font = NSFont.systemFont(ofSize: 14)
            }
            button.action = #selector(togglePopover)
            button.target = self
            button.setAccessibilityLabel("StandUp")
        }

        popover.contentViewController = NSHostingController(rootView: ContentView())
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            updatePopoverSize(for: button)
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func updatePopoverSize(for button: NSStatusBarButton) {
        let visibleHeight = button.window?.screen?.visibleFrame.height
            ?? NSScreen.main?.visibleFrame.height
            ?? Self.preferredPopoverHeight
        let availableHeight = max(
            Self.minimumPopoverHeight,
            visibleHeight - Self.screenVerticalMargin
        )

        popover.contentSize = NSSize(
            width: Self.popoverWidth,
            height: min(Self.preferredPopoverHeight, availableHeight)
        )
    }
}
