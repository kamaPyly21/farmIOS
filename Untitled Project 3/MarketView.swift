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
        case .cheese: return "Сыр"
        case .pie: return "пирог"
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
                Section("Склад") {
                    HStack {
                        Text("Баланс")
                        
                        Spacer()
                        
                        Text("\(farm.coins) монет")
                            .monospacedDigit()
                    }
                    
                    NavigationLink {
                        QuickSaleView(game: farm)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Быстрая продажа")
                                .font(.headline)
                            
                            Text("Продать продукцию сразу за 60% цены")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Работники") {
                    NavigationLink("Настройки садовников") {
                        GardenerSettingsView(farm: farm)
                    }
                }
                
                switch market.phase {
                case .approaching:
                    Section("Покупатель идёт") {
                        if let order = market.order {
                            Text(order.name)
                                .font(.title2.bold())
                            
                            ForEach(order.items.indices, id: \.self) { index in
                                let item = order.items[index]
                                let quantity = order.quantities[index]
                                
                                Text("\(item.marketTitle) × \(quantity)")
                            }
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
            ForEach(
                Array(
                    zip(order.items, order.quantities)
                ),
                id: \.0
            ) { item, quantity in
                HStack {
                    Text(item.marketTitle)
                    
                    Spacer()
                    
                    Text("× \(quantity)")
                        .bold()
                }
                
                HStack {
                    Text("На складе")
                    
                    Spacer()
                    
                    Text(
                        "\(farm.count(item))"
                        + " / \(quantity)"
                    )
                    .foregroundColor(
                        farm.count(item) >= quantity
                        ? .primary
                        : .red
                    )
                }
            }
        }
    }
    private var bargainingSection: some View {
        Section("Торг") {
            HStack {
                Text("Твоя цена")

                Spacer()

                Text("\(market.askingPrice) монет")
                    .bold()
            }

            HStack {
                Text("Предложение покупателя")

                Spacer()

                Text("\(market.currentOffer) монет")
                    .bold()
            }

            HStack {
                Text("Осталось раундов")

                Spacer()

                Text("\(market.roundsLeft)")
            }

            HStack(spacing: 12) {
                Button("−") {
                    market.decreasePrice()
                }
                .buttonStyle(.bordered)
                .disabled(
                    market.phase != .waiting
                        || market.agreed
                        || market.roundsLeft <= 0
                        || market.askingPrice <= market.minimumPrice
                )

                Button("+") {
                    market.increasePrice()
                }
                .buttonStyle(.bordered)
                .disabled(
                    market.phase != .waiting
                        || market.agreed
                        || market.roundsLeft <= 0
                        || market.askingPrice >= market.maximumPrice
                )

                Button("Предложить") {
                    market.proposePrice()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!market.canNegotiate)
            }

            if market.agreed {
                Text("Покупатель согласился на твою цену.")
                    .foregroundColor(.green)
            } else if market.roundsLeft > 0 {
                Text(
                    "Измени свою цену и предложи её снова. "
                    + "После первого предложения цену можно "
                    + "только снижать."
                )
                .font(.caption)
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
                !market.agreed || !canSellOrder(order)
            )
            if !market.agreed {
                Text("Сначала договорись о цене.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !canSellOrder(order) {
                Text("Не хватает товаров для заказа.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Отказать покупателю") {
                market.refuseCustomer()
            }
            .foregroundColor(.red)
        }
    }
    
    private func canSellOrder(
        _ order: CustomerOrder
    ) -> Bool {
        for (index, item) in order.items.enumerated() {
            let needed = order.quantities[index]
            let available = farm.count(item)
            
            if available < needed {
                return false
            }
        }
        
        return true
    }
}
