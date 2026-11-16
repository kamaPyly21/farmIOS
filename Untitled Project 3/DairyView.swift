//
//  DairyView.swift
//  Untitled Project 3
//
//  Created by камиль on 16.11.2026.
//

import SwiftUI

struct DairyView: View {
    @ObservedObject var state: GameState

    var body: some View {
        NavigationStack {
            Form {
                recipeSection

                if state.dairyOwned {
                    productionSection
                    workerSection
                }

                upgradeSection
            }
            .navigationTitle("Сыроварня")
        }
    }

    private var recipeSection: some View {
        Section("Рецепт") {
            Text("3 молока → 1 сыр")

            LabeledContent(
                "Молоко на складе",
                value: "\(state.count(.milk))"
            )

            LabeledContent(
                "Сыр на складе",
                value: "\(state.count(.cheese))"
            )

            LabeledContent(
                "Базовая цена сыра",
                value: "\(Item.cheese.price) монет"
            )

            Text(
                "Торговая лавка и способ продажи "
                + "влияют на итоговую цену."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var productionSection: some View {
        Section("Производство") {
            LabeledContent(
                "Уровень",
                value: "\(state.dairyLevel) из 3"
            )

            LabeledContent(
                "Время новой партии",
                value: "\(Int(state.dairyBatchDuration)) сек."
            )

            LabeledContent(
                "Занято мест",
                value: "\(state.dairyOccupied)"
                    + " / \(state.dairyCapacity)"
            )

            LabeledContent(
                "Партий в работе и очереди",
                value: "\(state.dairyQueue)"
            )

            if state.dairyQueue > 0 {
                LabeledContent(
                    "До готовности",
                    value: mmss(state.dairySeconds)
                )
            }

            LabeledContent(
                "Готово к получению",
                value: "\(state.dairyReady)"
            )

            Button("Загрузить 3 молока") {
                state.queueCheese()
            }
            .disabled(!state.canQueueCheese)

            Button("Забрать сыр: \(state.dairyReady)") {
                state.collectCheese()
            }
            .disabled(state.dairyReady == 0)

            if state.dairyOccupied >= state.dairyCapacity {
                Text(
                    "Сыроварня заполнена. Дождись готовности "
                    + "и забери сыр."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var workerSection: some View {
        Section("Сыровар") {
            if state.dairyWorkerHired {
                Toggle(
                    "Автопроизводство",
                    isOn: Binding(
                        get: { state.dairyAuto },
                        set: { state.setDairyAuto($0) }
                    )
                )

                Stepper(
                    "Оставлять молока: \(state.dairyMilkReserve)",
                    value: Binding(
                        get: { state.dairyMilkReserve },
                        set: { state.setDairyMilkReserve($0) }
                    ),
                    in: 0...1000
                )

                Stepper(
                    "Запас сыра: \(state.dairyTarget)",
                    value: Binding(
                        get: { state.dairyTarget },
                        set: { state.setDairyTarget($0) }
                    ),
                    in: 1...1000
                )

                Text(
                    "Сыровар забирает готовый сыр и запускает "
                    + "новые партии, сохраняя резерв молока. "
                    + "При достижении запаса сыра он останавливается."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if state.dairyLevel >= 2 {
                Button("Нанять сыровара — 1200 монет") {
                    state.hireDairyWorker()
                }
                .disabled(!state.canHireDairyWorker)
            } else {
                Text("Найм сыровара откроется на втором уровне.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var upgradeSection: some View {
        Section(state.dairyOwned ? "Улучшение" : "Покупка") {
            if let cost = state.dairyNextCost {
                if !state.dairyOwned {
                    Text(
                        "Первый уровень: одна партия "
                        + "за 90 секунд."
                    )
                } else if state.dairyLevel == 1 {
                    Text(
                        "Второй уровень: два места, "
                        + "75 секунд на партию и доступ к сыровару."
                    )
                } else {
                    Text(
                        "Третий уровень: три места "
                        + "и 60 секунд на партию."
                    )
                }

                Button(
                    state.dairyOwned
                        ? "Улучшить — \(cost) монет"
                        : "Купить — \(cost) монет"
                ) {
                    state.buyOrUpgradeDairy()
                }
                .disabled(state.coins < cost)
            } else {
                Text("Сыроварня улучшена до максимального уровня.")
            }
        }
    }
}
