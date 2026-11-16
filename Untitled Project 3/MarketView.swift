import SwiftUI

extension Item {
    var marketTitle: String {
        switch self {
        case .wheat: return "Пшеница"
        case .carrot: return "Морковь"
        case .cabbage: return "Капуста"
        case .bread: return "Хлеб"
        case .egg: return "Яйца"
        case .wool: return "Шерсть"
        case .milk: return "Молоко"
        case .chickenMeat: return "Куриное мясо"
        case .mutton: return "Баранина"
        case .beef: return "Говядина"
        case .coal: return "Уголь"
        }
    }
}

struct MarketView: View {
    @ObservedObject private var market = MarketState.shared
    @ObservedObject private var farm = GameState.shared

    private var timeText: String {
        String(
            format: "%d:%02d",
            market.secondsLeft / 60,
            market.secondsLeft % 60
        )
    }

    var body: some View {
        NavigationStack {
            List {
                switch market.phase {
                case .approaching:
                    Section("Покупатель идёт") {
                        if let order = market.order {
                            Text(order.name)
                                .font(.title2.bold())

                            Text(
                                "Хочет купить: "
                                + "\(order.item.marketTitle)"
                                + " × \(order.quantity)"
                            )
                        }

                        Text("Подойдёт через \(timeText)")
                            .monospacedDigit()
                    }

                case .waiting:
                    if let order = market.order {
                        customerSection(order)
                        orderSection(order)
                        bargainingSection
                        saleSection(order)
                    }

                case .leaving:
                    Section("Покупатель уходит") {
                        Text(market.message)
                            .foregroundColor(
                                market.angry
                                    ? Color.red
                                    : Color.primary
                            )

                        Text("Уйдёт через \(timeText)")
                            .monospacedDigit()
                    }

                case .pause:
                    Section("Прилавок свободен") {
                        if !market.message.isEmpty {
                            Text(market.message)
                        }

                        Text(
                            "Новый покупатель через \(timeText)"
                        )
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Прилавок")
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            market.prepareCustomer()
        }
    }

    private func customerSection(
        _ order: CustomerOrder
    ) -> some View {
        Section("Покупатель") {
            Text(order.name)
                .font(.title2.bold())

            HStack {
                Text("Осталось ждать")

                Spacer()

                Text(timeText)
                    .monospacedDigit()
                    .bold()
                    .foregroundColor(
                        market.secondsLeft <= 30
                            ? Color.red
                            : Color.primary
                    )
            }

            Text(market.message)
                .foregroundColor(.secondary)
        }
    }

    private func orderSection(
        _ order: CustomerOrder
    ) -> some View {
        Section("Заказ") {
            HStack {
                Text(order.item.marketTitle)

                Spacer()

                Text("× \(order.quantity)")
                    .bold()
            }

            HStack {
                Text("На складе")

                Spacer()

                Text(
                    "\(farm.count(order.item))"
                    + " / \(order.quantity)"
                )
            }

            HStack {
                Text("Обычная стоимость")

                Spacer()

                Text("\(order.basePrice) монет")
            }

            HStack {
                Text("Покупатель готов заплатить")

                Spacer()

                Text("\(market.currentOffer)")
                    .bold()
                    .foregroundColor(.green)
            }
        }
    }

    private var bargainingSection: some View {
        Section("Торг") {
            if market.agreed {
                Text(
                    "Цена согласована: "
                    + "\(market.currentOffer) монет."
                )
                .font(.headline)

                Text(
                    "Подготовьте товар и подтвердите продажу."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            } else if market.roundsLeft > 0 {
                Text(
                    "Осталось предложений: "
                    + "\(market.roundsLeft)"
                )

                HStack {
                    Button {
                        market.decreasePrice()
                    } label: {
                        Text("−\(market.priceStep)")
                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        market.askingPrice <= market.minimumPrice
                    )

                    Spacer()

                    Text("\(market.askingPrice) монет")
                        .font(.title3.bold())
                        .monospacedDigit()

                    Spacer()

                    Button {
                        market.increasePrice()
                    } label: {
                        Text("+\(market.priceStep)")
                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        market.askingPrice >= market.maximumPrice
                    )
                }

                if market.askingPrice < market.currentOffer {
                    Text(
                        "Покупатель уже предлагает больше. "
                        + "Вы собираетесь уступить ему в цене."
                    )
                    .font(.caption)
                    .foregroundColor(.orange)
                }

                Button("Предложить свою цену") {
                    market.proposePrice()
                }
                .buttonStyle(.bordered)
                .disabled(!market.canNegotiate)

                Text(
                    "Высокая цена может сорвать сделку. "
                    + "После предложения свою цену "
                    + "можно только снижать."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text(
                    "Торг закончен. Можно принять "
                    + "последнее предложение или отказаться."
                )
                .foregroundColor(.secondary)
            }
        }
    }

    private func saleSection(
        _ order: CustomerOrder
    ) -> some View {
        Section("Продажа") {
            Button {
                market.sellToCustomer()
            } label: {
                Text(
                    "Продать за \(market.currentOffer) монет"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                farm.count(order.item) < order.quantity
            )

            if farm.count(order.item) < order.quantity {
                Text(
                    "Не хватает: "
                    + "\(order.quantity - farm.count(order.item))"
                    + " шт."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Button("Отказать покупателю") {
                market.refuseCustomer()
            }
            .foregroundColor(.red)
        }
    }
}
