//
//  HomeView.swift
//  WellnessWatch
//
//  第一个 Tab —— 主页。展示：
//    1. 进食会话进度（大圆环 + 倒计时 + 停止按钮）
//    2. 当前激活的"多次计时"数量
//    3. 血压最近一次读数 + 状态指示
//    4. 下一次睡眠提醒倒计时
//

import SwiftUI

struct HomeView: View {

    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var healthManager: HealthManager

    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                eatingCard
                bloodPressureCard
                sleepCard
                activeLoopsCountCard
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("健康守护")
        .onReceive(tick) { now = $0 }
    }

    // MARK: - 进食会话

    @ViewBuilder
    private var eatingCard: some View {
        if let sess = timerManager.eatingSession,
           let item = timerManager.items.first(where: { $0.id == sess.itemId }) {

            let elapsedSec = now.timeIntervalSince(sess.startedAt)
            let totalSec = Double(item.eatingMaxMinutes * 60)
            let progress = min(elapsedSec / totalSec, 1.0)
            let remaining = max(totalSec - elapsedSec, 0)

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "fork.knife.circle.fill")
                        .foregroundStyle(.orange)
                    Text("进食节律")
                        .font(.headline)
                    Spacer()
                }

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.25), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(progress >= 1.0 ? Color.red : Color.orange,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progress)

                    VStack(spacing: 2) {
                        Text("\(formatMinutes(seconds: Int(remaining)))")
                            .font(.title2.bold())
                            .monospacedDigit()
                        Text("剩余")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)

                Text("已经吃了 \(Int(elapsedSec / 60)) 分钟 / 上限 \(item.eatingMaxMinutes) 分钟")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(role: .destructive) {
                    timerManager.stopEating()
                    HapticManager.success()
                } label: {
                    Label("停止", systemImage: "stop.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .accessibilityLabel("停止进食计时")
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.orange.opacity(0.08))
            )

        } else {
            // 没有进行中的 eating session —— 显示启动按钮
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.orange)
                    Text("进食节律")
                        .font(.headline)
                    Spacer()
                }

                Text("开始吃饭时点这里，按设定的节律震，到上限强力提示。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink(destination: EatingReminderView()) {
                    Label("开始", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .accessibilityLabel("进入进食提醒页")
            }
            .padding(10)
        }
    }

    // MARK: - 血压

    private var bloodPressureCard: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                Text("血压")
                    .font(.headline)
                Spacer()
            }

            if healthManager.lastSystolic > 0 {
                Text("\(Int(healthManager.lastSystolic))/\(Int(healthManager.lastDiastolic))")
                    .font(.title.bold())
                    .monospacedDigit()
                    .foregroundStyle(bpColor(systolic: healthManager.lastSystolic))

                Text(bpLabel(systolic: healthManager.lastSystolic))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let last = healthManager.lastUpdate {
                    Text("更新于 \(last, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("—")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
                Text("等待 HealthKit 数据")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            NavigationLink(destination: BloodPressureView()) {
                Text("详情")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
    }

    private func bpColor(systolic: Double) -> Color {
        switch systolic {
        case ..<120:   return .green
        case 120..<140: return .yellow
        case 140..<160: return .orange
        default:       return .red
        }
    }

    private func bpLabel(systolic: Double) -> String {
        switch systolic {
        case ..<120:   return "理想"
        case 120..<140: return "正常偏高"
        case 140..<160: return "高血压 1 级"
        default:       return "高血压 2 级 ⚠️"
        }
    }

    // MARK: - 睡眠

    private var sleepCard: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.indigo)
                Text("睡眠")
                    .font(.headline)
                Spacer()
            }

            let next = nextSleepInfo()

            Text(next.title)
                .font(.title3.bold())
                .monospacedDigit()

            Text(next.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink(destination: SleepReminderView()) {
                Text("设置")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
    }

    private func nextSleepInfo() -> (title: String, detail: String) {
        let sleepItems = timerManager.items.filter { $0.kind == .sleep && $0.isEnabled }
        guard let next = sleepItems.first else {
            return ("未启用", "前往睡眠页开启提醒")
        }
        let cal = Calendar.current
        var dc = cal.dateComponents([.year, .month, .day], from: now)
        dc.hour = next.sleepAtHour
        dc.minute = next.sleepAtMinute
        dc.second = 0

        var target = cal.date(from: dc) ?? now
        if target <= now {
            target = cal.date(byAdding: .day, value: 1, to: target) ?? target
        }
        let minutesLeft = Int(target.timeIntervalSince(now) / 60)

        let timeStr = String(format: "%02d:%02d", next.sleepAtHour, next.sleepAtMinute)
        return (timeStr, "还有 \(formatMinutes(seconds: minutesLeft * 60))")
    }

    // MARK: - 多次计时器计数

    private var activeLoopsCountCard: some View {
        let active = timerManager.items.filter {
            $0.isEnabled && $0.kind == .repeated
        }
        let totalFires = active.reduce(0) { $0 + $1.firedCount }

        return HStack {
            Image(systemName: "timer")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("多次计时器")
                    .font(.headline)
                Text("\(active.count) 个运行中，共震 \(totalFires) 次")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink(destination: TimerListView()) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
    }

    // MARK: - Util

    private func formatMinutes(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environmentObject(TimerManager.shared)
        .environmentObject(HealthManager.shared)
}
