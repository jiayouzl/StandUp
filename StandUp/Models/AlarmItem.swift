// 定义可持久化的闹钟数据，并提供时间和日期的本地化显示格式。
import Foundation

struct AlarmItem: Identifiable, Codable {
    let id: UUID
    let time: Date
    let reminderText: String

    init(id: UUID = UUID(), time: Date, reminderText: String) {
        self.id = id
        self.time = time
        self.reminderText = reminderText
    }

    var formattedTime: String {
        Self.timeFormatter.string(from: time)
    }

    var formattedDate: String {
        Self.dateFormatter.string(from: time)
    }

    private static let timeFormatter = makeFormatter("HH:mm")
    private static let dateFormatter = makeFormatter("M月d日 EEEE")

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = format
        return formatter
    }
}
