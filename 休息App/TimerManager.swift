import Foundation
import Combine
import AppKit

// MARK: - 闹钟数据模型

struct AlarmItem: Identifiable, Codable {
    var id: UUID
    var time: Date
    var reminderText: String
    
    init(id: UUID = UUID(), time: Date = Date(), reminderText: String = "") {
        self.id = id
        self.time = time
        self.reminderText = reminderText
    }
    
    var formattedTime: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: time)
    }
    
    var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: time)
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
    
    @Published var isRunning = false
    @Published var isOnBreak = false
    @Published var timeUntilBreak: TimeInterval = 0
    
    var formattedTimeUntilBreak: String {
        let mins = Int(timeUntilBreak) / 60
        let secs = Int(timeUntilBreak) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Alarm Mode (多条闹钟)
    
    @Published var isAlarmMode = false
    @Published var alarms: [AlarmItem] = []
    static let maxAlarms = 5
    
    private var workTimer: Timer?
    private var workEndDate: Date?
    private var alarmCheckTimer: Timer?
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
        overlayManager.hide()
        isRunning = false
        isOnBreak = false
        timeUntilBreak = 0
    }
    
    private func scheduleWorkTimer() {
        workTimer?.invalidate()
        workEndDate = Date().addingTimeInterval(workDuration)
        timeUntilBreak = workDuration
        
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self, let endDate = self.workEndDate else {
                timer.invalidate()
                return
            }
            
            let remaining = endDate.timeIntervalSince(Date())
            if remaining <= 0 {
                self.timeUntilBreak = 0
                timer.invalidate()
                self.workTimer = nil
                self.showBreakOverlay()
            } else {
                self.timeUntilBreak = remaining
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        workTimer = timer
    }
    
    private func showBreakOverlay() {
        isOnBreak = true
        NSApp.activate(ignoringOtherApps: true)  // open -j 启动的 App 是失焦的，必须激活才能显示 overlay
        overlayManager.show(
            customReminderText: reminderText, presetReminder: currentPresetReminder,
            breakDuration: breakActivityDuration,
            onDismiss: { [weak self] in
                guard let self = self else { return }
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
        if let data = try? JSONEncoder().encode(alarms) {
            ud.set(data, forKey: "alarms")
        }
    }
}
