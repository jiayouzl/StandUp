import Foundation
import Combine
import AppKit
import AVFoundation

final class CountdownDisplayState: ObservableObject {
    @Published private(set) var remainingSeconds = 0

    var formattedTime: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    func update(remaining: TimeInterval) {
        let seconds = max(0, Int(remaining))
        guard seconds != remainingSeconds else { return }
        remainingSeconds = seconds
    }
}

// MARK: - TimerManager

class TimerManager: ObservableObject {
    
    static let shared = TimerManager()
    private init() { loadSettings() }
    
    @Published var workDuration: TimeInterval = 50 * 60
    @Published var breakActivityDuration: TimeInterval = 5 * 60
    static let presetReminders = [
        "起来走走，看看远方",
        "喝口水，深呼吸一下",
        "站起来，转转脖子",
        "离开屏幕，让眼睛休息",
        "伸个懒腰，放松身体",
        "眺望远处，放空大脑",
        "休息五分钟，效率更高",
        "站起来活动一下",
        "深呼吸，放松一下",
        "看看窗外，给眼睛放个假"
    ]
    @Published var reminderText: String = ""
    @Published var currentPresetReminder: String = presetReminders[0]
    @Published var isPreReminderEnabled = false {
        didSet { UserDefaults.standard.set(isPreReminderEnabled, forKey: "isPreReminderEnabled") }
    }
    @Published var isAutoPauseEnabled = false {
        didSet { UserDefaults.standard.set(isAutoPauseEnabled, forKey: "isAutoPauseEnabled") }
    }
    
    @Published var isRunning = false
    @Published var isOnBreak = false
    let countdownDisplay = CountdownDisplayState()
    
    // MARK: - Alarm Mode (多条闹钟)
    
    @Published var alarms: [AlarmItem] = []
    static let maxAlarms = 5
    
    private var workTimer: Timer?
    private var workEndDate: Date?
    private var alarmCheckTimer: Timer?
    private var promptPlayer: AVAudioPlayer?
    private var hasPlayedPreReminder = false
    private var shouldResumeMediaAfterBreak = false
    private let overlayManager = BreakOverlayManager()
    
    func start() {
        currentPresetReminder = Self.presetReminders.randomElement()!
        stop()
        isRunning = true
        isOnBreak = false
        scheduleWorkTimer()
        saveSettings()
    }
    
    func stop() {
        workTimer?.invalidate()
        workTimer = nil
        workEndDate = nil
        promptPlayer?.stop()
        promptPlayer = nil
        hasPlayedPreReminder = false
        resumeMediaPlaybackIfNeeded()
        overlayManager.hide()
        isRunning = false
        isOnBreak = false
        countdownDisplay.update(remaining: 0)
    }
    
    private func scheduleWorkTimer() {
        workTimer?.invalidate()
        workEndDate = Date().addingTimeInterval(workDuration)
        countdownDisplay.update(remaining: workDuration)
        hasPlayedPreReminder = false
        
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self, let endDate = self.workEndDate else {
                timer.invalidate()
                return
            }
            
            let remaining = endDate.timeIntervalSince(Date())
            if remaining <= 0 {
                self.countdownDisplay.update(remaining: 0)
                timer.invalidate()
                self.workTimer = nil
                self.showBreakOverlay()
            } else {
                self.countdownDisplay.update(remaining: remaining)
                if self.isPreReminderEnabled, remaining <= 10, !self.hasPlayedPreReminder {
                    self.hasPlayedPreReminder = true
                    self.playPreReminder()
                }
            }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        workTimer = timer
    }
    
    private func showBreakOverlay() {
        isOnBreak = true
        shouldResumeMediaAfterBreak = false
        if isAutoPauseEnabled {
            sendPlayPauseMediaKey()
            shouldResumeMediaAfterBreak = true
        }
        NSApp.activate(ignoringOtherApps: true)  // open -j 启动的 App 是失焦的，必须激活才能显示 overlay
        overlayManager.show(
            customReminderText: reminderText, presetReminder: currentPresetReminder,
            breakDuration: breakActivityDuration,
            onDismiss: { [weak self] in
                guard let self = self else { return }
                guard self.isOnBreak else { return }
                self.resumeMediaPlaybackIfNeeded()
                self.overlayManager.hide()
                self.isOnBreak = false
                // 先启动 bash（孤儿进程，App 退出后继续跑）
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/bash")
                task.arguments = ["-c", "sleep 0.5 && open -j '\(Bundle.main.bundlePath)' --args -autoRestart"]
                try? task.run()
                // 再退出当前 App（bash 已是孤儿进程，不受影响）
                AppDelegate.allowTerminate = true
                NSApplication.shared.terminate(nil)
            }
        )
    }

    private func playPreReminder() {
        guard let url = Bundle.main.url(forResource: "Prompt", withExtension: "mp3") else { return }
        promptPlayer = try? AVAudioPlayer(contentsOf: url)
        promptPlayer?.prepareToPlay()
        promptPlayer?.play()
    }

    private func sendPlayPauseMediaKey() {
        let playPauseKeyCode = 16

        func postEvent(isKeyDown: Bool) {
            let keyState = isKeyDown ? 0xA : 0xB
            let data1 = (playPauseKeyCode << 16) | (keyState << 8)
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(keyState << 8)),
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: CGEventTapLocation.cghidEventTap)
        }

        postEvent(isKeyDown: true)
        postEvent(isKeyDown: false)
    }

    private func resumeMediaPlaybackIfNeeded() {
        guard shouldResumeMediaAfterBreak else { return }
        shouldResumeMediaAfterBreak = false
        sendPlayPauseMediaKey()
    }
    
    // MARK: - 多条闹钟方法
    
    /// 添加闹钟，返回 true 表示成功，false 表示已达上限
    @discardableResult
    func addAlarm(time: Date, reminderText: String) -> Bool {
        guard alarms.count < Self.maxAlarms else { return false }
        var adjustedTime = time
        while adjustedTime <= Date() {
            adjustedTime = Calendar.current.date(byAdding: .day, value: 1, to: adjustedTime) ?? adjustedTime
        }
        let alarm = AlarmItem(time: adjustedTime, reminderText: reminderText)
        alarms.append(alarm)
        scheduleAlarmCheck()
        saveSettings()
        return true
    }
    
    func removeAlarm(id: UUID) {
        alarms.removeAll(where: { $0.id == id })
        if alarms.isEmpty {
            alarmCheckTimer?.invalidate()
            alarmCheckTimer = nil
        }
        saveSettings()
    }
    
    func updateAlarm(id: UUID, time: Date, reminderText: String) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        var adjustedTime = time
        while adjustedTime <= Date() {
            adjustedTime = Calendar.current.date(byAdding: .day, value: 1, to: adjustedTime) ?? adjustedTime
        }
        alarms[index] = AlarmItem(id: id, time: adjustedTime, reminderText: reminderText)
        scheduleAlarmCheck()
        saveSettings()
    }
    
    private func scheduleAlarmCheck() {
        alarmCheckTimer?.invalidate()
        guard !alarms.isEmpty else { return }
        
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            guard !self.isOnBreak else { return }
            
            let now = Date()
            if let alarm = self.alarms.first(where: { now >= $0.time }) {
                self.alarms.removeAll(where: { $0.id == alarm.id })
                self.saveSettings()
                if self.alarms.isEmpty {
                    timer.invalidate()
                    self.alarmCheckTimer = nil
                }
                self.fireAlarm(for: alarm)
            }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        alarmCheckTimer = timer
    }
    
    private func fireAlarm(for alarm: AlarmItem) {
        currentPresetReminder = Self.presetReminders.randomElement()!
        isOnBreak = true
        overlayManager.show(
            customReminderText: alarm.reminderText,
            presetReminder: currentPresetReminder,
            breakDuration: breakActivityDuration,
            onDismiss: { [weak self] in
                guard let self = self else { return }
                self.overlayManager.hide()
                self.isOnBreak = false
            },
            displayMode: .alarm
        )
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        let ud = UserDefaults.standard
        let work = ud.double(forKey: "workDuration")
        if work > 0 { workDuration = work }
        let brk = ud.double(forKey: "breakActivityDuration")
        if brk > 0 { breakActivityDuration = brk }
        if let text = ud.string(forKey: "reminderText"), !text.isEmpty {
            reminderText = text
        }
        isPreReminderEnabled = ud.bool(forKey: "isPreReminderEnabled")
        isAutoPauseEnabled = ud.bool(forKey: "isAutoPauseEnabled")
        if let data = ud.data(forKey: "alarms"),
           let decoded = try? JSONDecoder().decode([AlarmItem].self, from: data) {
            alarms = decoded.filter { $0.time > Date() }
            if !alarms.isEmpty {
                scheduleAlarmCheck()
            }
        }
    }
    
    private func saveSettings() {
        let ud = UserDefaults.standard
        ud.set(workDuration, forKey: "workDuration")
        ud.set(breakActivityDuration, forKey: "breakActivityDuration")
        ud.set(reminderText, forKey: "reminderText")
        ud.set(isPreReminderEnabled, forKey: "isPreReminderEnabled")
        ud.set(isAutoPauseEnabled, forKey: "isAutoPauseEnabled")
        if let data = try? JSONEncoder().encode(alarms) {
            ud.set(data, forKey: "alarms")
        }
    }
}
