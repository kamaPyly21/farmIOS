//
//  FarmerGuideView.swift
//  Untitled Project 3
//
//  Created by камиль on 16.11.2026.
//

import SwiftUI

struct FarmerGuideView: View {
    @AppStorage("farmerGuide.step.v1")
    private var savedStep = 0

    @AppStorage("farmerGuide.completed.v1")
    private var completed = false

    @State private var collapsed = false

    private let hints: [String] = [
        """
        Привет! Начни с пшеницы: выбери её на нижней панели \
        и посади на свободной грядке.
        """,

        """
        Пока посевы растут, проверь кур. \
        Собирай готовую продукцию — она попадёт на склад.
        """,

        """
        Когда урожай созреет, собери его. \
        Количество продукции видно сверху, рядом с балансом.
        """,

        """
        Нажми «Прилавок». Там можно продать товар покупателю. \
        Если деньги нужны сразу, открой «Быструю продажу».
        """,

        """
        Загляни в улучшения через кнопку магазина. \
        Не трать все монеты: оставляй запас на семена.
        """
    ]

    private var step: Int {
        min(max(0, savedStep), hints.count - 1)
    }

    var body: some View {
        if completed {
            compactButton(
                title: "Подсказки",
                symbol: "questionmark.circle"
            ) {
                savedStep = 0
                collapsed = false
                completed = false
            }
        } else if collapsed {
            compactButton(
                title: "Совет фермера",
                symbol: "bubble.left"
            ) {
                collapsed = false
            }
        } else {
            expandedGuide
        }
    }

    private var expandedGuide: some View {
        HStack(alignment: .bottom, spacing: 8) {
            FarmerPortrait()
                .frame(width: 64, height: 100)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Совет фермера")
                        .font(.subheadline.bold())

                    Spacer(minLength: 4)

                    Text("\(step + 1)/\(hints.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        collapsed = true
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.title3)
                    }
                    .accessibilityLabel("Свернуть подсказку")
                }

                Text(hints[step])
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    if step > 0 {
                        Button("Назад") {
                            savedStep = step - 1
                        }
                    }

                    Spacer(minLength: 0)

                    Button(
                        step == hints.count - 1
                            ? "Понятно"
                            : "Дальше"
                    ) {
                        if step == hints.count - 1 {
                            completed = true
                        } else {
                            savedStep = step + 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brown)
                }

                Button("Пропустить обучение") {
                    completed = true
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        Color.brown.opacity(0.3),
                        lineWidth: 1
                    )
            }
        }
        .frame(maxWidth: 360, alignment: .leading)
    }

    private func compactButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    .regularMaterial,
                    in: Capsule()
                )
        }
        .tint(.brown)
        .buttonStyle(.plain)
    }
}

// Временный персонаж без дополнительных файлов в Assets.
// Позже можно заменить на рисованного фермера.
private struct FarmerPortrait: View {
    var body: some View {
        ZStack {
            // Вилы.
            Path { path in
                path.move(to: CGPoint(x: 54, y: 96))
                path.addLine(to: CGPoint(x: 54, y: 22))

                path.move(to: CGPoint(x: 46, y: 9))
                path.addLine(to: CGPoint(x: 46, y: 26))
                path.addLine(to: CGPoint(x: 62, y: 26))
                path.addLine(to: CGPoint(x: 62, y: 9))

                path.move(to: CGPoint(x: 54, y: 9))
                path.addLine(to: CGPoint(x: 54, y: 26))
            }
            .stroke(
                Color.brown,
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            // Тело.
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.9))
                .frame(width: 36, height: 47)
                .position(x: 26, y: 73)

            // Лямки комбинезона.
            HStack(spacing: 12) {
                Rectangle().fill(Color.blue)
                Rectangle().fill(Color.blue)
            }
            .frame(width: 22, height: 26)
            .position(x: 26, y: 63)

            RoundedRectangle(cornerRadius: 5)
                .fill(Color.blue)
                .frame(width: 29, height: 23)
                .position(x: 26, y: 84)

            // Голова.
            Circle()
                .fill(
                    Color(
                        red: 0.96,
                        green: 0.77,
                        blue: 0.58
                    )
                )
                .frame(width: 30, height: 32)
                .position(x: 26, y: 33)

            // Волосы.
            Capsule()
                .fill(Color.brown)
                .frame(width: 29, height: 10)
                .position(x: 26, y: 20)

            // Глаза.
            HStack(spacing: 7) {
                Circle().fill(Color.black)
                Circle().fill(Color.black)
            }
            .frame(width: 13, height: 3)
            .position(x: 26, y: 32)

            // Усы.
            Capsule()
                .fill(Color.brown)
                .frame(width: 13, height: 4)
                .position(x: 26, y: 40)

            // Рука у вил.
            Circle()
                .fill(
                    Color(
                        red: 0.96,
                        green: 0.77,
                        blue: 0.58
                    )
                )
                .frame(width: 10, height: 10)
                .position(x: 52, y: 62)
        }
        .frame(width: 64, height: 100)
    }
}
