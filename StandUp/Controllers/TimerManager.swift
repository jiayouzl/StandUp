// 管理工作与休息倒计时、闹钟调度、用户设置持久化及提醒触发。
import Foundation
import Combine
import AppKit
import ApplicationServices
import AVFAudio

final class CountdownDisplayState: ObservableObject {
    @Published private(set) var remainingSeconds = 0

    var formattedTime: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    func update(remaining: TimeInterval) {
        let seconds = Int(max(0, remaining).rounded(.up))
        guard seconds != remainingSeconds else { return }
        remainingSeconds = seconds
    }
}

// MARK: - TimerManager

final class TimerManager: ObservableObject {
    
    static let shared = TimerManager(defaults: .standard, overlayManager: BreakOverlayManager())

    private let defaults: UserDefaults
    private let overlayManager: any BreakOverlayPresenting

    init(defaults: UserDefaults, overlayManager: any BreakOverlayPresenting) {
        self.defaults = defaults
        self.overlayManager = overlayManager
        loadSettings()
        clockChanges = NotificationCenter.default.publisher(for: .NSSystemClockDidChange)
            .merge(with: NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshSchedule() }
        refreshSchedule()
    }
    
    @Published var workDuration: TimeInterval = 50 * 60
    @Published var breakActivityDuration: TimeInterval = 5 * 60
    private static let presetReminders = [
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
    private var currentPresetReminder: String = presetReminders[0]
    @Published var isPreReminderEnabled = false {
        didSet { defaults.set(isPreReminderEnabled, forKey: "isPreReminderEnabled") }
    }
    @Published var isAutoPauseEnabled = false {
        didSet { defaults.set(isAutoPauseEnabled, forKey: "isAutoPauseEnabled") }
    }
    
    @Published private(set) var isRunning = false
    @Published private(set) var isOnBreak = false
    let countdownDisplay = CountdownDisplayState()
    
    // MARK: - 多条闹钟
    
    @Published private(set) var alarms: [AlarmItem] = []
    static let maxAlarms = 5
    
    private var autoStartTimer: Timer?
    private var workTimer: Timer?
    private var workEndDate: Date?
    private var alarmTimer: Timer?
    private var clockChanges: AnyCancellable?
    private var promptPlayer: AVAudioPlayer?
    private var hasPlayedPreReminder = false
    private var shouldResumeMediaAfterBreak = false
    private var presentedAlarm: (id: UUID, token: UUID)?
    
    func scheduleAutomaticStart() {
        autoStartTimer?.invalidate()
        let timer = Timer(timeInterval: 2, repeats: false) { [weak self] _ in
            guard let self, !self.isRunning else { return }
            self.start()
        }
        RunLoop.main.add(timer, forMode: .common)
        autoStartTimer = timer
    }

    func start() {
        cancelAutomaticStart()
        saveTimerSettings()
        beginWorkCycle()
    }

    private func beginWorkCycle() {
        resetWorkCycle()
        currentPresetReminder = Self.presetReminders.randomElement()!
        isRunning = true
        workEndDate = Date().addingTimeInterval(workDuration)
        countdownDisplay.update(remaining: workDuration)
        startWorkTimer()
        refreshSchedule()
    }
    
    func stop() {
        cancelAutomaticStart()
        resetWorkCycle()
        isRunning = false
        countdownDisplay.update(remaining: 0)
        refreshSchedule()
    }

    func prepareToTerminate() {
        cancelAutomaticStart()
        resetWorkCycle()
        alarmTimer?.invalidate()
        alarmTimer = nil
        clockChanges?.cancel()
        if let id = presentedAlarm?.id { finishAlarmPresentation(id: id) }
    }

    private func cancelAutomaticStart() {
        autoStartTimer?.invalidate()
        autoStartTimer = nil
    }

    private func resetWorkCycle() {
        workTimer?.invalidate()
        workTimer = nil
        workEndDate = nil
        promptPlayer?.stop()
        promptPlayer = nil
        hasPlayedPreReminder = false
        resumeMediaPlaybackIfNeeded()
        if isOnBreak { overlayManager.hide() }
        isOnBreak = false
    }
    
    private func startWorkTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self, let endDate = self.workEndDate else {
                timer.invalidate()
                return
            }
            
            let now = Date()
            let remaining = endDate.timeIntervalSince(now)
            if remaining <= 0 {
                self.countdownDisplay.update(remaining: 0)
                timer.invalidate()
                self.workTimer = nil
                self.refreshSchedule(now: now)
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
        if isAutoPauseEnabled, AXIsProcessTrusted() {
            shouldResumeMediaAfterBreak = sendPlayPauseMediaKey()
        }
        overlayManager.show(
            customReminderText: reminderText, presetReminder: currentPresetReminder,
            breakDuration: breakActivityDuration,
            onDismiss: { [weak self] in
                guard let self, self.isOnBreak else { return }
                self.beginWorkCycle()
            },
            displayMode: .breakReminder
        )
    }

    private func playPreReminder() {
        guard let url = Bundle.main.url(forResource: "Prompt", withExtension: "mp3") else { return }
        promptPlayer = try? AVAudioPlayer(contentsOf: url)
        promptPlayer?.prepareToPlay()
        promptPlayer?.play()
    }

    private func sendPlayPauseMediaKey() -> Bool {
        let playPauseKeyCode = 16

        func makeEvent(isKeyDown: Bool) -> CGEvent? {
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
            return event?.cgEvent
        }

        guard let keyDown = makeEvent(isKeyDown: true), let keyUp = makeEvent(isKeyDown: false) else { return false }
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func resumeMediaPlaybackIfNeeded() {
        guard shouldResumeMediaAfterBreak else { return }
        shouldResumeMediaAfterBreak = false
        if AXIsProcessTrusted() { _ = sendPlayPauseMediaKey() }
    }
    
    // MARK: - 多条闹钟方法
    
    /// 添加闹钟，返回 true 表示成功，false 表示已达上限
    @discardableResult
    func addAlarm(time: Date, reminderText: String) -> Bool {
        guard alarms.count < Self.maxAlarms else { return false }
        let adjustedTime = nextAlarmTime(time)
        let alarm = AlarmItem(time: adjustedTime, reminderText: reminderText)
        alarms.append(alarm)
        saveAlarms()
        refreshSchedule()
        return true
    }
    
    func removeAlarm(id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms.remove(at: index)
        finishAlarmPresentation(id: id)
        saveAlarms()
        refreshSchedule()
    }
    
    func updateAlarm(id: UUID, time: Date, reminderText: String) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        let adjustedTime = nextAlarmTime(time)
        alarms[index] = AlarmItem(id: id, time: adjustedTime, reminderText: reminderText)
        finishAlarmPresentation(id: id)
        saveAlarms()
        refreshSchedule()
    }

    private func nextAlarmTime(_ time: Date) -> Date {
        let now = Date()
        guard time <= now else { return time }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: time)
        return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents)
            ?? now.addingTimeInterval(24 * 60 * 60)
    }

    private func finishAlarmPresentation(id: UUID) {
        guard presentedAlarm?.id == id else { return }
        presentedAlarm = nil
        overlayManager.hide()
    }

    private func refreshSchedule(now: Date = Date()) {
        alarmTimer?.invalidate()
        alarmTimer = nil
        guard !isOnBreak, presentedAlarm == nil else { return }

        let nextAlarm = alarms.min(by: { $0.time < $1.time })
        // 两种提醒同时到期时，先处理最早到期的闹钟。
        if let nextAlarm, nextAlarm.time <= now {
            fireAlarm(for: nextAlarm)
        } else if let endDate = workEndDate, endDate <= now {
            workTimer?.invalidate()
            workTimer = nil
            workEndDate = nil
            countdownDisplay.update(remaining: 0)
            showBreakOverlay()
        } else {
            // 系统时钟调回到工作截止时间之前时，恢复曾暂停的刷新。
            if let endDate = workEndDate, workTimer == nil {
                countdownDisplay.update(remaining: endDate.timeIntervalSince(now))
                startWorkTimer()
            }
            if let nextAlarm {
                let timer = Timer(fire: nextAlarm.time, interval: 0, repeats: false) { [weak self] _ in
                    self?.refreshSchedule()
                }
                RunLoop.main.add(timer, forMode: .common)
                alarmTimer = timer
            }
        }
    }
    
    private func fireAlarm(for alarm: AlarmItem) {
        let token = UUID()
        presentedAlarm = (id: alarm.id, token: token)
        overlayManager.show(
            customReminderText: alarm.reminderText,
            presetReminder: Self.presetReminders.randomElement()!,
            breakDuration: breakActivityDuration,
            onDismiss: { [weak self] in
                guard let self, self.presentedAlarm?.token == token else { return }
                self.removeAlarm(id: alarm.id)
            },
            displayMode: .alarm
        )
    }
    
    // MARK: - 设置持久化
    
    private func loadSettings() {
        let ud = defaults
        let work = ud.double(forKey: "workDuration")
        if (60...14_400).contains(work) { workDuration = work }
        let brk = ud.double(forKey: "breakActivityDuration")
        if (60...3_600).contains(brk) { breakActivityDuration = brk }
        if let text = ud.string(forKey: "reminderText"), !text.isEmpty {
            reminderText = text
        }
        isPreReminderEnabled = ud.bool(forKey: "isPreReminderEnabled")
        isAutoPauseEnabled = ud.bool(forKey: "isAutoPauseEnabled")
        if let data = ud.data(forKey: "alarms"),
           let decoded = try? JSONDecoder().decode([AlarmItem].self, from: data) {
            let now = Date()
            alarms = decoded.filter { $0.time > now }
            if alarms.count != decoded.count { saveAlarms() }
        }
    }
    
    private func saveTimerSettings() {
        let ud = defaults
        ud.set(workDuration, forKey: "workDuration")
        ud.set(breakActivityDuration, forKey: "breakActivityDuration")
        ud.set(reminderText, forKey: "reminderText")
    }

    private func saveAlarms() {
        if let data = try? JSONEncoder().encode(alarms) {
            defaults.set(data, forKey: "alarms")
        }
    }
}
