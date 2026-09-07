//
//  TimerListView.swift
//  WellnessWatch
//
//  第二个 Tab —— 所有 TimerItem 列表。
//  交互（已按 watchOS HIG 调过）：
//    - 整行点按   → 弹出 sheet 进入编辑
//    - 行右侧 Toggle → 启 / 停
//    - 左滑       → 显示「删除」操作
//    - 右滑       → 显示「编辑」操作
//

import SwiftUI

struct TimerListView: View {

    @EnvironmentObject var timerManager: TimerManager

    @State private var showingNewSheet = false
    @State private var editingItem: TimerItem? = nil
    @State private var pendingDelete: TimerItem? = nil

    var body: some View {
        List {
            Section("多次计时") {
                let repeateds = timerManager.items.filter { $0.kind == .repeated }
                if repeateds.isEmpty {
                    emptyRow(text: "暂无多次计时器，点击右上 + 新建")
                } else {
                    ForEach(repeateds) { rowView($0) }
                }
            }

            Section("健康提醒") {
                let others = timerManager.items.filter { $0.kind != .repeated }
                if others.isEmpty {
                    emptyRow(text: "暂无健康提醒")
                } else {
                    ForEach(others) { rowView($0) }
                }
            }
        }
        .navigationTitle("提醒列表")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .accessibilityLabel("新建提醒")
                }
            }
        }
        .sheet(isPresented: $showingNewSheet) {
            NavigationStack { TimerEditView() }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack { TimerEditView(editing: item) }
        }
        .alert("确认删除？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let p = pendingDelete { timerManager.remove(id: p.id) }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        }
    }

    @ViewBuilder
    private func emptyRow(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }

    // MARK: - 行

    private func rowView(_ item: TimerItem) -> some View {
        Button {
            editingItem = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.kind.sfSymbol)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(subtitle(for: item))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { _ in timerManager.toggle(id: item.id) }
                ))
                .labelsHidden()
                .tint(.green)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = item
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                editingItem = item
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    private func subtitle(for item: TimerItem) -> String {
        switch item.kind {
        case .repeated:
            return "每 \(item.intervalSeconds / 60) 分钟震动 · 已震 \(item.firedCount) 次"
        case .eating:
            return "上限 \(item.eatingMaxMinutes) 分钟"
        case .sleep:
            return String(format: "每日 %02d:%02d", item.sleepAtHour, item.sleepAtMinute)
        case .bloodPressure:
            return String(format: "阈值 %d mmHg · 最新 %d/%d", Int(item.bpSystolicThreshold), Int(item.bpLastSystolic), Int(item.bpLastDiastolic))
        }
    }
}

#Preview {
    NavigationStack { TimerListView() }
        .environmentObject(TimerManager.shared)
}
