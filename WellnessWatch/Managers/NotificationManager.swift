//
//  NotificationManager.swift
//  WellnessWatch
//
//  本地通知封装。watchOS 上 UNUserNotificationCenter 会在屏幕亮起时
//  同步显示 banner 并触发系统触感，比单独 WKExtendedRuntimeSession 更省电。
//  对睡眠提醒这种"到点"场景特别合适 —— App 不在前台也能触发。
//

import Foundation
import UserNotifications

enum NotificationManager {

    /// 申请权限。应在 App 启动后调用一次。
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// 清理本 App 所有未发送通知
    static func clearAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// 注册一个"到达时间点"型通知（每天重复）
    /// - Parameters:
    ///   - id: 通知 identifier，用于后续 remove
    ///   - hour: 24h 制小时
    ///   - minute: 分钟
    ///   - title: 标题
    ///   - body: 正文
    static func scheduleDailyAt(
        id: String,
        hour: Int,
        minute: Int,
        title: String,
        body: String
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(req, withCompletionHandler: nil)
    }

    /// 一次性通知，N 秒后触发（用于"开始吃饭后 20 分钟震"类场景）
    static func scheduleAfter(
        id: String,
        seconds: TimeInterval,
        title: String,
        body: String
    ) {
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, seconds),
            repeats: false
        )
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    /// 移除指定 id 通知
    static func cancel(id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }
}
