//
//  SleepReminderView.swift
//  WellnessWatch
//
//  睡眠提醒页：选时间 + 启用切换。点了保存立刻注册 UNCalendarNotificationTrigger。
//

import SwiftUI

struct SleepReminderView: View {

    @EnvironmentObject var timerManager: TimerManager

    @State private var hour: Int
    @State private var minute: Int
    @State private var isEnabled: Bool
    @State private var didInitFromExisting = false

    init() {
        _hour = State(initialValue: 23)
        _minute = State(initialValue: 30)
        _isEnabled = State(initialValue: false)
    }

    var body: some View {
        let existing = timerManager.items.first(where: { $0.kind == .sleep })

        ScrollView {
            VStack(spacing: 12) {
                headerCard
                timePickerCard
                previewCard
                if existing == nil {
                    Button {
                        saveNew()
                    } label: {
                        Label("保存并启用", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                } else {
                    Button {
                        if let e = existing {
                            var item = e
                            item.isEnabled = isEnabled
                            item.sleepAtHour = hour
                            item.sleepAtMinute = minute
                            timerManager.update(item)
                            if isEnabled { timerManager.arm(item) } else { timerManager.disarm(id: item.id) }
                        }
                    } label: {
                        Label("保存", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("睡眠提醒")
        .onAppear {
            if !didInitFromExisting, let e = existing {
                hour = e.sleepAtHour
                minute = e.sleepAtMinute
                isEnabled = e.isEnabled
                didInitFromExisting = true
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.title)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("到点提醒去睡")
                    .font(.headline)
                Text("系统会在指定时间推送本地通知 + 触感震动")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
    }

    private var timePickerCard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                Picker("小时", selection: $hour) {
                    ForEach(0..<24) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Text(":")
                    .font(.title.bold())
                    .padding(.bottom, 8)

                Picker("分钟", selection: $minute) {
                    ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { v in
                        Text(String(format: "%02d", v)).tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 90)

            Toggle("启用", isOn: $isEnabled)
                .tint(.indigo)
        }
        .padding(10)
    }

    private var previewCard: some View {
        VStack(spacing: 4) {
            Text("预览")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "每天 %02d:%02d 提醒", hour, minute))
                .font(.title3.bold())
                .monospacedDigit()
            Text("「该睡觉啦 🌙」")
                .font(.caption2)
                .foregroundStyle(.indigo)
        }
        .padding(10)
    }

    private func saveNew() {
        let item = TimerItem.defaultSleep(hour: hour, minute: minute)
        var modified = item
        modified.isEnabled = true
        timerManager.add(modified)
        timerManager.arm(modified)
        isEnabled = true
    }
}

#Preview {
    NavigationStack { SleepReminderView() }
        .environmentObject(TimerManager.shared)
}
