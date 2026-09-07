//
//  WellnessWatchApp.swift
//  WellnessWatch
//
//  @main 入口。注入单例到 environment，申请通知权限，
//  并尝试激活 WKExtendedRuntimeSession —— 但实际激活由 TimerManager
//  在检测到有 periodic timer 时才进行，避免空载浪费电量。
//

import SwiftUI
import UserNotifications
import WatchKit

@main
struct WellnessWatchApp: App {

    init() {
        // 启动即申请 HealthKit / 通知权限；触感反馈推迟到首屏渲染后，避免 init 阶段 WKInterfaceDevice 尚未就绪
        Task {
            _ = await NotificationManager.requestAuthorization()
            await HealthManager.shared.requestAuthorization()
            await ReminderManager.shared.refreshAuthStatus()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // 首屏出现后做一次轻触感，确认 App 进入工作状态
                    HapticManager.click()
                }
        }
    }
}
