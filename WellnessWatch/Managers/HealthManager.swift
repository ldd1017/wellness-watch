//
//  HealthManager.swift
//  WellnessWatch
//
//  监听 HealthKit 中的血压数据。Apple Watch 的血压从连接的 iPhone 上的
//  健康 App 同步（实际测量通常需要第三方血压计配合）。observerQuery 检测
//  到新样本时触发回调，进而联动 TimerManager 中的 bloodPressure 计时器。
//

import Foundation
import HealthKit
import Combine

@MainActor
final class HealthManager: ObservableObject {

    static let shared = HealthManager()

    // MARK: - Published

    @Published var isAuthorized: Bool = false
    @Published var lastSystolic: Double = 0
    @Published var lastDiastolic: Double = 0
    @Published var lastUpdate: Date? = nil
    @Published var statusMessage: String = "未授权"

    // 上次报告的血压超过阈值时的回调（由 TimerManager 注册）
    var onRiseDetected: ((Double, Double) -> Void)?

    // MARK: - Private

    private let store = HKHealthStore()
    private lazy var systolicType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
    private lazy var diastolicType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
    private var anchor: HKQueryAnchor?
    private var observerQueries: [HKObserverQuery] = []

    private init() {}

    // MARK: - Auth

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let sys = systolicType,
              let dia = diastolicType else {
            await MainActor.run { self.statusMessage = "HealthKit 不可用" }
            return
        }

        let read: Set<HKObjectType> = [sys, dia]

        do {
            try await store.requestAuthorization(toShare: [], read: read)
            await MainActor.run {
                self.isAuthorized = true
                self.statusMessage = "已授权"
            }
            startObserving()
            refreshLatest()
        } catch {
            await MainActor.run {
                self.isAuthorized = false
                self.statusMessage = "授权失败：\(error.localizedDescription)"
            }
        }
    }

    // MARK: - Observer

    func startObserving() {
        guard let sys = systolicType, let dia = diastolicType else { return }

        // 先清旧 query
        observerQueries.forEach { store.stop($0) }
        observerQueries.removeAll()

        let sysQuery = HKObserverQuery(
            sampleType: sys,
            predicate: nil
        ) { [weak self] _, completion, error in
            if let error {
                NSLog("[HealthManager] sys observer err: \(error)")
                completion()
                return
            }
            Task { @MainActor in
                self?.onNewSample(kind: .systolic) { _ in completion() }
            }
        }
        store.execute(sysQuery)
        observerQueries.append(sysQuery)

        let diaQuery = HKObserverQuery(
            sampleType: dia,
            predicate: nil
        ) { [weak self] _, completion, error in
            if let error {
                NSLog("[HealthManager] dia observer err: \(error)")
                completion()
                return
            }
            Task { @MainActor in
                self?.onNewSample(kind: .diastolic) { _ in completion() }
            }
        }
        store.execute(diaQuery)
        observerQueries.append(diaQuery)

        // 让系统在数据变化时拉起 App
        if let sys = systolicType {
            store.enableBackgroundDelivery(for: sys, frequency: .immediate) { _, _ in }
        }
    }

    private enum Kind { case systolic, diastolic }

    private func onNewSample(kind: Kind, completion: @escaping (Bool) -> Void) {
        guard let type = (kind == .systolic ? systolicType : diastolicType) else {
            completion(false)
            return
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: lastUpdate,
            end: nil,
            options: .strictEndDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let self,
                  let sample = samples?.first as? HKQuantitySample else {
                completion(false)
                return
            }

            // bloodPressure 单位：mmHg，兼容 kPa 也用 mmHg 转换
            let mmHg = (kind == .systolic)
                ? sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                : sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())

            Task { @MainActor in
                if kind == .systolic {
                    self.lastSystolic = mmHg
                } else {
                    self.lastDiastolic = mmHg
                }
                self.lastUpdate = sample.endDate
                self.evaluateAndNotify()
            }
            completion(true)
        }
        store.execute(query)
    }

    /// 启动时主动拉一次最近血压
    func refreshLatest() {
        guard let sys = systolicType else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: sys,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let self,
                  let sample = samples?.first as? HKQuantitySample else { return }
            let v = sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
            Task { @MainActor in
                self.lastSystolic = v
                self.lastUpdate = sample.endDate
            }
        }
        store.execute(query)

        if let dia = diastolicType {
            let q2 = HKSampleQuery(
                sampleType: dia,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { [weak self] _, samples, _ in
                guard let self,
                      let s = samples?.first as? HKQuantitySample else { return }
                let v = s.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                Task { @MainActor in self.lastDiastolic = v }
            }
            store.execute(q2)
        }
    }

    // MARK: - 阈值判定

    /// 当新样本是 systolic 时触发 onRiseDetected，由 TimerManager 决定是否要响。
    private func evaluateAndNotify() {
        if lastSystolic > 0 {
            onRiseDetected?(lastSystolic, lastDiastolic)
        }
    }
}
