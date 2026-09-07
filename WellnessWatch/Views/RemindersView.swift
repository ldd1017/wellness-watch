//
//  RemindersView.swift
//  WellnessWatch
//
//  第三个 Tab —— 聚合页：进食 / 睡眠 / 血压 三类提醒的快捷入口。
//  多次计时放在单独的 TimerListView。
//

import SwiftUI

struct RemindersView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                NavigationLink(destination: EatingReminderView()) {
                    tile(
                        icon: "fork.knife.circle.fill",
                        tint: .orange,
                        title: "进食节律",
                        subtitle: "吃饭时开启，节律震 + 上限强提示"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: SleepReminderView()) {
                    tile(
                        icon: "moon.zzz.fill",
                        tint: .indigo,
                        title: "睡眠提醒",
                        subtitle: "到点推送 + 触感震动"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: BloodPressureView()) {
                    tile(
                        icon: "heart.fill",
                        tint: .pink,
                        title: "血压提醒",
                        subtitle: "收缩压超过阈值时警示"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("提醒分类")
    }

    private func tile(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tint.opacity(0.06))
        )
    }
}

#Preview {
    NavigationStack { RemindersView() }
}
