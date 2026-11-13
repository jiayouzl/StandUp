// 呈现休息或闹钟全屏提醒，显示倒计时、提示内容并处理用户交互。
import Combine
import SwiftUI
import AppKit

struct BreakOverlayView: View {

    private static let backgroundImageAsset = OverlayImageAssets.landscape
    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    let customReminderText: String
    let presetReminder: String
    let breakDuration: TimeInterval
    let onDismiss: () -> Void
    let displayMode: OverlayDisplayMode
    
    private enum Phase { case resting, countingDown }
    
    @State private var phase: Phase = .resting
    @State private var countdownRemaining = 0
    @State private var countdownEndDate: Date?
    @State private var appeared = false
    @FocusState private var acceptsKeyboardInput: Bool
    
    private static let countdownTicks = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 背景图片
            backgroundImage
            
            // 可调节半透明黑色叠加层
            Color.black.opacity(0.30)
                .ignoresSafeArea()
            
            // 内容层
            if displayMode == .alarm {
                alarmContent
            } else {
                VStack(spacing: 0) {
                    Spacer()
                    ZStack {
                        if phase == .resting {
                            restingContent
                                .transition(.opacity)
                        } else {
                            countdownContent
                                .transition(.opacity)
                                .onReceive(Self.countdownTicks) { _ in tick() }
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: phase)
                    Spacer()
                }
            }
            

        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) { appeared = true }
            if displayMode == .breakReminder {
                requestKeyboardFocus()
            }
        }
        .focusable()
        .focused($acceptsKeyboardInput)
        .onKeyPress(keys: [.return, .space]) { _ in
            guard displayMode == .breakReminder, phase == .resting else {
                return .ignored
            }
            startBreak()
            return .handled
        }
    }
    
    // MARK: - 背景图片
    
    private var backgroundImage: some View {
        Group {
            if let nsImg = Self.backgroundImageAsset {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .accessibilityHidden(true)
            } else {
                Color.black
            }
        }
        .ignoresSafeArea()
    }

    
    // MARK: - 闹钟模式内容
    
    private var alarmContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("现在的时间是")
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.80))
                .tracking(1)
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            TimelineView(.everyMinute) { context in
                Text(Self.clockFormatter.string(from: context.date))
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .tracking(6)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
            }

            Text(customReminderText.isEmpty ? presetReminder : customReminderText)
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(10).tracking(1.0)
                .foregroundStyle(.white.opacity(0.80))
                .padding(.horizontal, 60)
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            Button { onDismiss() } label: {
                Text("我知道了")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(Color(red: 0.18, green: 0.14, blue: 0.02))
                    .padding(.horizontal, 56).padding(.vertical, 18)
                    .background(LinearGradient(colors: [Color(red: 0.94, green: 0.84, blue: 0.58), Color(red: 0.83, green: 0.70, blue: 0.40)], startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(red: 0.65, green: 0.55, blue: 0.28), lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .transition(.opacity)
    }
    
    // MARK: - 计时器：休息提示
    
    private var restingContent: some View {
        VStack(spacing: 12) {

            if !customReminderText.isEmpty {
                Text(customReminderText)
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center).lineSpacing(6)
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 80)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
            
            Text(presetReminder)
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .multilineTextAlignment(.center).lineSpacing(12)
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 80)
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            Button {
                startBreak()
            } label: {
                Text("开始休息")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(Color(red: 0.18, green: 0.14, blue: 0.02))
                    .padding(.horizontal, 56).padding(.vertical, 18)
                    .background(LinearGradient(colors: [Color(red: 0.94, green: 0.84, blue: 0.58), Color(red: 0.83, green: 0.70, blue: 0.40)], startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(red: 0.65, green: 0.55, blue: 0.28), lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 160)
    }
    
    // MARK: - 计时器：倒计时
    
    private var countdownContent: some View {
        VStack(spacing: 32) {
            Text(formattedCountdown)
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .monospacedDigit().tracking(4)
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .shadow(color: .black.opacity(0.5), radius: 4)
            
            Text("好好放松一下吧")
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.5))
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            Button { onDismiss() } label: {
                Text("打断休息，继续工作！")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(Color(red: 0.18, green: 0.14, blue: 0.02))
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(LinearGradient(colors: [Color(red: 0.94, green: 0.84, blue: 0.58).opacity(0.65), Color(red: 0.83, green: 0.70, blue: 0.40).opacity(0.65)], startPoint: .top, endPoint: .bottom))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color(red: 0.65, green: 0.55, blue: 0.28).opacity(0.4), lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, -20).padding(.bottom, 160)
    }
    
    // MARK: - 倒计时与焦点
    
    private var formattedCountdown: String {
        let mins = countdownRemaining / 60
        let secs = countdownRemaining % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func tick() {
        guard phase == .countingDown, let endDate = countdownEndDate else { return }
        let remaining = endDate.timeIntervalSince(Date())
        let seconds = Int(max(0, remaining).rounded(.up))
        if countdownRemaining != seconds { countdownRemaining = seconds }
        if remaining <= 0 {
            countdownEndDate = nil
            onDismiss()
        }
    }

    private func startBreak() {
        guard phase == .resting else { return }
        phase = .countingDown
        countdownRemaining = Int(breakDuration.rounded(.up))
        countdownEndDate = Date().addingTimeInterval(breakDuration)
    }

    private func requestKeyboardFocus() {
        DispatchQueue.main.async {
            acceptsKeyboardInput = true
        }
        // 窗口成为 key window 后重新申请一次，避免首次挂载时焦点请求被忽略。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            acceptsKeyboardInput = false
            DispatchQueue.main.async {
                acceptsKeyboardInput = true
            }
        }
    }
    
}

// MARK: - 副屏背景视图（只铺背景图，无文字 / 无倒计时 / 无按钮）

struct SecondaryBackgroundView: View {
    let resourceName: String
    @State private var appeared = false

    var body: some View {
        ZStack {
            // 黑色底层：防止图片因缩放比例不同而露边
            Color.black
                .ignoresSafeArea()

            backgroundImage
                .ignoresSafeArea()
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            // 与主屏一致的 0.6s 淡入，保证视觉上“同步出现”
            withAnimation(.easeIn(duration: 0.6)) {
                appeared = true
            }
        }
    }

    private var backgroundImage: some View {
        Group {
            if let nsImg = OverlayImageAssets.image(named: resourceName) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black
            }
        }
    }
}

private enum OverlayImageAssets {
    static let landscape = loadBundledImage(named: "background")
    static let portrait = loadBundledImage(named: "menu_bg")

    static func image(named resourceName: String) -> NSImage? {
        switch resourceName {
        case "background":
            return landscape
        case "menu_bg":
            return portrait
        default:
            return loadBundledImage(named: resourceName)
        }
    }
}

private func loadBundledImage(named resourceName: String) -> NSImage? {
    guard let path = Bundle.main.path(forResource: resourceName, ofType: "png") else {
        return nil
    }
    return NSImage(contentsOfFile: path)
}
