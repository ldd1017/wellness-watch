//
//  BloodPressureView.swift
//  WellnessWatch
//
//  血压页：
//    - 显示 HealthKit 最近一次读数
//    - 阈值设置
//    - 启用 / 停用血压计时器
//

import SwiftUI

struct BloodPressureView: View {

    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var healthManager: HealthManager

    @State private var threshold: Double = 140
    @State private var didInitFromExisting = false
    @State private var didRequestAuth = false

    var body: some View {
        let existing = timerManager.items.first(where: { $0.kind == .bloodPressure })

        ScrollView {
            VStack(spacing: 10) {
                statusCard
                readingCard
                thresholdCard
                toggleCard(existing: existing)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("血压提醒")
        .onAppear {
            if !didRequestAuth {
                didRequestAuth = true
                Task { await healthManager.requestAuthorization() }
            }
            if !didInitFromExisting, let e = existing {
                threshold = e.bpSystolicThreshold
                didInitFromExisting = true
            }
        }
    }

    private var statusCard: some View {
        HStack {
            Image(systemName: healthManager.isAuthorized ? "checkmark.shield.fill" : "shield.slash.fill")
                .foregroundStyle(healthManager.isAuthorized ? .green : .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(healthManager.isAuthorized ? "HealthKit 已授权" : "未授权或不可用")
                    .font(.subheadline.bold())
                Text(healthManager.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !healthManager.isAuthorized {
                Button("请求") {
                    Task { await healthManager.requestAuthorization() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
    }

    private var readingCard: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                Text("最近一次")
                    .font(.headline)
                Spacer()
            }

            if healthManager.lastSystolic > 0 {
                Text("\(Int(healthManager.lastSystolic))/\(Int(healthManager.lastDiastolic))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color(for: healthManager.lastSystolic))
                Text("mmHg · \(label(for: healthManager.lastSystolic))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let last = healthManager.lastUpdate {
                    Text("更新于 \(last, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("—/—")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("等待血压数据，可从连接的 iPhone 健康 App 同步")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(10)
    }

    private var thresholdCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                Text("收缩压阈值")
                Spacer()
                Text("\(Int(threshold)) mmHg")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $threshold, in: 110...200, step: 5)
                .tint(.pink)
            Text("超过阈值会触发『血压偏高』强震 + 推送『不要冲动』提醒")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
    }

    @ViewBuilder
    private func toggleCard(existing: TimerItem?) -> some View {
        if let item = existing {
            VStack(spacing: 6) {
                Toggle("启用血压提醒", isOn: Binding(
                    get: { item.isEnabled },
                    set: { _ in
                        var v = item
                        v.bpSystolicThreshold = threshold
                        v.isEnabled.toggle()
                        timerManager.update(v)
                        timerManager.disarm(id: item.id)
                        if v.isEnabled { timerManager.arm(v) }
                    }
                ))
                .tint(.pink)

                Button("应用阈值") {
                    var v = item
                    v.bpSystolicThreshold = threshold
                    timerManager.update(v)
                }
                .buttonStyle(.bordered)
            }
            .padding(10)
        } else {
            Button {
                var item = TimerItem.defaultBloodPressure()
                item.isEnabled = true
                item.bpSystolicThreshold = threshold
                timerManager.add(item)
                timerManager.arm(item)
            } label: {
                Label("新建并启用血压提醒", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .padding(10)
        }
    }

    private func color(for systolic: Double) -> Color {
        switch systolic {
        case ..<120:   return .green
        case 120..<140: return .yellow
        case 140..<160: return .orange
        default:       return .red
        }
    }

    private func label(for systolic: Double) -> String {
        switch systolic {
        case ..<120:   return "理想"
        case 120..<140: return "正常偏高"
        case 140..<160: return "1 级高血压"
        default:       return "2 级高血压 ⚠️"
        }
    }
}

#Preview {
    NavigationStack { BloodPressureView() }
        .environmentObject(TimerManager.shared)
        .environmentObject(HealthManager.shared)
}
