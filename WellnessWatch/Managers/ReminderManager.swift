//
//  ReminderManager.swift
//  WellnessWatch
//
//  全局提醒偏好：
//    - eatTooMuch *  : 不要吃那么多文案（标题/正文）
//    - sleep *       : 睡眠文案
//    - bpTitle / bpBody : 血压警告文案
//    - bpThreshold   : 全局默认血压阈值（用于 new item 的初始值）
//    - notificationsAllowed : 当前通知授权状态
//
//  所有"用户偏好"字段都通过 @Published + didSet 自动同步到 UserDefaults，
//  其他 View 通过 @EnvironmentObject 双向绑定。
//

import Foundation
import SwiftUI
import Combine
import UserNotifications

@MainActor
final class ReminderManager: ObservableObject {

    static let shared = ReminderManager()

    // MARK: - 偏好

    @Published var eatTooMuchTitle: String {
        didSet { d.set(eatTooMuchTitle, forKey: K.eatTitle) }
    }
    @Published var eatTooMuchBody: String {
        didSet { d.set(eatTooMuchBody, forKey: K.eatBody) }
    }
    @Published var sleepTitle: String {
        didSet { d.set(sleepTitle, forKey: K.sleepTitle) }
    }
    @Published var sleepBody: String {
        didSet { d.set(sleepBody, forKey: K.sleepBody) }
    }
    @Published var bpTitle: String {
        didSet { d.set(bpTitle, forKey: K.bpTitle) }
    }
    @Published var bpBody: String {
        didSet { d.set(bpBody, forKey: K.bpBody) }
    }
    @Published var bpThreshold: Double {
        didSet { d.set(bpThreshold, forKey: K.bpThreshold) }
    }

    // MARK: - 运行时状态

    @Published var notificationsAllowed: Bool = false

    // MARK: - 内部

    private let d = UserDefaults.standard
    private enum K {
        static let eatTitle    = "pref.eatTooMuch.title"
        static let eatBody     = "pref.eatTooMuch.body"
        static let sleepTitle  = "pref.sleep.title"
        static let sleepBody   = "pref.sleep.body"
        static let bpTitle     = "pref.bp.title"
        static let bpBody      = "pref.bp.body"
        static let bpThreshold = "pref.bp.threshold"
    }

    private init() {
        eatTooMuchTitle = d.string(forKey: K.eatTitle) ?? "放下筷子吧 🛑"
        eatTooMuchBody  = d.string(forKey: K.eatBody)  ?? "已经吃很久了，不要再吃那么多。"
        sleepTitle      = d.string(forKey: K.sleepTitle) ?? "该睡觉啦 🌙"
        sleepBody       = d.string(forKey: K.sleepBody)  ?? "时间到了，去休息。"
        bpTitle         = d.string(forKey: K.bpTitle) ?? "血压偏高 ⚠️"
        bpBody          = d.string(forKey: K.bpBody)  ?? "深呼吸，不要冲动，等数值回落。"
        let storedBp = d.double(forKey: K.bpThreshold)
        bpThreshold = storedBp > 0 ? storedBp : 140

        Task { await self.refreshAuthStatus() }
    }

    // MARK: - 通知

    @discardableResult
    func requestNotificationAuth() async -> Bool {
        let allowed = await NotificationManager.requestAuthorization()
        await MainActor.run { self.notificationsAllowed = allowed }
        return allowed
    }

    func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.notificationsAllowed = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
        }
    }
}
