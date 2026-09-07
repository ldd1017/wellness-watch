//
//  ContentView.swift
//  WellnessWatch
//
//  顶层 TabView。watchOS 上用 verticalPage 风格做横向滚动，
//  4 个页面：主页 / 列表 / 提醒 / 设置
//

import SwiftUI

struct ContentView: View {

    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var reminderManager = ReminderManager.shared

    @State private var selection: Int = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView() }
                .tag(0)

            NavigationStack { TimerListView() }
                .tag(1)

            NavigationStack { RemindersView() }
                .tag(2)

            NavigationStack { SettingsView() }
                .tag(3)
        }
        .tabViewStyle(.verticalPage)
        .environmentObject(timerManager)
        .environmentObject(healthManager)
        .environmentObject(reminderManager)
    }
}

#Preview {
    ContentView()
}
