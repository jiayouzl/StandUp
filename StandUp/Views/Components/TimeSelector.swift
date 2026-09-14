//
//  TimeSelector.swift
//  StandUp
//

import SwiftUI
import AppKit

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
        .disabled(disabled)
        .managedPopover(isPresented: $showEditor) {
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
    @State private var inputField = DurationTextField()
    
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
                            dismissEditor()
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
                    DurationInput(field: inputField, text: $customText,
                                  placeholder: "\(range.lowerBound)~\(range.upperBound)",
                                  onSubmit: submitCustom)
                        .frame(width: 80)
                    
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
        }
        .onDisappear {
            inputField.finishEditing()
        }
    }
    
    private func submitCustom() {
        guard let val = Int(customText), range.contains(val) else { return }
        currentValue = val
        dismissEditor()
    }

    private func dismissEditor() {
        inputField.finishEditing()
        isPresented = false
    }
}

// 原生输入框使用所属窗口的编辑器，避免 SwiftUI 编辑器在嵌套弹窗间残留。
private final class DurationTextField: NSTextField {
    func finishEditing() {
        guard let window, let editor = currentEditor(), window.firstResponder === editor else { return }
        window.makeFirstResponder(nil)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if window !== newWindow {
            finishEditing()
        }
        super.viewWillMove(toWindow: newWindow)
    }
}

private struct DurationInput: NSViewRepresentable {
    let field: DurationTextField
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> DurationTextField {
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.stringValue = text
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit)
        (field.cell as? NSTextFieldCell)?.sendsActionOnEndEditing = false
        return field
    }

    func updateNSView(_ field: DurationTextField, context: Context) {
        context.coordinator.parent = self
        field.placeholderString = placeholder
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    static func dismantleNSView(_ field: DurationTextField, coordinator: Coordinator) {
        field.delegate = nil
        field.target = nil
        field.finishEditing()
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DurationInput

        init(_ parent: DurationInput) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            parent.text = parent.field.stringValue
        }

        @objc func submit() {
            parent.text = parent.field.stringValue
            parent.onSubmit()
        }
    }
}
