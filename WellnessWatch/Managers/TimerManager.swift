//
//  TimerManager.swift
//  WellnessWatch
//
//  多计时器调度的核心。职责：
//    1. 维护 [TimerItem] 持久化（UserDefaults JSON）
//    2. 启动 repeated / eating 计时器时，用 WKExtendedRuntimeSession 保持 App 前台
//    3. 调度 sleep 到点通知（依赖 NotificationManager）
//    4. 把 HealthManager 的血压回调接进来，转成 .bloodPressure 计时器的 fire
//    5. 不同 kind 触发不同震动语义（通过 HapticManager.Scene）
//
//  使用：
//    @StateObject var timerManager = TimerManager.shared
//    timerManager.add(.defaultRepeated(minutes: 5))
//    timerManager.toggle(id)
//    timerManager.arm(id)
//

import Foundation
import SwiftUI
import Combine
import WatchKit

@MainActor
final class TimerManager: ObservableObject {

    static let shared = TimerManager()

    // MARK: - Published

    @Published var items: [TimerItem] = []
    @Published var eatingSession: EatingSession? = nil       // 当前进食会话
    @Published var lastError: String? = nil
    @Published var runtimeIsActive: Bool = false

    // MARK: - Internal

    /// 每个 enabled 且是 periodic(repeated / eating) 的 item 用 Foundation.Timer 驱动
    private var loopTimers: [UUID: Timer] = [:]

    /// sleep / repeated 在 App 后台保活 —— watchOS 上单实例 session 即可。
    private var session: WKExtendedRuntimeSession?

    private let storageKey = "wellness.timers.v1"
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        load()
        wireHealthManager()
        // 启动时尝试激活 session（只有存在 enabled 项时才真正激活）
        refreshRuntimeSession()
        scheduleAllSleeps()
    }

    // MARK: - CRUD

    func add(_ item: TimerItem) {
        items.append(item)
        save()
    }

    func remove(id: UUID) {
        disarm(id)
        items.removeAll { $0.id == id }
        save()
    }

    func update(_ item: TimerItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
            save()
        }
    }

    /// 切换启用状态。会启停对应的循环计时器 / 睡眠通知。
    func toggle(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isEnabled.toggle()
        let item = items[idx]
        save()

        if item.isEnabled {
            arm(item)
        } else {
            disarm(id)
        }
        refreshRuntimeSession()
        scheduleAllSleeps()
    }

    /// 启用 / 重新注册某个 item
    func arm(_ item: TimerItem) {
        switch item.kind {
        case .repeated:
            scheduleRepeated(item)
        case .eating:
            // eating 由用户通过 startEating() 显式启动；
            // 这里仅当 isEnabled 时打开开关，让 startEating 可以拾起。
            break
        case .sleep:
            scheduleSleepNotification(for: item)
        case .bloodPressure:
            // 注册 HealthManager 监听
            HealthManager.shared.requestAuthorization()
        }
    }

    /// 停用某 item：释放循环 timer / 注销通知
    func disarm(id: UUID) {
        loopTimers[id]?.invalidate()
        loopTimers.removeValue(forKey: id)
        // 同步清理 scheduleSleep 时注册的 id
        NotificationManager.cancel(id: "sleep.\(id.uuidString)")
    }

    // MARK: - Repeated / 多次计时器

    private func scheduleRepeated(_ item: TimerItem) {
        loopTimers[item.id]?.invalidate()
        guard item.intervalSeconds > 0 else { return }
        let t = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(item.intervalSeconds),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.fireRepeated(itemId: item.id)
            }
        }
        // 立刻 fire 一次让用户感知
        RunLoop.main.add(t, forMode: .common)
        loopTimers[item.id] = t
        // 第一次 tick 先震一下作为确认
        HapticManager.gentle()
    }

    private func fireRepeated(itemId: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[idx].firedCount += 1
        items[idx].lastFiredAt = Date()
        save()
        HapticManager.gentle()
    }

    // MARK: - Eating

    /// 用户开启一次进食会话。会按 intervalSeconds 节律震，
    /// 当 elapsedMinutes 达到 eatingMaxMinutes 时强力震"不要吃那么多"。
    func startEating(itemId: UUID) {
        guard let item = items.first(where: { $0.id == itemId }),
              item.kind == .eating else { return }

        eatingSession = EatingSession(
            itemId: itemId,
            startedAt: Date(),
            nextTickAt: Date().addingTimeInterval(TimeInterval(item.intervalSeconds)),
            limitAt: Date().addingTimeInterval(TimeInterval(item.eatingMaxMinutes * 60)),
            hapticsToFire: .gentle
        )

        // 单独 timer 推进 eating
        loopTimers[itemId]?.invalidate()
        let t = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tickEatingSession()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        loopTimers[itemId] = t
        refreshRuntimeSession()
    }

    func stopEating() {
        guard let sess = eatingSession else { return }
        loopTimers[sess.itemId]?.invalidate()
        loopTimers.removeValue(forKey: sess.itemId)
        eatingSession = nil
        refreshRuntimeSession()
        HapticManager.success()
    }

    private func tickEatingSession() {
        guard var sess = eatingSession,
              let item = items.first(where: { $0.id == sess.itemId }) else { return }

        let now = Date()

        // 1. 节律 tick
        if now >= sess.nextTickAt {
            HapticManager.gentle()
            sess.nextTickAt = now.addingTimeInterval(TimeInterval(item.intervalSeconds))
            // 通知 App：节拍
            NotificationManager.scheduleAfter(
                id: "eating.tick.\(item.id.uuidString)",
                seconds: TimeInterval(item.intervalSeconds),
                title: "进食进行中",
                body: "已吃 \(Int(elapsedMinutes(of: sess))) 分钟，注意放慢节奏"
            )
        }

        // 2. 超过限制 → 不要吃那么多
        if now >= sess.limitAt {
            HapticManager.strong()
            // 强提示：本机强震 + 锁屏通知
            NotificationManager.scheduleAfter(
                id: "eating.tooMuch.\(item.id.uuidString)",
                seconds: 1,
                title: "已经吃了 \(item.eatingMaxMinutes) 分钟啦",
                body: "放下筷子，不要再吃那么多了 🛑"
            )
            // 推进 5 分钟再提醒一次
            sess.limitAt = now.addingTimeInterval(5 * 60)
        }

        eatingSession = sess
    }

    private func elapsedMinutes(of session: EatingSession) -> Double {
        Date().timeIntervalSince(session.startedAt) / 60.0
    }

    // MARK: - Sleep

    private func scheduleAllSleeps() {
        for item in items where item.kind == .sleep && item.isEnabled {
            scheduleSleepNotification(for: item)
        }
    }

    private func scheduleSleepNotification(for item: TimerItem) {
        let id = "sleep.\(item.id.uuidString)"
        NotificationManager.scheduleDailyAt(
            id: id,
            hour: item.sleepAtHour,
            minute: item.sleepAtMinute,
            title: "该睡觉啦 🌙",
            body: "现在 \(item.sleepAtHour):\(String(format: "%02d", item.sleepAtMinute))，放下手机去睡。"
        )
    }

    // MARK: - Blood Pressure

    private func wireHealthManager() {
        HealthManager.shared.onRiseDetected = { [weak self] sys, dia in
            Task { @MainActor in
                self?.evaluateBloodPressure(systolic: sys, diastolic: dia)
            }
        }
    }

    private func evaluateBloodPressure(systolic: Double, diastolic: Double) {
        for i in items.indices {
            guard items[i].kind == .bloodPressure, items[i].isEnabled else { continue }

            let prev = items[i].bpLastSystolic
            items[i].bpLastSystolic = systolic
            items[i].bpLastDiastolic = diastolic

            let isOverThreshold = systolic >= items[i].bpSystolicThreshold
            let isRising = prev > 0 && systolic - prev >= 10

            let snapshot = items[i]
            save()

            if isOverThreshold {
                HapticManager.strong()
                NotificationManager.scheduleAfter(
                    id: "bp.high.\(snapshot.id.uuidString)",
                    seconds: 1,
                    title: "血压偏高 ⚠️",
                    body: "收缩压 \(Int(systolic))/\(Int(diastolic)) mmHg，深呼吸，不要冲动。"
                )
            } else if isRising {
                HapticManager.warning()
                NotificationManager.scheduleAfter(
                    id: "bp.rise.\(snapshot.id.uuidString)",
                    seconds: 1,
                    title: "血压上升中",
                    body: "比上次高了 \(Int(systolic - prev)) mmHg，注意情绪。"
                )
            }
        }
    }

    // MARK: - WKExtendedRuntimeSession

    /// 当存在任何 periodic 计时器 或 eating session 时激活
    func refreshRuntimeSession() {
        let needsRuntime =
            items.contains(where: { $0.isEnabled && ($0.kind == .repeated || $0.kind == .eating) })
            || eatingSession != nil

        if needsRuntime, session == nil {
            let s = WKExtendedRuntimeSession()
            s.delegate = SessionDelegate.shared
            s.start()
            session = s
            runtimeIsActive = true
        } else if !needsRuntime, let s = session {
            s.invalidate()
            session = nil
            runtimeIsActive = false
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TimerItem].self, from: data) else {
            return
        }
        items = decoded
    }

    // MARK: - 便利工厂

    func makeDefaultRepeated(minutes: Int) -> TimerItem {
        .defaultRepeated(minutes: minutes)
    }

    func makeDefaultEating(maxMinutes: Int) -> TimerItem {
        .defaultEating(maxMinutes: maxMinutes)
    }

    func makeDefaultSleep(hour: Int, minute: Int) -> TimerItem {
        .defaultSleep(hour: hour, minute: minute)
    }

    func makeDefaultBP() -> TimerItem {
        .defaultBloodPressure()
    }
}

// MARK: - EatingSession

struct EatingSession: Equatable {
    let itemId: UUID
    let startedAt: Date
    var nextTickAt: Date
    var limitAt: Date
    var hapticsToFire: HapticManager.Scene
}

// MARK: - Session Delegate

final class SessionDelegate: NSObject, WKExtendedRuntimeSessionDelegate {
    static let shared = SessionDelegate()
    func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) { }
    func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        // 系统要回收运行时 —— 在这里最后震一次避免用户错过
        HapticManager.warning()
    }
    func extendedRuntimeSession(_ session: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) { }
}
