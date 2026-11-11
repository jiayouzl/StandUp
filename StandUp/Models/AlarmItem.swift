// 定义可持久化的闹钟数据，并提供时间和日期的本地化显示格式。
import Foundation

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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: time)
    }
}
