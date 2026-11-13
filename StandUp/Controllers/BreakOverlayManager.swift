//
//  BreakOverlayManager.swift
//  StandUp
//
// 管理休息和闹钟提醒窗口，并将提醒铺展到当前连接的所有显示器。

import AppKit
import Combine
import SwiftUI

private final class BreakOverlayWindow: NSWindow {
    var isInteractive = false
    override var canBecomeKey: Bool { isInteractive }
    override var canBecomeMain: Bool { isInteractive }
}

@MainActor
protocol BreakOverlayPresenting {
    func show(customReminderText: String,
              presetReminder: String,
              breakDuration: TimeInterval,
              onDismiss: @escaping () -> Void,
              displayMode: OverlayDisplayMode)
    func hide()
}

final class BreakOverlayManager: BreakOverlayPresenting {
    
    private var primaryWindow: NSWindow?
    private var secondaryWindows: [NSWindow] = []
    private var screenChanges: AnyCancellable?
    
    func show(customReminderText: String,
              presetReminder: String,
              breakDuration: TimeInterval,
              onDismiss: @escaping () -> Void,
              displayMode: OverlayDisplayMode) {
        
        hide()
        let window = createWindow(interactive: true)
        updateContent(window: window,
                      customReminderText: customReminderText,
                      presetReminder: presetReminder,
                      breakDuration: breakDuration,
                      onDismiss: onDismiss,
                      displayMode: displayMode)
        primaryWindow = window
        screenChanges = NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateScreenLayout() }
        updateScreenLayout()
    }

    private func updateScreenLayout() {
        guard let primaryWindow else { return }
        closeWindows(secondaryWindows)
        secondaryWindows.removeAll()
        let screens = NSScreen.screens
        // 系统把主显示器放在首位。保留主窗口的视图，避免重置进行中的休息倒计时。
        guard let primaryScreen = screens.first else {
            primaryWindow.orderOut(nil)
            return
        }
        primaryWindow.setFrame(primaryScreen.frame, display: true)
        secondaryWindows = screens.dropFirst().map { screen in
            let window = createWindow(interactive: false)
            updateSecondaryBackground(window: window, screen: screen)
            window.setFrame(screen.frame, display: false)
            // 菜单栏 App 在副屏上用 orderFront(nil) 可能不显示。
            window.orderFrontRegardless()
            return window
        }
        focusPrimaryWindow(primaryWindow)
    }
    
    func hide() {
        screenChanges?.cancel()
        screenChanges = nil
        var hiddenWindows = secondaryWindows
        if let primaryWindow { hiddenWindows.append(primaryWindow) }
        primaryWindow = nil
        secondaryWindows.removeAll()
        closeWindows(hiddenWindows)
    }

    private func closeWindows(_ hiddenWindows: [NSWindow]) {
        guard !hiddenWindows.isEmpty else { return }
        for window in hiddenWindows {
            window.orderOut(nil)
        }
        // 按钮回调结束后再销毁承载它的窗口，避免事件处理中释放视图。
        DispatchQueue.main.async {
            for window in hiddenWindows {
                window.close()
            }
        }
    }
    
    // MARK: - 窗口创建

    private func createWindow(interactive: Bool) -> NSWindow {
        // 注意：不要在 init 里同时传 contentRect + screen:，
        // 否则非主屏(Retina)上坐标会被重复计算、窗口跑到屏幕外。
        // 改为：用 .zero 创建，再显式 setFrame 到屏幕 frame。
        let win = BreakOverlayWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isInteractive = interactive
        win.level = .screenSaver
        win.isOpaque = false
        win.backgroundColor = .clear
        win.isReleasedWhenClosed = false
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return win
    }

    /// 副屏全部显示后再激活主窗口，避免后续窗口排序抢走键盘焦点。
    private func focusPrimaryWindow(_ window: NSWindow) {
        let focus = { [weak self, weak window] in
            guard let self, let window, self.primaryWindow === window, !NSScreen.screens.isEmpty else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeMain()
        }

        focus()
        // SwiftUI 内容会在下一轮 RunLoop 完成挂载，再确认一次窗口焦点。
        DispatchQueue.main.async(execute: focus)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: focus)
    }
    
    // MARK: - 内容更新（使用 NSHostingView + Auto Layout）
    
    /// 主屏：完整界面（背景图 + 倒计时动效 + 全部功能）
    private func updateContent(window: NSWindow,
                               customReminderText: String,
                               presetReminder: String,
                               breakDuration: TimeInterval,
                               onDismiss: @escaping () -> Void,
                               displayMode: OverlayDisplayMode) {
        let overlayView = BreakOverlayView(
            customReminderText: customReminderText,
            presetReminder: presetReminder,
            breakDuration: breakDuration,
            onDismiss: onDismiss,
            displayMode: displayMode
        )
        setHostingContent(window: window, rootView: overlayView)
    }
    
    /// 副屏：只铺背景图（无文字、无倒计时、无按钮），并挡住其所在屏幕的点击。
    /// 横屏用横版图 background，竖屏用竖版图 menu_bg，保证整块屏幕都被铺满。
    private func updateSecondaryBackground(window: NSWindow, screen: NSScreen) {
        let resourceName = screen.frame.height > screen.frame.width ? "menu_bg" : "background"
        let backgroundView = SecondaryBackgroundView(resourceName: resourceName)
        setHostingContent(window: window, rootView: backgroundView)
    }
    
    private func setHostingContent<Content: View>(window: NSWindow, rootView: Content) {
        guard let contentView = window.contentView else { return }
        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hosting)
        
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: contentView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

}
