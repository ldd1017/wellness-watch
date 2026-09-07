//
//  SettingsView.swift
//  WellnessWatch
//
//  第四个 Tab —— App 设置：
//    - 全局提示文案（吃太多 / 血压高 / 睡觉）
//    - HealthKit / 通知权限状态
//    - 全部停用 / 重置
//    - About
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var reminderManager: ReminderManager

    @State private var showingResetAlert = false

    var body: some View {
        List {
            Section("通知") {
                HStack {
                    Image(systemName: "bell.badge.fill")
                    Text("通知权限")
                    Spacer()
                    Text(reminderManager.notificationsAllowed ? "已开" : "未开")
                        .foregroundStyle(reminderManager.notificationsAllowed ? .green : .secondary)
                }
                if !reminderManager.notificationsAllowed {
                    Button("请求通知权限") {
                        Task { await reminderManager.requestNotificationAuth() }
                    }
                }
            }

            Section("HealthKit") {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                    Text("血压读取")
                    Spacer()
                    Text(healthManager.isAuthorized ? "已授权" : "未授权")
                        .foregroundStyle(healthManager.isAuthorized ? .green : .secondary)
                }
                if !healthManager.isAuthorized {
                    Button("请求血压权限") {
                        Task { await healthManager.requestAuthorization() }
                    }
                }
            }

            Section("全局文案") {
                TextField("不要吃那么多 · 标题", text: $reminderManager.eatTooMuchTitle)
                TextField("不要吃那么多 · 正文", text: $reminderManager.eatTooMuchBody, axis: .vertical)
                    .lineLimit(1...3)

                TextField("睡眠 · 标题", text: $reminderManager.sleepTitle)
                TextField("睡眠 · 正文", text: $reminderManager.sleepBody, axis: .vertical)
                    .lineLimit(1...3)

                TextField("血压 · 标题", text: $reminderManager.bpTitle)
                TextField("血压 · 正文", text: $reminderManager.bpBody, axis: .vertical)
                    .lineLimit(1...3)

                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("血压默认阈值")
                    Spacer()
                    Text("\(Int(reminderManager.bpThreshold)) mmHg")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $reminderManager.bpThreshold, in: 110...200, step: 5)
                    .tint(.pink)
            }

            Section("运行时") {
                HStack {
                    Image(systemName: timerManager.runtimeIsActive ? "bolt.fill" : "bolt.slash")
                        .foregroundStyle(timerManager.runtimeIsActive ? .yellow : .gray)
                    Text("后台 Session")
                    Spacer()
                    Text(timerManager.runtimeIsActive ? "活跃" : "未激活")
                        .foregroundStyle(timerManager.runtimeIsActive ? .green : .secondary)
                }
                Text("当存在多次计时器或进食会话时自动激活。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    Label("清空所有提醒", systemImage: "trash")
                }
            }

            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0").foregroundStyle(.secondary)
                }
                Text("WellnessWatch · 健康守护")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .alert("确认清空所有提醒？", isPresented: $showingResetAlert) {
            Button("清空", role: .destructive) {
                for item in timerManager.items {
                    timerManager.remove(id: item.id)
                }
                HapticManager.success()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有计时器和提醒将不再触发。")
        }
        .task {
            await reminderManager.refreshAuthStatus()
            await healthManager.requestAuthorization()
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(TimerManager.shared)
        .environmentObject(HealthManager.shared)
        .environmentObject(ReminderManager.shared)
}
