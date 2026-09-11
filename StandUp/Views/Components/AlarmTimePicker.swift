import SwiftUI

// MARK: - 闹钟时间选择器（日期·24小时·大弹窗）

struct AlarmTimePicker: View {
    @Binding var alarmTime: Date
    var disabled: Bool = false
    
    @State private var showDate = false
    @State private var showHour = false
    @State private var showMinute = false
    
    private var hour24: Int {
        Calendar.current.component(.hour, from: alarmTime)
    }
    
    private var minute: Int {
        Calendar.current.component(.minute, from: alarmTime)
    }
    
    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: alarmTime)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // 日期
            Button(action: { showDate = true }) {
                Text(dateLabel)
                    .font(.title3.weight(.semibold))
                    .frame(width: 72, height: 48)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDate, arrowEdge: .bottom) { datePopover }
            
            // 小时
            Button(action: { showHour = true }) {
                Text(String(format: "%02d", hour24))
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 56, height: 48)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showHour, arrowEdge: .bottom) {
                valuePopover(title: "小时", range: 0...23, current: hour24, format: "%02d", onSelect: { setHour($0) }, dismiss: { showHour = false })
            }
            
            Text(":")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            
            // 分钟
            Button(action: { showMinute = true }) {
                Text(String(format: "%02d", minute))
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 56, height: 48)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showMinute, arrowEdge: .bottom) {
                valuePopover(title: "分钟", range: 0...59, current: minute, format: "%02d", onSelect: { setMinute($0) }, dismiss: { showMinute = false })
            }
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
    
    // MARK: - Setters
    
    private func setHour(_ newVal: Int) {
        let cal = Calendar.current
        var comp = cal.dateComponents([.year, .month, .day, .hour, .minute], from: alarmTime)
        comp.hour = newVal
        if let d = cal.date(from: comp) { alarmTime = d }
    }
    
    private func setMinute(_ newVal: Int) {
        let cal = Calendar.current
        var comp = cal.dateComponents([.year, .month, .day, .hour, .minute], from: alarmTime)
        comp.minute = newVal
        if let d = cal.date(from: comp) { alarmTime = d }
    }
    
    private func setDate(_ newDate: Date) {
        let cal = Calendar.current
        var comp = cal.dateComponents([.year, .month, .day], from: newDate)
        let timeComp = cal.dateComponents([.hour, .minute], from: alarmTime)
        comp.hour = timeComp.hour
        comp.minute = timeComp.minute
        if let d = cal.date(from: comp) { alarmTime = d }
    }
    
    // MARK: - 日期弹窗
    
    private var datePopover: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择日期")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Divider()
            
            // 快捷选项
            ForEach(quickDates, id: \.date) { item in
                Button {
                    setDate(item.date)
                    showDate = false
                } label: {
                    HStack(spacing: 12) {
                        Text(item.label)
                            .font(.body.weight(.medium))
                        Spacer()
                        Text(item.formatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if Calendar.current.isDate(item.date, inSameDayAs: alarmTime) {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color.accentColor)
                                .font(.body.weight(.semibold))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
            }
            
            // 日历选择器
            DatePicker("", selection: Binding(
                get: { alarmTime },
                set: { setDate($0); showDate = false }
            ), displayedComponents: .date)
            .datePickerStyle(.graphical)
            .padding()
        }
        .frame(width: 280)
    }
    
    private var quickDates: [(label: String, date: Date, formatted: String)] {
        let cal = Calendar.current
        let today = Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        
        return (0...6).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let label: String
            if offset == 0 { label = "今天" }
            else if offset == 1 { label = "明天" }
            else if offset == 2 { label = "后天" }
            else { label = "\(offset)天后" }
            return (label, date, f.string(from: date))
        }
    }
    
    // MARK: - 数值大弹窗
    
    private func valuePopover(title: String, range: ClosedRange<Int>, current: Int, format: String, onSelect: @escaping (Int) -> Void, dismiss: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(range, id: \.self) { value in
                            Button {
                                onSelect(value)
                                dismiss()
                            } label: {
                                HStack(spacing: 16) {
                                    Text(String(format: format, value))
                                        .font(.title2.weight(.medium))
                                        .monospacedDigit()
                                        .foregroundColor(value == current ? Color.accentColor : .primary)
                                    Spacer()
                                    if value == current {
                                        Image(systemName: "checkmark")
                                            .font(.body.weight(.semibold))
                                            .foregroundColor(Color.accentColor)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if value != range.upperBound {
                                Divider().padding(.leading, 20)
                            }
                        }
                    }
                }
                .frame(height: 320)
                .onAppear {
                    withAnimation(.none) {
                        proxy.scrollTo(current, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 220)
    }
}
