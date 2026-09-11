import AppKit
import SwiftUI

final class MenuBarManager: NSObject {
    private static let popoverWidth: CGFloat = 320
    private static let preferredPopoverHeight: CGFloat = 600
    private static let minimumPopoverHeight: CGFloat = 360
    private static let screenVerticalMargin: CGFloat = 24

    private var statusItem: NSStatusItem!
    private let popover: NSPopover

    override init() {
        popover = NSPopover()
        popover.contentSize = NSSize(
            width: Self.popoverWidth,
            height: Self.preferredPopoverHeight
        )
        popover.behavior = .transient

        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // 优先使用 SF Symbol，加载失败时用文字兜底
            if let image = NSImage(systemSymbolName: "macbook", accessibilityDescription: nil) {
                button.image = image
            } else {
                button.title = "💻"
                button.font = NSFont.systemFont(ofSize: 14)
            }
            button.action = #selector(togglePopover)
            button.target = self
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
