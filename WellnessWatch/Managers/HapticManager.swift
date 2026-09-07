//
//  HapticManager.swift
//  WellnessWatch
//
//  集中管理所有震动反馈。不同语义用不同触感，避免用户混淆。
//  全静态方法，可直接 HapticManager.warning() 调用。
//

import Foundation
import WatchKit

enum HapticManager {

    /// 温柔的提示音 + 震动（用于：温和计数提醒）
    static func gentle() {
        WKInterfaceDevice.current().play(.notification)
    }

    /// 警示性双震（用于：不要吃那么多 / 血压升高）
    static func warning() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    /// 强力三连震（用于：紧急 / 高血压超过阈值）
    static func strong() {
        WKInterfaceDevice.current().play(.failure)
    }

    /// 成功确认（用于：用户停止了一个计时器）
    static func success() {
        WKInterfaceDevice.current().play(.success)
    }

    /// 单击（用于：手动触发反馈）
    static func click() {
        WKInterfaceDevice.current().play(.click)
    }

    /// 根据场景挑选合适反馈
    static func play(for scene: Scene) {
        switch scene {
        case .countTick:     gentle()
        case .stopUser:      click()
        case .eatTooMuch:    warning()
        case .sleepTime:     warning()
        case .bpHigh:        strong()
        case .bpRising:      warning()
        }
    }

    enum Scene {
        case countTick      // 计数节拍
        case stopUser       // 停止计时
        case eatTooMuch     // 进食过多
        case sleepTime      // 睡眠时刻到
        case bpHigh         // 血压过高
        case bpRising       // 血压上升趋势
    }
}
