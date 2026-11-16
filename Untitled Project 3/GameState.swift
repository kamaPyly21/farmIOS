import SwiftUI
import UIKit
import Combine

enum Item: String, CaseIterable, Identifiable {
    case wheat
    case carrot
    case cabbage
    case bread
    case egg
    case wool
    case milk
    case cheese
    case chickenMeat
    case mutton
    case beef
    case coal
    
    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .wheat: return "🌾"
        case .carrot: return "🥕"
        case .cabbage: return "🥬"
        case .bread: return "🍞"
        case .egg: return "🥚"
        case .wool: return "🧶"
        case .milk: return "🥛"
        case .chickenMeat: return "🍗"
        case .mutton: return "🍖"
        case .beef: return "🥩"
        case .coal: return "🪨"
        case .cheese: return "🧀"
        }
    }
    var price: Int {
        switch self {
        case .wheat: return 12
        case .carrot: return 36
        case .cabbage: return 80
        case .bread: return 40
        case .egg: return 6
        case .wool: return 28
        case .milk: return 24
        case .chickenMeat: return 45
        case .mutton: return 140
        case .beef: return 320
        case .coal: return 0
        case .cheese: return Item.milk.price * 5
        }
    }
    var sellable: Bool { self != .coal }
}

enum Crop: String, CaseIterable, Identifiable {
    case wheat, carrot, cabbage
    var id: String { rawValue }
    var item: Item {
        switch self { case .wheat: return .wheat; case .carrot: return .carrot; case .cabbage: return .cabbage }
    }
    var emoji: String { item.emoji }
    var seedCost: Int {
        switch self { case .wheat: return 5; case .carrot: return 15; case .cabbage: return 30 }
    }
    var growTime: Double {
        let base: Double
        switch self { case .wheat: base = 8; case .carrot: base = 15; case .cabbage: base = 25 }
        return base * Balance.growthTimeScale
    }
}

enum AnimalType: String, CaseIterable, Identifiable {
    case chicken, sheep, cow
    var id: String { rawValue }
    var emoji: String {
        switch self { case .chicken: return "🐔"; case .sheep: return "🐑"; case .cow: return "🐄" }
    }
    var title: String {
        switch self { case .chicken: return "Куры"; case .sheep: return "Овцы"; case .cow: return "Коровы" }
    }
    var baseCost: Int {
        switch self { case .chicken: return 40; case .sheep: return 200; case .cow: return 450 }
    }
    var baseCapacity: Int {
        switch self { case .chicken: return 6; case .sheep: return 4; case .cow: return 3 }
    }
    var penCost: Int {
        switch self { case .chicken: return 0; case .sheep: return 500; case .cow: return 1200 }
    }
    var interval: Double {
        switch self {
        case .chicken: return 10 * Balance.animalTimeScale
        case .sheep, .cow: return Balance.regrowTime
        }
    }
    var speed: Double {
        switch self { case .chicken: return 70; case .sheep: return 40; case .cow: return 30 }
    }
    var startCount: Int { self == .chicken ? 2 : 0 }
    var product: Item {
        switch self { case .chicken: return .egg; case .sheep: return .wool; case .cow: return .milk }
    }
    var meat: Item {
        switch self { case .chicken: return .chickenMeat; case .sheep: return .mutton; case .cow: return .beef }
    }
    var sound: String {
        switch self { case .chicken: return "Ко-ко!"; case .sheep: return "Бээ!"; case .cow: return "Муу!" }
    }
}

enum Upgrade: String, CaseIterable, Identifiable {
    case fertilizer, market, coop, pens, worker, pickaxe, stockkeeper
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fertilizer: return "🧪 Удобрение"
        case .market: return "🏪 Торговая лавка"
        case .coop: return "🐾 Уход за животными"
        case .pens: return "🏚 Амбар и загоны"
        case .worker: return "🧑‍🌾Садовник"
        case .stockkeeper: return "🔪Животновод"
        case .pickaxe: return "⛏ Кирка"
        }
    }
    var info: String {
        switch self {
        case .fertilizer: return "Растения растут на 15% быстрее"
        case .market: return "Цены продажи +15%"
        case .coop: return "Продукты животных появляются на 15% чаще"
        case .pens: return "+1 место для скота в каждом загоне"
        case .worker: return "+1 садовник: сам ходит по полям и собирает урожай"
        case .stockkeeper: return "+1 животновод: собирает яйца, стрижет овец и доит коров"
        case .pickaxe: return "Поход в шахту короче на 10% и +2 угля за уровень"
        }
    }
    var baseCost: Int {
        switch self {
        case .fertilizer: return 100
        case .market: return 150
        case .coop: return 120
        case .pens: return 250
        case .worker: return 400
        case .stockkeeper: return 600
        case .pickaxe: return 200
        }
    }
    var maxLevel: Int { self == .pens ? 6 : 5 }
}

enum MinePhase: String { case idle, mining, resting }

func mmss(_ s: Int) -> String {
    String(format: "%d:%02d", max(0, s) / 60, max(0, s) % 60)
}

final class GameState: ObservableObject {
    static let shared = GameState()
    static let fieldCosts = [0, 300, 800]
    static let pickaxeNames = ["Деревянная", "Каменная", "Железная", "Стальная", "Алмазная", "Мифриловая"]

    @Published var coins: Int
    @Published var inventory: [Item: Int]
    @Published var animals: [AnimalType: Int]
    @Published var penUnlocked: Set<AnimalType>
    @Published var levels: [Upgrade: Int]
    @Published var unlocked: Set<Int>
    @Published var selected: Crop = .wheat
    @Published var bakeQueue: Int
    @Published var bakeProgress: Double = 0
    @Published var bakeryOpen = false
    @Published var dairyOpen = false
    @Published var mineOpen = false
    @Published var marketOpen = false
    @Published var minePhase: MinePhase = .idle
    @Published var mineSeconds = 0
    @Published var mineProgress: Double = 0
    @Published var gameSpeed: Double = 1
    // По умолчанию садовники только собирают урожай.
    @Published var gardenerAutoPlant = false {
        didSet {
            UserDefaults.standard.set(
                gardenerAutoPlant,
                forKey: "gardenerAutoPlant"
            )
        }
    }

    // Общий резерв для всех садовников.
    @Published var gardenerReserve = 100 {
        didSet {
            UserDefaults.standard.set(
                max(0, gardenerReserve),
                forKey: "gardenerReserve"
            )
        }
    }

    var growAllRequested = false
    var onMineFinished: ((Int) -> Void)?
    private var bakeAcc: Double = 0
    private var mineStart: Double = 0
    private var mineEnd: Double = 0
    private var restEnd: Double = 0
    // MARK: Cheese dairy

    @Published var dairyLevel = 0
    @Published var dairyQueue = 0
    @Published var dairyReady = 0
    @Published var dairyFinishAt: Double = 0
    @Published var dairySeconds = 0

    @Published var dairyWorkerHired = false
    @Published var dairyAuto = false
    @Published var dairyMilkReserve = 5
    @Published var dairyTarget = 10

    private var dairyDisplayedSecond = -1

    init() {
        let d = UserDefaults.standard
        gardenerAutoPlant =
            d.object(forKey: "gardenerAutoPlant") as? Bool ?? false

        gardenerReserve = max(
            0,
            d.object(forKey: "gardenerReserve") as? Int ?? 100
        )
        coins = d.object(forKey: "coins") as? Int ?? Balance.startCoins
        var inv: [Item: Int] = [:]
        for i in Item.allCases { inv[i] = d.integer(forKey: "inv_" + i.rawValue) }
        inventory = inv
        var an: [AnimalType: Int] = [:]
        for t in AnimalType.allCases {
            an[t] = d.object(forKey: "animals_" + t.rawValue) as? Int ?? t.startCount
        }
        animals = an
        let penRaw = d.array(forKey: "pens") as? [String] ?? ["chicken"]
        penUnlocked = Set(penRaw.compactMap { AnimalType(rawValue: $0) })
        var lv: [Upgrade: Int] = [:]
        for u in Upgrade.allCases { lv[u] = d.integer(forKey: "lvl_" + u.rawValue) }
        levels = lv
        unlocked = Set(d.array(forKey: "unlocked") as? [Int] ?? [0])
        bakeQueue = d.integer(forKey: "bakeQueue")
        minePhase = MinePhase(rawValue: d.string(forKey: "minePhase") ?? "") ?? .idle
        mineStart = d.double(forKey: "mineStart")
        mineEnd = d.double(forKey: "mineEnd")
        restEnd = d.double(forKey: "restEnd")

        // MARK: Загрузка сыроварни

        dairyLevel = min(
            3,
            max(0, d.integer(forKey: "dairyLevel"))
        )

        dairyQueue = max(
            0,
            d.integer(forKey: "dairyQueue")
        )

        dairyReady = max(
            0,
            d.integer(forKey: "dairyReady")
        )

        dairyFinishAt = d.double(forKey: "dairyFinishAt")

        dairyWorkerHired = d.bool(forKey: "dairyWorkerHired")
        dairyAuto = d.bool(forKey: "dairyAuto")

        dairyMilkReserve = max(
            0,
            d.object(forKey: "dairyMilkReserve") as? Int ?? 5
        )

        dairyTarget = max(
            1,
            d.object(forKey: "dairyTarget") as? Int ?? 10
        )

        tickDairy(allowAutomation: false)
    }


    func save() {
        let d = UserDefaults.standard
        d.set(coins, forKey: "coins")
        for i in Item.allCases { d.set(inventory[i] ?? 0, forKey: "inv_" + i.rawValue) }
        for t in AnimalType.allCases { d.set(animals[t] ?? 0, forKey: "animals_" + t.rawValue) }
        d.set(penUnlocked.map { $0.rawValue }, forKey: "pens")
        for u in Upgrade.allCases { d.set(levels[u] ?? 0, forKey: "lvl_" + u.rawValue) }
        d.set(Array(unlocked), forKey: "unlocked")
        d.set(bakeQueue, forKey: "bakeQueue")
        d.set(minePhase.rawValue, forKey: "minePhase")
        d.set(mineStart, forKey: "mineStart")
        d.set(mineEnd, forKey: "mineEnd")
        d.set(restEnd, forKey: "restEnd")
        d.set(dairyLevel, forKey: "dairyLevel")
        d.set(dairyQueue, forKey: "dairyQueue")
        d.set(dairyReady, forKey: "dairyReady")
        d.set(dairyFinishAt, forKey: "dairyFinishAt")

        d.set(dairyWorkerHired, forKey: "dairyWorkerHired")
        d.set(dairyAuto, forKey: "dairyAuto")
        d.set(dairyMilkReserve, forKey: "dairyMilkReserve")
        d.set(dairyTarget, forKey: "dairyTarget")
    }

    // MARK: Stats
    func level(_ u: Upgrade) -> Int { levels[u] ?? 0 }
    func count(_ i: Item) -> Int { inventory[i] ?? 0 }
    var growMultiplier: Double { pow(0.85, Double(level(.fertilizer))) }
    var sellMultiplier: Double { 1 + 0.15 * Double(level(.market)) }
    func productInterval(_ t: AnimalType) -> Double { t.interval * pow(0.85, Double(level(.coop))) }
    func capacity(_ t: AnimalType) -> Int { t.baseCapacity + level(.pens) }
    func animalCount(_ t: AnimalType) -> Int { animals[t] ?? 0 }
    func animalCost(_ t: AnimalType) -> Int {
        Int(Double(t.baseCost) * (1 + Balance.animalPriceStep * Double(animalCount(t))))
    }
    var workerCount: Int { min(level(.worker), Balance.maxWorkers) }
    var stockkeeperCount: Int { min(level(.stockkeeper), Balance.maxWorkers)}
    func cost(of u: Upgrade) -> Int {
        Int(Double(u.baseCost) * pow(Balance.upgradeCostFactor, Double(level(u))))
    }

    var pickaxeName: String {
        GameState.pickaxeNames[min(level(.pickaxe), GameState.pickaxeNames.count - 1)]
    }
    var tripDuration: Double { Balance.mineTripTime * pow(Balance.pickaxeTimeFactor, Double(level(.pickaxe))) }
    var mineYield: Int { Balance.mineBaseYield + level(.pickaxe) * Balance.pickaxeYieldStep }

    var sellValue: Int {
        var sum = 0
        for i in Item.allCases where i.sellable { sum += count(i) * i.price }
        return Int(Double(sum) * sellMultiplier)
    }

    // MARK: Actions
    func sellAll() {
        let revenue = sellValue

        guard revenue > 0 else { return }

        let (newCoins, overflow) =
            coins.addingReportingOverflow(revenue)

        guard !overflow else { return }

        for item in Item.allCases where item.sellable {
            inventory[item] = 0
        }

        coins = newCoins
        save()

        QuestState.shared.recordSale(revenue: revenue)
    }

    func spend(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        save()
        return true
    }

    func add(_ i: Item) {
        inventory[i, default: 0] += 1
        save()
    }

    func buy(_ u: Upgrade) {
        guard level(u) < u.maxLevel, spend(cost(of: u)) else { return }
        levels[u] = level(u) + 1
        save()
    }

    func unlockField(_ i: Int) -> Bool {
        guard i < GameState.fieldCosts.count, spend(GameState.fieldCosts[i]) else { return false }
        unlocked.insert(i)
        save()
        return true
    }

    func unlockPen(_ t: AnimalType) -> Bool {
        guard !penUnlocked.contains(t), spend(t.penCost) else { return false }
        penUnlocked.insert(t)
        save()
        return true
    }

    func buyAnimal(_ t: AnimalType) {
        guard penUnlocked.contains(t), animalCount(t) < capacity(t), spend(animalCost(t)) else { return }
        animals[t] = animalCount(t) + 1
        save()
    }

    func slaughter(_ t: AnimalType) {
        guard animalCount(t) > 0 else { return }

        animals[t] = animalCount(t) - 1
        inventory[t.meat, default: 0] += 1
        save()

        QuestState.shared.recordHarvest(t.meat)
    }
    func buyCoal() {
        guard spend(Balance.coalPrice) else { return }
        inventory[.coal, default: 0] += 1
        save()
    }
    // MARK: Gardener

    /// Проверка для выбора задачи. Монеты не списывает.
    func canGardenerPlant(_ crop: Crop) -> Bool {
        guard gardenerAutoPlant else { return false }

        let seedCost = crop.seedCost
        let reserve = max(0, gardenerReserve)

        guard seedCost >= 0,
              coins >= seedCost else {
            return false
        }

        return coins - seedCost >= reserve
    }

    /// Вызывать только непосредственно перед фактической автопосадкой.
    /// Повторно проверяет настройки и баланс, затем списывает семена.
    @discardableResult
    func payForGardenerPlanting(_ crop: Crop) -> Bool {
        guard canGardenerPlant(crop) else {
            return false
        }

        coins -= crop.seedCost
        save()

        return true
    }
    // MARK: Quick sale

    func quickSellUnitPrice(_ item: Item) -> Int {
        guard item.sellable else { return 0 }

        return max(
            1,
            Int(
                (Double(item.price) * sellMultiplier * 0.60)
                    .rounded(.down)
            )
        )
    }

    @discardableResult
    func quickSell(_ item: Item, quantity: Int) -> Int {
        guard item.sellable,
              quantity > 0,
              count(item) >= quantity else {
            return 0
        }

        let unitPrice = quickSellUnitPrice(item)

        let (revenue, revenueOverflow) =
            quantity.multipliedReportingOverflow(by: unitPrice)

        guard !revenueOverflow, revenue > 0 else {
            return 0
        }

        let (newCoins, balanceOverflow) =
            coins.addingReportingOverflow(revenue)

        guard !balanceOverflow else {
            return 0
        }

        inventory[item] = count(item) - quantity
        coins = newCoins
        save()

        QuestState.shared.recordSale(revenue: revenue)

        return revenue
    }
    // MARK: Bakery
    var canBake: Bool {
        count(.wheat) >= Balance.breadWheat && count(.coal) >= Balance.coalPerBatch
    }

    func queueBake() {
        guard canBake else { return }
        inventory[.wheat, default: 0] -= Balance.breadWheat
        inventory[.coal, default: 0] -= Balance.coalPerBatch
        bakeQueue += 1
        save()
    }
    // MARK: Dairy

    var dairyOwned: Bool {
        dairyLevel > 0
    }

    var dairyCapacity: Int {
        dairyLevel
    }

    var dairyBatchDuration: Double {
        switch dairyLevel {
        case 2:
            return 75
        case 3:
            return 60
        default:
            return 90
        }
    }

    var dairyNextCost: Int? {
        switch dairyLevel {
        case 0:
            return 1000
        case 1:
            return 1500
        case 2:
            return 2500
        default:
            return nil
        }
    }

    var dairyOccupied: Int {
        dairyQueue + dairyReady
    }

    var canQueueCheese: Bool {
        dairyOwned
            && count(.milk) >= 3
            && dairyOccupied < dairyCapacity
    }

    var canHireDairyWorker: Bool {
        dairyLevel >= 2
            && !dairyWorkerHired
            && coins >= 1200
    }

    func buyOrUpgradeDairy() {
        guard let cost = dairyNextCost,
              coins >= cost else {
            return
        }

        coins -= cost
        dairyLevel += 1

        // Уже начатая партия сохраняет свой срок.
        // Новая скорость применяется к следующим партиям.
        save()
    }

    func hireDairyWorker() {
        guard canHireDairyWorker else { return }

        coins -= 1200
        dairyWorkerHired = true
        dairyAuto = true
        save()
    }

    func setDairyAuto(_ enabled: Bool) {
        dairyAuto = enabled && dairyWorkerHired
        save()
    }

    func setDairyMilkReserve(_ value: Int) {
        dairyMilkReserve = max(0, value)
        save()
    }

    func setDairyTarget(_ value: Int) {
        dairyTarget = max(1, value)
        save()
    }

    func queueCheese() {
        guard canQueueCheese else { return }

        let wasIdle = dairyQueue == 0

        inventory[.milk] = count(.milk) - 3
        dairyQueue += 1

        if wasIdle {
            dairyFinishAt =
                Date().timeIntervalSince1970 + dairyBatchDuration
            dairySeconds = Int(ceil(dairyBatchDuration))
        }

        save()
    }

    func collectCheese() {
        guard dairyReady > 0 else { return }

        inventory[.cheese, default: 0] += dairyReady
        dairyReady = 0
        save()
    }

    private func tickDairy(allowAutomation: Bool = true) {
        guard dairyOwned else { return }

        let now = Date().timeIntervalSince1970
        var changed = false

        // Защитное восстановление таймера.
        if dairyQueue > 0 && dairyFinishAt <= 0 {
            dairyFinishAt = now + dairyBatchDuration
            changed = true
        }

        // Завершаем уже загруженные партии, в том числе
        // если их время прошло, пока игра была закрыта.
        while dairyQueue > 0 && now >= dairyFinishAt {
            let completedAt = dairyFinishAt

            dairyQueue -= 1
            dairyReady += 1
            changed = true

            if dairyQueue > 0 {
                dairyFinishAt = completedAt + dairyBatchDuration
            } else {
                dairyFinishAt = 0
            }
        }

        if allowAutomation && dairyWorkerHired && dairyAuto {
            // Сыровар переносит готовую продукцию на склад.
            if dairyReady > 0 {
                inventory[.cheese, default: 0] += dairyReady
                dairyReady = 0
                changed = true
            }

            // В целевой запас включаем уже заказанные партии,
            // чтобы не производить лишнее.
            while dairyOccupied < dairyCapacity
                && count(.milk) >= 3
                && count(.milk) - 3 >= dairyMilkReserve
                && count(.cheese) + dairyQueue + dairyReady
                    < dairyTarget {

                let wasIdle = dairyQueue == 0

                inventory[.milk] = count(.milk) - 3
                dairyQueue += 1

                if wasIdle {
                    dairyFinishAt = now + dairyBatchDuration
                }

                changed = true
            }
        }

        let seconds = dairyQueue > 0
            ? max(0, Int(ceil(dairyFinishAt - now)))
            : 0

        if seconds != dairyDisplayedSecond {
            dairyDisplayedSecond = seconds
            dairySeconds = seconds
        }

        if changed {
            save()
        }
    }

    // MARK: Mine
    func startMineTrip() {
        guard minePhase == .idle else { return }
        let now = Date().timeIntervalSince1970
        mineStart = now
        mineEnd = now + tripDuration
        minePhase = .mining
        mineSeconds = Int(tripDuration)
        mineProgress = 0
        save()
    }

    private func tickMine() {
        let now = Date().timeIntervalSince1970
        switch minePhase {
        case .idle:
            if mineSeconds != 0 { mineSeconds = 0 }
        case .mining:
            if now >= mineEnd {
                let y = mineYield
                inventory[.coal, default: 0] += y
                minePhase = .resting
                restEnd = now + Balance.mineRestTime
                mineProgress = 0
                mineSeconds = Int(Balance.mineRestTime)
                save()
                onMineFinished?(y)
            } else {
                let s = Int(ceil(mineEnd - now))
                if s != mineSeconds { mineSeconds = s }
                let total = max(1, mineEnd - mineStart)
                let pr = ((now - mineStart) / total * 50).rounded(.down) / 50
                if pr != mineProgress { mineProgress = pr }
            }
        case .resting:
            if now >= restEnd {
                minePhase = .idle
                mineSeconds = 0
                save()
            } else {
                let s = Int(ceil(restEnd - now))
                if s != mineSeconds { mineSeconds = s }
            }
        }
    }

    private func tickBake(_ dt: Double) {
        guard bakeQueue > 0 else {
            if bakeProgress != 0 { bakeProgress = 0 }
            bakeAcc = 0
            return
        }
        bakeAcc += dt
        if bakeAcc >= Balance.bakeTime {
            bakeAcc = 0
            bakeQueue -= 1
            inventory[.bread, default: 0] += 1
            bakeProgress = 0
            save()
        } else {
            let step = (bakeAcc / Balance.bakeTime * 20).rounded(.down) / 20
            if step != bakeProgress { bakeProgress = step }
        }
    }

    /// Вызывается из GameScene.update каждый кадр.
    func tick(_ dt: Double) {
        tickBake(dt)
        tickMine()
        tickDairy()
    }

    // MARK: Cheats
    func cheatCoins(_ n: Int) { coins += n; save() }

    func cheatItems(_ n: Int) {
        for i in Item.allCases { inventory[i, default: 0] += n }
        save()
    }

    func cheatCoal(_ n: Int) { inventory[.coal, default: 0] += n; save() }

    func cheatUnlockAll() {
        unlocked = Set(0..<GameState.fieldCosts.count)
        penUnlocked = Set(AnimalType.allCases)
        save()
    }

    func cheatMaxUpgrades() {
        for u in Upgrade.allCases { levels[u] = u.maxLevel }
        save()
    }

    func cheatFinishMine() {
        if minePhase == .mining { mineEnd = Date().timeIntervalSince1970 }
    }

    func cheatResetRest() {
        if minePhase == .resting { restEnd = Date().timeIntervalSince1970 }
    }

    func cheatFinishBake() {
        inventory[.bread, default: 0] += bakeQueue
        bakeQueue = 0
        save()
    }

    func cheatResetAll() {
        if let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        UserDefaults.standard.synchronize()
        exit(0)
    }
}
