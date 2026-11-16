//
//  QuestState.swift
//  Untitled Project 3
//
//  Created by камиль on 16.11.2026.
//

import Foundation
import Combine

enum FarmQuestKind: String, CaseIterable, Identifiable, Codable {
    case wheat
    case eggs
    case revenue
    case meat
    case wool
    case milk
    case cheese
    case pie

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .wheat:
            return "Урожай пшеницы"
        case .eggs:
            return "Свежие яйца"
        case .revenue:
            return "Успешная торговля"
        case .meat:
            return "Мясная продукция"
        case .wool:
            return "Мягкая шерсть"
        case .milk:
            return "Свежее молоко"
        case .cheese:
            return "Сырное дело"
        case .pie:
            return "Мастер пирогов"
        }
    }

    var instruction: String {
        switch self {
        case .wheat:
            return "Собери пшеницу"
        case .eggs:
            return "Собери яйца"
        case .revenue:
            return "Заработай продажей продукции"
        case .meat:
            return "Получи мясо при забое животных"
        case .wool:
            return "Собери шерсть с овец"
        case .milk:
            return "Собери молоко с коров"
        case .cheese:
            return "Получи готовый сыр на склад"
        case .pie:
            return "Испеки пироги"
        }
    }

    var unit: String {
        self == .revenue ? "монет" : "шт."
    }

    var firstTarget: Int {
        switch self {
        case .wheat:
            return 10
        case .eggs:
            return 5
        case .revenue:
            return 100
        case .meat:
            return 3
        case .wool, .milk:
            return 5
        case .cheese, .pie:
            return 3
        }
    }

    func nextTarget(after target: Int) -> Int {
        let step: Int

        switch self {
        case .wheat:
            switch target {
            case ..<50:
                step = 10
            case ..<200:
                step = 25
            case ..<500:
                step = 50
            case ..<1000:
                step = 100
            default:
                step = 250
            }

        case .eggs, .wool, .milk:
            switch target {
            case ..<25:
                step = 5
            case ..<100:
                step = 10
            case ..<250:
                step = 25
            case ..<500:
                step = 50
            default:
                step = 100
            }

        case .meat, .cheese, .pie:
            switch target {
            case ..<15:
                step = 3
            case ..<50:
                step = 5
            case ..<100:
                step = 10
            default:
                step = 25
            }

        case .revenue:
            switch target {
            case ..<500:
                step = 100
            case ..<2000:
                step = 250
            case ..<5000:
                step = 500
            case ..<10000:
                step = 1000
            default:
                step = 2500
            }
        }

        return target + step
    }

    func reward(for target: Int) -> Int {
        switch self {
        case .wheat:
            let raw = 20 + target * 4 / 5
            return max(20, raw / 10 * 10)

        case .eggs:
            return 10 + target * 2

        case .revenue:
            return 10 + target / 10

        case .meat:
            return 20 + target * 5

        case .wool, .milk:
            return 15 + target * 3

        case .cheese, .pie:
            return 25 + target * 8
        }
    }
}
      
struct FarmQuestProgress: Codable {
    var target: Int
    var progress: Int = 0
    var completedLevels: Int = 0
}

final class QuestState: ObservableObject {
    static let shared = QuestState()

    private static let storageKey = "farm.quests.v1"

    @Published private(set) var records:
        [FarmQuestKind: FarmQuestProgress]

    private init() {
        let restored: [FarmQuestKind: FarmQuestProgress]

        if let data = UserDefaults.standard.data(
            forKey: Self.storageKey
        ),
           let decoded = try? JSONDecoder().decode(
               [FarmQuestKind: FarmQuestProgress].self,
               from: data
           ) {
            restored = decoded
        } else {
            restored = [:]
        }

        var result: [FarmQuestKind: FarmQuestProgress] = [:]

        for kind in FarmQuestKind.allCases {
            if let saved = restored[kind], saved.target > 0 {
                result[kind] = FarmQuestProgress(
                    target: saved.target,
                    progress: max(0, saved.progress),
                    completedLevels: max(0, saved.completedLevels)
                )
            } else {
                result[kind] = FarmQuestProgress(
                    target: kind.firstTarget
                )
            }
        }

        records = result
    }

    func quest(_ kind: FarmQuestKind) -> FarmQuestProgress {
        records[kind] ?? FarmQuestProgress(
            target: kind.firstTarget
        )
    }

    // Вызывать только при реальном сборе продукции.
    func recordHarvest(_ item: Item, quantity: Int = 1) {
        switch item {
        case .wheat:
            addProgress(to: .wheat, amount: quantity)

        case .egg:
            addProgress(to: .eggs, amount: quantity)

        case .chickenMeat, .mutton, .beef:
            addProgress(to: .meat, amount: quantity)

        case .wool:
            addProgress(to: .wool, amount: quantity)

        case .milk:
            addProgress(to: .milk, amount: quantity)

        case .cheese:
            addProgress(to: .cheese, amount: quantity)

        case .pie:
            addProgress(to: .pie, amount: quantity)

        default:
            break
        }
    }

    // Только выручка от успешных продаж.
    func recordSale(revenue: Int) {
        addProgress(to: .revenue, amount: revenue)
    }

    private func addProgress(
        to kind: FarmQuestKind,
        amount: Int
    ) {
        guard amount > 0 else { return }

        var current = quest(kind)

        let (newProgress, overflow) =
            current.progress.addingReportingOverflow(amount)

        guard !overflow else { return }

        current.progress = newProgress
        records[kind] = current
        save()
    }

    @discardableResult
    func claim(
        _ kind: FarmQuestKind,
        farm: GameState
    ) -> Bool {
        var current = quest(kind)

        guard current.progress >= current.target else {
            return false
        }

        // Защита арифметики для аномально больших сохранений.
        guard current.target <= Int.max / 10,
              current.completedLevels < Int.max else {
            return false
        }

        let reward = kind.reward(for: current.target)

        let (newCoins, overflow) =
            farm.coins.addingReportingOverflow(reward)

        guard !overflow else { return false }

        // Лишний прогресс переносится в следующий квест.
        current.progress -= current.target
        current.target = kind.nextTarget(after: current.target)
        current.completedLevels += 1

        records[kind] = current

        farm.coins = newCoins
        farm.save()
        save()

        return true
    }

    func reset() {
        var fresh: [FarmQuestKind: FarmQuestProgress] = [:]

        for kind in FarmQuestKind.allCases {
            fresh[kind] = FarmQuestProgress(
                target: kind.firstTarget
            )
        }

        records = fresh
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: Self.storageKey
        )
    }
}
