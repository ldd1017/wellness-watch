//
//  TimerEditView.swift
//  WellnessWatch
//
//  新建 / 编辑一个 TimerItem。4 种 kind 共用一个表单，
//  通过 Picker 切换并显示对应字段。
//
//  设计要点：
//    - 名称、kind 是所有模式必填
//    - repeated：intervalSeconds（分钟选择器）
//    - eating ：intervalSeconds（节律分钟）+ eatingMaxMinutes（上限分钟）
//    - sleep  ：小时 / 分钟 DatePicker
//    - bloodPressure ：阈值 Stepper
//

import SwiftUI

struct TimerEditView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var timerManager: TimerManager

    @State private var name: String
    @State private var kind: TimerItem.Kind
    @State private var isEnabled: Bool

    @State private var intervalMinutes: Int
    @State private var sleepHour: Int
    @State private var sleepMinute: Int
    @State private var eatingMaxMinutes: Int
    @State private var bpThreshold: Double

    private let editingId: UUID?
    private let isEditing: Bool

    init(editing: TimerItem? = nil) {
        if let e = editing {
            self.editingId = e.id
            self.isEditing = true
            _name = State(initialValue: e.name)
            _kind = State(initialValue: e.kind)
            _isEnabled = State(initialValue: e.isEnabled)
            _intervalMinutes = State(initialValue: max(1, e.intervalSeconds / 60))
            _sleepHour = State(initialValue: e.sleepAtHour)
            _sleepMinute = State(initialValue: e.sleepAtMinute)
            _eatingMaxMinutes = State(initialValue: e.eatingMaxMinutes)
            _bpThreshold = State(initialValue: e.bpSystolicThreshold)
        } else {
            self.editingId = nil
            self.isEditing = false
            _name = State(initialValue: "新提醒")
            _kind = State(initialValue: .repeated)
            _isEnabled = State(initialValue: true)
            _intervalMinutes = State(initialValue: 5)
            _sleepHour = State(initialValue: 23)
            _sleepMinute = State(initialValue: 30)
            _eatingMaxMinutes = State(initialValue: 30)
            _bpThreshold = State(initialValue: 140)
        }
    }

    var body: some View {
        Form {
            Section("基础") {
                TextField("名称", text: $name)
                    .accessibilityLabel("提醒名称")

                Picker("类型", selection: $kind) {
                    ForEach(TimerItem.Kind.allCases) { k in
                        Label(k.displayName, systemImage: k.sfSymbol).tag(k)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: kind) { _, newValue in
                    // 切换类型时把名字自动改成对应默认
                    switch newValue {
                    case .repeated:
                        name = "每 \(intervalMinutes) 分钟提醒"
                    case .eating:
                        name = "吃饭节律"
                    case .sleep:
                        name = "该睡觉了"
                    case .bloodPressure:
                        name = "血压骤升提示"
                    }
                }

                Toggle("立即启用", isOn: $isEnabled)
                    .tint(.green)
                    .accessibilityLabel("是否启用此提醒")
            }

            Section("参数") {
                kindSpecificFields
            }

            if isEditing {
                Section {
                    Button(role: .destructive) {
                        if let id = editingId {
                            timerManager.remove(id: id)
                        }
                        dismiss()
                    } label: {
                        Label("删除此提醒", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "编辑提醒" : "新建提醒")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { save() }
                    .bold()
                    .accessibilityLabel("保存提醒")
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var kindSpecificFields: some View {
        switch kind {
        case .repeated:
            Stepper(value: $intervalMinutes, in: 1...120, step: 1) {
                HStack {
                    Image(systemName: "timer")
                    Text("每隔")
                    Spacer()
                    Text("\(intervalMinutes) 分钟")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("每次间隔分钟数")

        case .eating:
            Stepper(value: $intervalMinutes, in: 1...60, step: 5) {
                HStack {
                    Image(systemName: "fork.knife")
                    Text("节律")
                    Spacer()
                    Text("\(intervalMinutes) 分钟")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Stepper(value: $eatingMaxMinutes, in: 5...180, step: 5) {
                HStack {
                    Image(systemName: "stopwatch")
                    Text("上限")
                    Spacer()
                    Text("\(eatingMaxMinutes) 分钟")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

        case .sleep:
            HStack {
                Image(systemName: "moon.zzz.fill")
                Text("时间")
                Spacer()
                Picker("小时", selection: $sleepHour) {
                    ForEach(0..<24) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: 60)
                Text(":")
                Picker("分钟", selection: $sleepMinute) {
                    ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: 70)
            }

        case .bloodPressure:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                    Text("收缩压阈值")
                    Spacer()
                    Text("\(Int(bpThreshold)) mmHg")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $bpThreshold, in: 110...200, step: 5)
                    .tint(.pink)
            }
        }
    }

    private func save() {
        let item = TimerItem(
            id: editingId ?? UUID(),
            name: name.isEmpty ? kind.displayName : name,
            kind: kind,
            isEnabled: isEnabled,
            intervalSeconds: max(60, intervalMinutes * 60),
            sleepAtHour: sleepHour,
            sleepAtMinute: sleepMinute,
            eatingMaxMinutes: max(5, eatingMaxMinutes),
            bpSystolicThreshold: bpThreshold
        )

        if isEditing {
            timerManager.update(item)
        } else {
            timerManager.add(item)
        }

        // 立即同步一次启停状态 —— 让 .sleep 重新调度通知、.repeated 启动 timer 等。
        // 注意：不要在 update/add 之前 toggle，否则旧 state 还是上一次的 isEnabled。
        let stored = timerManager.items.first(where: { $0.id == item.id })
        if stored?.isEnabled == true {
            timerManager.disarm(id: item.id) // 先 disarm 一次清掉旧 timer / 旧通知
        }
        if item.isEnabled {
            timerManager.arm(item)
        }

        // 重新校准后台 session
        timerManager.refreshRuntimeSession()

        dismiss()
    }
}

#Preview {
    NavigationStack {
        TimerEditView()
            .environmentObject(TimerManager.shared)
    }
}
