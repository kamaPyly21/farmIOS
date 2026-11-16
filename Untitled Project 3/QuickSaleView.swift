//
//  QuickSaleView.swift
//  Untitled Project 3
//
//  Created by камиль on 16.11.2026.
//

import SwiftUI

struct QuickSaleView: View {
    @ObservedObject var game: GameState
    
    @State private var selectedItem: Item = .wheat
    @State private var quantity = 1
    @State private var message = ""
    
    private var available: Int {
        max(0, game.count(selectedItem))
    }
    
    private var selectedQuantity: Int {
        min(max(1, quantity), max(1, available))
    }
    
    private var unitPrice: Int {
        game.quickSellUnitPrice(selectedItem)
    }
    
    private var total: Int? {
        let (value, overflow) =
        selectedQuantity.multipliedReportingOverflow(by: unitPrice)
        
        return overflow ? nil : value
    }
    
    private var canSell: Bool {
        guard available > 0,
              let total,
              total > 0 else {
            return false
        }
        
        let (_, overflow) =
        game.coins.addingReportingOverflow(total)
        
        return !overflow
    }
    
    var body: some View {
        Form {
            Section {
                LabeledContent(
                    "Баланс",
                    value: "\(game.coins) монет"
                )
            }
            
            Section("Что продать") {
                Picker("Товар", selection: $selectedItem) {
                    ForEach(Item.allCases.filter { $0.sellable }) { item in
                        Text(
                            "\(item.emoji) \(item.saleTitle) — \(game.count(item)) шт."
                        )
                        .tag(item)
                    }
                }
                
                LabeledContent(
                    "На складе",
                    value: "\(available) шт."
                )
                
                LabeledContent(
                    "Цена за штуку",
                    value: "\(unitPrice) монет"
                )
                
                if available > 0 {
                    Stepper(
                        "Количество: \(selectedQuantity)",
                        value: $quantity,
                        in: 1...available
                    )
                    
                    Button("Выбрать весь остаток") {
                        quantity = available
                        message = ""
                    }
                    
                    if let total {
                        LabeledContent(
                            "Получишь",
                            value: "\(total) монет"
                        )
                    } else {
                        Text("Слишком большое количество.")
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("Этого товара пока нет на складе.")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Button {
                    let amount = selectedQuantity
                    
                    let earned = game.quickSell(
                        selectedItem,
                        quantity: amount
                    )
                    
                    if earned > 0 {
                        QuestState.shared.recordSale(revenue: earned)
                        
                        message =
                        "Продано \(amount) шт. Получено \(earned) монет."
                        quantity = 1
                    } else {
                        message =
                        "Продажа не выполнена. Проверь остаток и баланс."
                    }
                } label: {
                    Text("Продать выбранное")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canSell)
                } footer: {
                    Text(
                        "Мгновенная продажа за 60% базовой цены "
                        + "с учётом бонуса лавки и округлением вниз. "
                        + "Уголь не продаётся."
                    )
                }
                
                if !message.isEmpty {
                    Section {
                        Text(message)
                    }
                }
            }
            .navigationTitle("Быстрая продажа")
            .onChange(of: selectedItem) { _, _ in
                quantity = 1
                message = ""
            }
            .onChange(of: available) { _, newValue in
                quantity = min(
                    max(1, quantity),
                    max(1, newValue)
                )
            }
        }
    }
    
    private extension Item {
        var saleTitle: String {
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
            }
        }
    }

