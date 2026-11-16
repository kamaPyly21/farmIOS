import Foundation
import Combine

enum CustomerPhase {
    case approaching
    case waiting
    case leaving
    case pause
}

struct CustomerOrder {
    let name: String
    let item: Item
    let quantity: Int
    let basePrice: Int
}

final class MarketState: ObservableObject {
    static let shared = MarketState()

    // MARK: - Настройки

    let approachDuration: TimeInterval = 12
    let waitingDuration: TimeInterval = 180
    let leaveDuration: TimeInterval = 15

    private let pauseRange: ClosedRange<Double> = 20...40

    // MARK: - Состояние покупателя

    @Published private(set) var order: CustomerOrder?
    @Published private(set) var phase: CustomerPhase = .pause
    @Published private(set) var secondsLeft = 0
    @Published private(set) var message = ""
    @Published private(set) var angry = false

    // MARK: - Торг

    @Published private(set) var currentOffer = 0
    @Published private(set) var askingPrice = 0
    @Published private(set) var roundsLeft = 3
    @Published private(set) var agreed = false

    private var buyerBudget = 0
    private var lastAskedPrice: Int?

    // MARK: - Время

    private var started = false
    private var phaseStartedAt = Date()
    private var phaseEndsAt = Date()

    private let names = [
        "Трамп", "Мелстрой", "Камиль",
        "Рустам", "Илон Маск", "Товарищ Майор"
    ]

    private init() {}

    // Используется для движения человека на карте.
    var phaseProgress: Double {
        let duration = phaseEndsAt.timeIntervalSince(phaseStartedAt)

        guard duration > 0 else { return 1 }

        let elapsed = Date().timeIntervalSince(phaseStartedAt)

        return min(1, max(0, elapsed / duration))
    }

    var minimumPrice: Int {
        guard let order = order else { return 1 }

        return max(
            1,
            Int((Double(order.basePrice) * 0.70).rounded())
        )
    }

    var maximumPrice: Int {
        guard let order = order else { return 1 }

        let normalMaximum = max(
            minimumPrice,
            Int((Double(order.basePrice) * 1.50).rounded())
        )

        // После первого предложения можно только уступать,
        // а не поднимать свою предыдущую цену.
        if let previous = lastAskedPrice {
            return min(normalMaximum, previous)
        }

        return normalMaximum
    }

    var priceStep: Int {
        guard let order = order else { return 1 }

        return max(
            1,
            Int((Double(order.basePrice) * 0.05).rounded())
        )
    }

    var canNegotiate: Bool {
        phase == .waiting
            && !agreed
            && roundsLeft > 0
            && askingPrice != lastAskedPrice
    }

    // MARK: - Запуск и обновление

    func prepareCustomer() {
        update()
    }

    func update() {
        let now = Date()

        if !started {
            started = true
            createCustomer(now: now)
            return
        }

        switch phase {
        case .approaching:
            if now >= phaseEndsAt {
                phase = .waiting
                phaseStartedAt = now
                phaseEndsAt = now.addingTimeInterval(waitingDuration)
                secondsLeft = Int(waitingDuration)
                message = "Здравствуйте! Посмотрим, что у вас есть."
            } else {
                refreshSeconds(now: now)
            }

        case .waiting:
            if now >= phaseEndsAt {
                beginLeaving(
                    angry: true,
                    message: "Слишком долго! Я ухожу.",
                    now: now
                )
            } else {
                refreshSeconds(now: now)
            }

        case .leaving:
            if now >= phaseEndsAt {
                order = nil
                phase = .pause
                phaseStartedAt = now

                let delay = Double.random(in: pauseRange)
                phaseEndsAt = now.addingTimeInterval(delay)

                secondsLeft = Int(ceil(delay))
            } else {
                refreshSeconds(now: now)
            }

        case .pause:
            if now >= phaseEndsAt {
                createCustomer(now: now)
            } else {
                refreshSeconds(now: now)
            }
        }
    }

    private func refreshSeconds(now: Date) {
        let value = max(
            0,
            Int(ceil(phaseEndsAt.timeIntervalSince(now)))
        )

        if value != secondsLeft {
            secondsLeft = value
        }
    }

    // MARK: - Создание заказа

    private func availableProducts() -> [Item] {
        let farm = GameState.shared

        var products: [Item] = [
            .wheat,
            .carrot,
            .cabbage,
            .bread
        ]

        if farm.penUnlocked.contains(.chicken) {
            products.append(contentsOf: [.egg, .chickenMeat])
        }

        if farm.penUnlocked.contains(.sheep) {
            products.append(contentsOf: [.wool, .mutton])
        }

        if farm.penUnlocked.contains(.cow) {
            products.append(contentsOf: [.milk, .beef])
        }

        return products
    }

    private func quantityRange(
        for item: Item
    ) -> ClosedRange<Int> {
        switch item {
        case .wheat, .carrot, .cabbage:
            return 3...6

        case .egg:
            return 2...5

        case .bread, .milk, .wool:
            return 1...3

        case .chickenMeat, .mutton, .beef:
            return 1...2

        case .coal:
            return 1...1
        }
    }

    private func createCustomer(now: Date) {
        let farm = GameState.shared

        guard let item = availableProducts().randomElement(),
              let name = names.randomElement() else {
            return
        }

        let quantity = Int.random(
            in: quantityRange(for: item)
        )

        let basePrice = max(
            1,
            Int(
                (
                    Double(item.price * quantity)
                    * farm.sellMultiplier
                ).rounded()
            )
        )

        let firstOffer = max(
            1,
            Int(
                (
                    Double(basePrice)
                    * Double.random(in: 0.85...1.0)
                ).rounded()
            )
        )

        buyerBudget = max(
            firstOffer,
            Int(
                (
                    Double(basePrice)
                    * Double.random(in: 1.0...1.35)
                ).rounded()
            )
        )

        order = CustomerOrder(
            name: name,
            item: item,
            quantity: quantity,
            basePrice: basePrice
        )

        currentOffer = firstOffer
        askingPrice = basePrice

        roundsLeft = 3
        lastAskedPrice = nil
        agreed = false
        angry = false

        message = "Покупатель идёт к прилавку."

        phase = .approaching
        phaseStartedAt = now
        phaseEndsAt = now.addingTimeInterval(approachDuration)
        secondsLeft = Int(approachDuration)
    }

    // MARK: - Изменение своей цены

    func decreasePrice() {
        guard phase == .waiting,
              !agreed,
              roundsLeft > 0 else {
            return
        }

        askingPrice = max(
            minimumPrice,
            askingPrice - priceStep
        )
    }

    func increasePrice() {
        guard phase == .waiting,
              !agreed,
              roundsLeft > 0 else {
            return
        }

        askingPrice = min(
            maximumPrice,
            askingPrice + priceStep
        )
    }

    // MARK: - Переговоры

    func proposePrice() {
        update()

        guard canNegotiate else { return }

        let proposed = askingPrice

        lastAskedPrice = proposed
        roundsLeft -= 1

        if proposed <= buyerBudget {
            currentOffer = proposed
            agreed = true

            message =
                "Договорились! Беру за \(proposed) монет."

            // Не менее 10 секунд на подтверждение сделки.
            let graceDeadline = Date().addingTimeInterval(10)

            if phaseEndsAt < graceDeadline {
                phaseEndsAt = graceDeadline
            }

            refreshSeconds(now: Date())
            return
        }

        // Слишком высокая цена может сорвать сделку.
        if Double(proposed) > Double(buyerBudget) * 1.25 {
            beginLeaving(
                angry: true,
                message: "За такую цену не возьму!",
                now: Date()
            )

            return
        }

        // Покупатель делает встречное предложение.
        let counterOffer = min(
            buyerBudget,
            max(
                currentOffer,
                (currentOffer + buyerBudget) / 2
            )
        )

        currentOffer = counterOffer

        if roundsLeft > 0 {
            message =
                "Дорого. Могу предложить "
                + "\(counterOffer) монет."
        } else {
            message =
                "\(counterOffer) монет — моё последнее предложение."
        }
    }

    // MARK: - Продажа

    func sellToCustomer() {
        update()

        guard phase == .waiting,
              let currentOrder = order else {
            return
        }

        let farm = GameState.shared

        guard farm.count(currentOrder.item)
                >= currentOrder.quantity else {
            message = "Сначала подготовьте весь заказ."
            return
        }

        let earned = currentOffer

        farm.inventory[currentOrder.item, default: 0]
            -= currentOrder.quantity

        farm.coins += earned
        farm.save()

        beginLeaving(
            angry: false,
            message: "Спасибо за покупку! +\(earned) монет.",
            now: Date()
        )
    }

    func refuseCustomer() {
        update()

        guard phase == .waiting else { return }

        beginLeaving(
            angry: false,
            message: "Жаль. Поищу товар в другом месте.",
            now: Date()
        )
    }

    private func beginLeaving(
        angry: Bool,
        message: String,
        now: Date
    ) {
        self.angry = angry
        self.message = message

        phase = .leaving
        phaseStartedAt = now
        phaseEndsAt = now.addingTimeInterval(leaveDuration)

        secondsLeft = Int(leaveDuration)
    }
}
