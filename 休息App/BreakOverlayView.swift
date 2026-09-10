import Combine
import SwiftUI
import AppKit

// MARK: - 显示模式
enum OverlayDisplayMode {
    case breakReminder
    case alarm
}

struct BreakOverlayView: View {
    
    let customReminderText: String
    let presetReminder: String
    let breakDuration: TimeInterval
    let onDismiss: () -> Void
    let displayMode: OverlayDisplayMode
    
    init(customReminderText: String,
         presetReminder: String,
         breakDuration: TimeInterval,
         onDismiss: @escaping () -> Void,
         displayMode: OverlayDisplayMode = .breakReminder) {
        self.customReminderText = customReminderText
        self.presetReminder = presetReminder
        self.breakDuration = breakDuration
        self.onDismiss = onDismiss
        self.displayMode = displayMode
    }
    
    private enum Phase { case resting, countingDown }
    
    @State private var phase: Phase = .resting
    @State private var countdownRemaining: TimeInterval = 0
    @State private var countdownEndDate: Date?
    @State private var currentTimeString = ""
    @State private var appeared = false
    
    // 共享一个 Timer，防止反复创建导致 RunLoop 堆积
    static let sharedTickTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
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
                        restingContent
                            .opacity(phase == .resting ? 1 : 0)
                            .animation(.easeOut(duration: 0.12), value: phase)
                        countdownContent
                            .opacity(phase == .countingDown ? 1 : 0)
                            .animation(.easeIn(duration: 0.35).delay(0.12), value: phase)
                    }
                    Spacer()
                }
            }
            

        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            if displayMode == .alarm { updateClock() }
            withAnimation(.easeIn(duration: 0.6)) { appeared = true }
        }
        .onReceive(Self.sharedTickTimer) { _ in
            if displayMode == .alarm { updateClock() }
            else { tick() }
        }
    }
    
    // MARK: - 背景图片
    
    private var backgroundImage: some View {
        Group {
            if let path = Bundle.main.path(forResource: "background", ofType: "png"),
               let nsImg = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
            
            Text(currentTimeString)
                .font(.system(size: 100, weight: .bold, design: .rounded))
                .monospacedDigit()
                .tracking(6)
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .shadow(color: .black.opacity(0.5), radius: 4)
            
            if !customReminderText.isEmpty {
                Text(customReminderText)
                    .font(.system(size: 28, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10).tracking(1.0)
                    .foregroundColor(.white.opacity(0.80))
                    .padding(.horizontal, 60)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            } else {
                Text(presetReminder)
                    .font(.system(size: 28, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10).tracking(1.0)
                    .foregroundColor(.white.opacity(0.80))
                    .padding(.horizontal, 60)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
            
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
        .onAppear { updateClock() }
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
                phase = .countingDown
                countdownRemaining = breakDuration
                countdownEndDate = Date().addingTimeInterval(breakDuration)
            } label: {
                Text("我会好好休息")
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
                Text("我不要，我要干活！")
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
    
    // MARK: - Helpers
    
    private var formattedCountdown: String {
        let mins = Int(countdownRemaining) / 60
        let secs = Int(countdownRemaining) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func tick() {
        guard phase == .countingDown, let endDate = countdownEndDate else { return }
        let remaining = endDate.timeIntervalSince(Date())
        countdownRemaining = remaining > 0 ? remaining : 0
        if remaining <= 0 { onDismiss() }
    }
    
    private func updateClock() {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        currentTimeString = f.string(from: Date())
    }
}

// MARK: - NSVisualEffectView 封装

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var alphaValue: CGFloat = 1.0
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.alphaValue = alphaValue
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.alphaValue = alphaValue
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
            if let path = Bundle.main.path(forResource: resourceName, ofType: "png"),
               let nsImg = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black
            }
        }
    }
}
