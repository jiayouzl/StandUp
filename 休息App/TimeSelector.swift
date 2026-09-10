//
//  TimeSelector.swift
//  休息App
//

import SwiftUI

// MARK: - 时间选择器（点击弹出 + 键盘自定义）

struct TimeSelector: View {
    @Binding var value: Int
    let presets: [Int]
    let range: ClosedRange<Int>
    var disabled: Bool = false
    
    @State private var showEditor = false
    
    var body: some View {
        Button {
            guard !disabled else { return }
            showEditor = true
        } label: {
            HStack(spacing: 4) {
                Text("\(value)")
                    .monospacedDigit()
                    .foregroundColor(disabled ? .secondary : .primary)
                Text("分钟")
                    .foregroundColor(.secondary)
            }
            .font(.body)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.gray.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showEditor, arrowEdge: .bottom) {
            TimeEditorPopover(
                currentValue: $value,
                presets: presets,
                range: range,
                isPresented: $showEditor
            )
        }
    }
}

// MARK: - 弹窗内容

struct TimeEditorPopover: View {
    @Binding var currentValue: Int
    let presets: [Int]
    let range: ClosedRange<Int>
    @Binding var isPresented: Bool
    
    @State private var customText = ""
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack(spacing: 14) {
            // ── 标题 ──
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("选择时间")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            // ── 常用预设 ──
            VStack(alignment: .leading, spacing: 8) {
                Text("常用预设")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            currentValue = preset
                            isPresented = false
                        } label: {
                            Text("\(preset)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(currentValue == preset ? .medium : .regular)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(currentValue == preset
                                              ? Color.accentColor.opacity(0.12)
                                              : Color.gray.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(currentValue == preset
                                                      ? Color.accentColor
                                                      : Color.gray.opacity(0.2),
                                                      lineWidth: currentValue == preset ? 1.5 : 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
            
            // ── 自定义输入 ──
            VStack(alignment: .leading, spacing: 8) {
                Text("自定义")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    TextField("\(range.lowerBound)~\(range.upperBound)", text: $customText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .focused($focused)
                        .onSubmit(submitCustom)
                    
                    Text("分钟")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button("确定") {
                        submitCustom()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(Int(customText).map { !range.contains($0) } ?? true)
                }
            }
        }
        .padding()
        .frame(width: 270)
        .onAppear {
            customText = "\(currentValue)"
            // 延迟一下再聚焦，让弹窗先呈现
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focused = true
            }
        }
    }
    
    private func submitCustom() {
        guard let val = Int(customText), range.contains(val) else { return }
        currentValue = val
        isPresented = false
    }
}
