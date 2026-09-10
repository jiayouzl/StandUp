//
//  ContentView.swift
//  休息App
//

import SwiftUI
import AppKit

struct ContentView: View {
    
    @ObservedObject private var timer = TimerManager.shared
    
    @State private var editWorkMinutes: Int = 50
    @State private var editBreakMinutes: Int = 5
    @State private var editReminderText: String = ""
    @State private var newAlarmText: String = ""
    @State private var newAlarmTime: Date = Date()
    @State private var editingAlarmId: UUID? = nil
    
    private var alarmCount: Int { timer.alarms.count }
    private var alarmsFull: Bool { alarmCount >= TimerManager.maxAlarms }
    
    var body: some View {
        ZStack {
            // 菜单背景图片
            menuBgImage
            
            // 内容 + 毛玻璃
            VStack(spacing: 0) {
            // ── 顶部标题 ──
            HStack(spacing: 10) {
                Image(systemName: "moon.stars.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text("Stop working")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // ── 模式切换 ──
            HStack(spacing: 10) {
                Label("模式", systemImage: "arrow.triangle.swap")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $timer.isAlarmMode) {
                    Text("计时器").tag(false)
                    Text("闹钟").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    if timer.isAlarmMode {
                        alarmModeContent
                    } else {
                        timerModeContent
                    }
                }
                .padding(20)
            }
            
            // ── 退出 ──
            Button {
                UserDefaults.standard.removeObject(forKey: "autoRestart")
                AppDelegate.allowTerminate = true
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                    Text("退出App")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
            .frame(width: 300)
            .background(
                VisualEffectBlur(material: .menu, blendingMode: .withinWindow)
            )
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            editWorkMinutes = Int(timer.workDuration / 60)
            editBreakMinutes = Int(timer.breakActivityDuration / 60)
            editReminderText = timer.reminderText
        }
    }
    
    // MARK: - 计时器模式
    
    @ViewBuilder
    private var timerModeContent: some View {
        SettingsRow(icon: "timer", iconColor: .blue, title: "工作间隔") {
            TimeSelector(value: $editWorkMinutes, presets: [25, 30, 35, 40], range: 1...240, disabled: timer.isRunning)
        }
        Divider()
        SettingsRow(icon: "zzz", iconColor: .indigo, title: "休息活动") {
            TimeSelector(value: $editBreakMinutes, presets: [5, 10, 15], range: 1...60, disabled: timer.isRunning)
        }
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            Label("提醒文字", systemImage: "text.quote")
                .font(.subheadline).foregroundColor(.secondary)
            TextEditor(text: Binding(get: { editReminderText }, set: { editReminderText = String($0.prefix(20)) }))
                .font(.system(.body, design: .rounded))
                .frame(height: 44)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5))
                .disabled(timer.isRunning)
        }
        Divider()
        if timer.isRunning {
            Button { timer.stop() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                    Text("停止工作")
                }
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        } else {
            Button {
                timer.workDuration = TimeInterval(editWorkMinutes * 60)
                timer.breakActivityDuration = TimeInterval(editBreakMinutes * 60)
                timer.reminderText = editReminderText
                timer.start()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("开始做牛马")
                }
                .font(.body.weight(.medium)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.blue))
            }
            .buttonStyle(.plain)
        }
        if timer.isRunning { statusRow.transition(.opacity.combined(with: .move(edge: .top))) }
    }
    
    // MARK: - 闹钟模式
    
    @ViewBuilder
    private var alarmModeContent: some View {
        // ── 闹钟时间选择器 ──
        VStack(alignment: .leading, spacing: 6) {
            Label("闹钟时间", systemImage: "alarm")
                .font(.subheadline).foregroundColor(.secondary)
            HStack {
                Spacer()
                AlarmTimePicker(alarmTime: $newAlarmTime, disabled: alarmsFull)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        
        Divider()
        
        // ── 提醒文字 ──
        VStack(alignment: .leading, spacing: 8) {
            Label("提醒文字", systemImage: "text.quote")
                .font(.subheadline).foregroundColor(.secondary)
            TextEditor(text: Binding(get: { newAlarmText }, set: { newAlarmText = String($0.prefix(20)) }))
                .font(.system(.body, design: .rounded))
                .frame(height: 44)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5))
                .disabled(alarmsFull)
        }
        
        Divider()
        
        // ── 添加 / 保存按钮 ──
        if let editingId = editingAlarmId {
            HStack(spacing: 10) {
                Button {
                    editingAlarmId = nil
                    newAlarmText = ""
                    newAlarmTime = Date()
                } label: {
                    Text("取消")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button {
                    timer.updateAlarm(id: editingId, time: newAlarmTime, reminderText: newAlarmText)
                    editingAlarmId = nil
                    newAlarmText = ""
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("保存修改")
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.orange))
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                _ = timer.addAlarm(time: newAlarmTime, reminderText: newAlarmText)
                newAlarmText = ""
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: alarmsFull ? "bell.slash" : "plus.circle.fill")
                    Text(alarmsFull ? "已达上限（5个）" : "添加闹钟")
                    if !alarmsFull {
                        Text("(\(alarmCount)/\(TimerManager.maxAlarms))")
                            .font(.caption)
                    }
                }
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(alarmsFull ? Color.gray.opacity(0.08) : Color.blue))
            }
            .buttonStyle(.plain)
            .foregroundColor(alarmsFull ? .secondary : .white)
            .disabled(alarmsFull)
        }
        
        // ── 闹钟列表 ──
        if !timer.alarms.isEmpty {
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("已添加的闹钟")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(timer.alarms) { alarm in
                alarmRow(alarm)
            }
        }
    }
    
    // MARK: - 闹钟行
    
    private func alarmRow(_ alarm: AlarmItem) -> some View {
        let isEditing = editingAlarmId == alarm.id
        return Button {
            if isEditing {
                editingAlarmId = nil
                newAlarmText = ""
                newAlarmTime = Date()
            } else {
                editingAlarmId = alarm.id
                newAlarmTime = alarm.time
                newAlarmText = alarm.reminderText
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: isEditing ? "pencil.circle.fill" : "bell.fill")
                        .font(.caption)
                        .foregroundColor(isEditing ? .orange : .red)
                    Text(alarm.formattedTime)
                        .font(.body.weight(.medium))
                    Text("·")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text(alarm.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        timer.removeAlarm(id: alarm.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                if !alarm.reminderText.isEmpty {
                    Text(alarm.reminderText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 22)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isEditing ? Color.orange.opacity(0.08) : Color.gray.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isEditing ? Color.orange.opacity(0.3) : Color.gray.opacity(0.12), lineWidth: isEditing ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    
    // MARK: - 状态行
    
    private var statusRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(timer.isOnBreak ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
            Text(timer.isOnBreak ? "休息中" : "工作中")
                .font(.subheadline).foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "clock").font(.caption).foregroundColor(.secondary)
                Text(timer.formattedTimeUntilBreak)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5))
    }
    
    // MARK: - 菜单背景
    
    private var menuBgImage: some View {
        if let path = Bundle.main.path(forResource: "menu_bg", ofType: "png"),
           let nsImg = NSImage(contentsOfFile: path) {
            return AnyView(
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 300)
                    .clipped()
            )
        }
        return AnyView(EmptyView())
    }
}

// MARK: - 设置行组件

struct SettingsRow<Content: View>: View {
    let icon: String
    var iconColor: Color = .secondary
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            content
        }
    }
}
