import AppKit
import SwiftUI

extension View {
    func managedPopover<Content: View>(isPresented: Binding<Bool>,
                                      @ViewBuilder content: @escaping () -> Content) -> some View {
        background(PopoverAnchor(isPresented: isPresented, content: content))
    }
}

private struct PopoverAnchor<Content: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    let content: () -> Content

    func makeCoordinator() -> PopoverCoordinator { PopoverCoordinator() }

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        let coordinator = context.coordinator
        coordinator.presentation = $isPresented
        // 布局更新结束后再操作窗口；过期的显示请求由版本号作废。
        coordinator.revision += 1
        let revision = coordinator.revision
        let requested = isPresented
        DispatchQueue.main.async { [weak view, weak coordinator] in
            guard let view, let coordinator, coordinator.revision == revision else { return }
            if requested {
                guard view.window != nil else { return }
                coordinator.show(content: content(), from: view)
            } else {
                coordinator.close()
            }
        }
    }

    static func dismantleNSView(_ view: NSView, coordinator: PopoverCoordinator) {
        coordinator.revision += 1
        coordinator.presentation = nil
        coordinator.close()
    }
}

private final class PopoverCoordinator: NSObject, NSPopoverDelegate {
    var presentation: Binding<Bool>?
    var revision = 0
    private var popover: NSPopover?

    func show<Content: View>(content: Content, from anchor: NSView) {
        guard popover == nil else { return }
        PopoverSession.closeActive?()
        // 子窗口建立前，父窗口必须先结束自己的编辑会话。
        guard anchor.window?.makeFirstResponder(nil) == true else {
            presentation?.wrappedValue = false
            return
        }
        let popover = NSPopover()
        popover.animates = false
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: content)
        self.popover = popover
        PopoverSession.owner = self
        PopoverSession.closeActive = { [weak self] in self?.close() }
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
    }

    func close() {
        popover?.performClose(nil)
    }

    func popoverWillClose(_ notification: Notification) {
        // 必须在 AppKit 拆除父子窗口关系之前清理，onDisappear 已经太晚。
        if let window = popover?.contentViewController?.view.window {
            window.makeFirstResponder(nil)
            window.endEditing(for: nil)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        popover?.delegate = nil
        popover = nil
        if PopoverSession.owner === self {
            PopoverSession.owner = nil
            PopoverSession.closeActive = nil
        }
        revision += 1
        presentation?.wrappedValue = false
    }
}

// 所有选择器共用一个活动弹窗，避免快速切换时窗口交叠。
@MainActor
private enum PopoverSession {
    static weak var owner: AnyObject?
    static var closeActive: (() -> Void)?
}
