//
//  TimerItem.swift
//  WellnessWatch
//
//  单个计时项的领域模型。支持 4 种模式：
//    - repeated   : 每隔 N 秒/分钟震动一次（多次计时器）
//    - eating     : 进食节律提醒（持续 N 分钟或每 M 分钟震）
//    - sleep      : 到指定时刻震一次（睡前提醒）
//    - bloodPressure : 血压升高阈值提醒
//

import Foundation

struct TimerItem: Identifiable, Codable, Equatable, Hashable {

    let id: UUID
    var name: String
    var kind: Kind
    var isEnabled: Bool

    /// repeated / eating 用的间隔（秒）。每过这个时长震一次。
    var intervalSeconds: Int

    /// sleep 用的目标时间点（当日 23:30 这种）。nil 时表示睡眠提醒未配置。
    var sleepAtHour: Int
    var sleepAtMinute: Int

    /// eating 用的最大允许持续时长（分钟）。到达上限触发"进食过多"提示。
    var eatingMaxMinutes: Int

    /// bloodPressure 用的收缩压阈值（mmHg）。默认 140。
    var bpSystolicThreshold: Double

    /// bloodPressure 用的最近一次收缩压快照（在 HealthManager 里更新）。
    var bpLastSystolic: Double
    var bpLastDiastolic: Double

    /// 记录该计时器累计已震次数（仅统计）
    var firedCount: Int

    /// 该计时器最近一次触发时间戳
    var lastFiredAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        kind: Kind,
        isEnabled: Bool = false,
        intervalSeconds: Int = 300,
        sleepAtHour: Int = 23,
        sleepAtMinute: Int = 30,
        eatingMaxMinutes: Int = 30,
        bpSystolicThreshold: Double = 140.0,
        bpLastSystolic: Double = 0,
        bpLastDiastolic: Double = 0,
        firedCount: Int = 0,
        lastFiredAt: Date = .distantPast
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isEnabled = isEnabled
        self.intervalSeconds = intervalSeconds
        self.sleepAtHour = sleepAtHour
        self.sleepAtMinute = sleepAtMinute
        self.eatingMaxMinutes = eatingMaxMinutes
        self.bpSystolicThreshold = bpSystolicThreshold
        self.bpLastSystolic = bpLastSystolic
        self.bpLastDiastolic = bpLastDiastolic
        self.firedCount = firedCount
        self.lastFiredAt = lastFiredAt
    }

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case repeated
        case eating
        case sleep
        case bloodPressure

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .repeated:       return "多次计时"
            case .eating:         return "进食提醒"
            case .sleep:          return "睡眠提醒"
            case .bloodPressure:  return "血压提醒"
            }
        }

        var sfSymbol: String {
            switch self {
            case .repeated:       return "timer"
            case .eating:         return "fork.knife"
            case .sleep:          return "moon.zzz.fill"
            case .bloodPressure:  return "heart.fill"
            }
        }
    }

    // MARK: - 便捷预设
    static func defaultRepeated(minutes: Int = 5) -> TimerItem {
        TimerItem(name: "每 \(minutes) 分钟提醒", kind: .repeated, intervalSeconds: minutes * 60)
    }

    static func defaultEating(maxMinutes: Int = 30) -> TimerItem {
        TimerItem(name: "吃饭节律", kind: .eating, intervalSeconds: 600, eatingMaxMinutes: maxMinutes)
    }

    static func defaultSleep(hour: Int = 23, minute: Int = 30) -> TimerItem {
        TimerItem(name: "该睡觉了", kind: .sleep, sleepAtHour: hour, sleepAtMinute: minute)
    }

    static func defaultBloodPressure() -> TimerItem {
        TimerItem(name: "血压骤升提示", kind: .bloodPressure, bpSystolicThreshold: 140)
    }
}
