//
//  GardenerSettingsView.swift
//  Untitled Project 3
//
//  Created by камиль on 16.11.2026.
//

import SwiftUI

struct GardenerSettingsView: View {
    @ObservedObject var farm: GameState

    var body: some View {
        Form {
            Section("Режим работы") {
                Toggle(
                    "Сажать заново после сбора",
                    isOn: $farm.gardenerAutoPlant
                )

                Text(
                    farm.gardenerAutoPlant
                        ? "Садовник собирает урожай и может "
                            + "сажать заново, сохраняя денежный резерв."
                        : "Садовник только собирает урожай. "
                            + "Монеты на семена не тратятся."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Денежный резерв") {
                Picker(
                    "Не тратить ниже",
                    selection: $farm.gardenerReserve
                ) {
                    ForEach(reserveOptions, id: \.self) { amount in
                        Text("\(amount) монет")
                            .tag(amount)
                    }
                }

                Text(
                    "Один резерв для всех садовников. "
                    + "Не ограничивает ручные покупки."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Сейчас") {
                HStack {
                    Text("Баланс")

                    Spacer()

                    Text("\(farm.coins) монет")
                        .monospacedDigit()
                }

                HStack {
                    Text("Резерв")

                    Spacer()

                    Text("\(max(0, farm.gardenerReserve)) монет")
                        .monospacedDigit()
                }
            }
        }
        .navigationTitle("Садовники")
    }

    private var reserveOptions: [Int] {
        Array(
            Set(
                [0, 50, 100, 200, 300, 500, 1000]
                + [max(0, farm.gardenerReserve)]
            )
        )
        .sorted()
    }
}
