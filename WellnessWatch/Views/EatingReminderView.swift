//
//  EatingReminderView.swift
//  WellnessWatch
//
//  吃饭节律页：列出已配置的 eating 计时器，用户可一键启动 / 停止。
//

import SwiftUI

struct EatingReminderView: View {

    @EnvironmentObject var timerManager: TimerManager

    @State private var showingNew = false
    @State private var now: Date = .now
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let eatings = timerManager.items.filter { $0.kind == .eating }

        return ScrollView {
            VStack(spacing: 10) {

                if let sess = timerManager.eatingSession,
                   let item = eatings.first(where: { $0.id == sess.itemId }) {
                    activeSessionCard(sess: sess, item: item)
                } else if eatings.isEmpty {
                    emptyState
                } else {
                    ForEach(eatings) { item in idleCard(item: item) }
                }

                Button {
                    showingNew = true
                } label: {
                    Label("新建吃饭提醒", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("新建吃饭提醒")
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("吃饭节律")
        .sheet(isPresented: $showingNew) {
            NavigationStack { TimerEditView() }
        }
        .onReceive(tick) { now = $0 }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("还没有吃饭提醒")
                .font(.headline)
            Text("点击下方按钮新建一个，或者在「提醒列表」中切换类型为「进食提醒」。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }

    private func activeSessionCard(sess: EatingSession, item: TimerItem) -> some View {
        let elapsed = now.timeIntervalSince(sess.startedAt)
        let total = Double(item.eatingMaxMinutes * 60)
        let progress = min(elapsed / total, 1.0)

        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "flame.fill").foregroundStyle(.red)
                Text("进行中")
                    .font(.headline)
                Spacer()
            }
            ProgressView(value: progress)
                .tint(progress >= 1 ? .red : .orange)

            HStack {
                Text("\(Int(elapsed / 60)) / \(item.eatingMaxMinutes) 分钟")
                    .monospacedDigit()
                Spacer()
                if elapsed >= total {
                    Label("已超限", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.subheadline)

            Text(item.name)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                timerManager.stopEating()
            } label: {
                Label("停止", systemImage: "stop.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.red.opacity(0.08)))
    }

    private func idleCard(item: TimerItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: item.kind.sfSymbol).foregroundStyle(.orange)
                Text(item.name).font(.headline)
                Spacer()
                if !item.isEnabled {
                    Text("未启用")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(.gray.opacity(0.2)))
                }
            }

            Text("节律 \(item.intervalSeconds / 60) 分钟 · 上限 \(item.eatingMaxMinutes) 分钟")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if !item.isEnabled {
                    Button("启用") {
                        timerManager.toggle(id: item.id)
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    timerManager.startEating(itemId: item.id)
                } label: {
                    Label("开始", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(10)
    }
}

#Preview {
    NavigationStack { EatingReminderView() }
        .environmentObject(TimerManager.shared)
}
