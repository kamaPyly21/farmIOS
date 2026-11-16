//
//  QuestView.swift
//  Untitled Project 3
//
//  Created by камиль on 16.11.2026.
//

import SwiftUI

struct QuestsView: View {
    @ObservedObject var farm: GameState
    @ObservedObject private var quests = QuestState.shared

    var body: some View {
        List {
            Section {
                Text(
                    "Собирай продукцию и торгуй. "
                    + "После получения награды открывается "
                    + "следующее задание с увеличенной целью."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack {
                    Text("Баланс")
                    Spacer()
                    Text("\(farm.coins) монет")
                        .monospacedDigit()
                }
            }

            ForEach(FarmQuestKind.allCases) { kind in
                questSection(kind)
            }

            Section {
                Text(
                    "Продукция за выполнение квестов не списывается. "
                    + "Лишний прогресс переносится. "
                    + "Награды и читы не считаются торговой выручкой."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Квесты фермера")
    }

    private func questSection(
        _ kind: FarmQuestKind
    ) -> some View {
        let quest = quests.quest(kind)
        let ready = quest.progress >= quest.target
        let reward = kind.reward(for: quest.target)

        return Section(kind.title) {
            Text("Уровень \(quest.completedLevels + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(kind.instruction)
                .font(.headline)

            ProgressView(
                value: Double(min(quest.progress, quest.target)),
                total: Double(quest.target)
            )
            .tint(ready ? .green : .brown)

            Text(
                "\(quest.progress) / \(quest.target) \(kind.unit)"
            )
            .monospacedDigit()

            HStack {
                Text("Награда")
                Spacer()
                Text("\(reward) монет")
                    .fontWeight(.semibold)
            }

            if quest.progress > quest.target {
                Text(
                    "Лишний прогресс перейдёт в следующее задание."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Button {
                quests.claim(kind, farm: farm)
            } label: {
                Text(
                    ready
                        ? "Забрать \(reward) монет"
                        : "Задание ещё не выполнено"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brown)
            .disabled(!ready)
        }
    }
}
