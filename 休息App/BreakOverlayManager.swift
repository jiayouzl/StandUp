//
//  BreakOverlayManager.swift
//  休息App
//

import AppKit
import SwiftUI

final class BreakOverlayManager {
    
    /// 窗口组。每次 show 时都会按“当前屏幕布局”重新对齐，
    /// 保证任何一块新增/拔掉的屏幕（包括副屏/平板）都能被覆盖。
    private var windows: [NSWindow] = []
    
    func show(customReminderText: String,
              presetReminder: String,
              breakDuration: TimeInterval,
              onDismiss: @escaping () -> Void,
              displayMode: OverlayDisplayMode = .breakReminder) {
        
        // 按当前屏幕布局重建窗口，确保主屏 + 所有副屏都有对应窗口
        rebuildWindows()
        
        // 主屏 = 带菜单栏、坐标原点(0,0) 所在的那块屏幕；其余全部视为副屏。
        // 主屏保留完整界面（背景图 + 倒计时 + 全部功能）；副屏只铺背景图。
        let screens = NSScreen.screens
        for (index, win) in windows.enumerated() {
            let screen = screens[index]
            // 关键：创建后再次把窗口 frame 精确设置到屏幕 frame，
            // 避免 contentView 设置或坐标换算把窗口挪到屏幕外。
            win.setFrame(screen.frame, display: false)
            if isPrimaryScreen(screen) {
                updateContent(window: win,
                              customReminderText: customReminderText,
                              presetReminder: presetReminder,
                              breakDuration: breakDuration,
                              onDismiss: onDismiss,
                              displayMode: displayMode)
            } else {
                updateSecondaryBackground(window: win, screen: screen)
            }
            // 强制置顶：菜单栏 App 在副屏上用 orderFront(nil) 可能不显示，必须用 Regardless
            win.orderFrontRegardless()
        }
    }
    
    func hide() {
        for w in windows {
            w.orderOut(nil)
        }
    }
    
    func fadeOut(completion: @escaping () -> Void) {
        hide()
        completion()
    }
    
    // MARK: - 窗口创建
    
    /// 依据当前屏幕布局重建窗口组：先关闭旧窗口，再为每块屏幕各建一个新窗口。
    private func rebuildWindows() {
        for w in windows {
            w.close()
        }
        windows = NSScreen.screens.map { createWindow(screen: $0) }
    }
    
    /// 主屏判定：坐标原点 (0,0) 所在的屏幕就是带菜单栏的主显示器。
    /// （NSScreen.main 是“键盘焦点屏”，在副屏上操作时会漂移，不能用。）
    private func isPrimaryScreen(_ screen: NSScreen) -> Bool {
        return screen.frame.origin == .zero
    }
    
    private func createWindow(screen: NSScreen) -> NSWindow {
        // 注意：不要在 init 里同时传 contentRect + screen:，
        // 否则非主屏(Retina)上坐标会被重复计算、窗口跑到屏幕外。
        // 改为：用 .zero 创建，再显式 setFrame 到屏幕 frame。
        let win = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.setFrame(screen.frame, display: false)
        win.level = .screenSaver
        win.isOpaque = false
        win.backgroundColor = .clear
        win.isReleasedWhenClosed = true
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return win
    }
    
    // MARK: - 内容更新（使用 NSHostingView + Auto Layout）
    
    /// 主屏：完整界面（背景图 + 倒计时动效 + 全部功能）
    private func updateContent(window: NSWindow,
                               customReminderText: String,
                               presetReminder: String,
                               breakDuration: TimeInterval,
                               onDismiss: @escaping () -> Void,
                               displayMode: OverlayDisplayMode = .breakReminder) {
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
