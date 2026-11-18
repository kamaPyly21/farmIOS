import SwiftUI
import SpriteKit
import Combine

@main
struct FarmApp: App {
    var body: some Scene {
        WindowGroup {
            GameContainer()
                .ignoresSafeArea()
        }
    }
}

enum ActiveSheet: String, Identifiable {
    case shop, animals, bakery, mine, cheats, market, quests, dairy
    var id: String { rawValue }
}

struct GameContainer: View {
    @StateObject private var state = GameState.shared
    @State private var sheet: ActiveSheet?
    @State private var scene: GameScene = {
        let s = GameScene(size: CGSize(width: 390, height: 844))
        s.scaleMode = .resizeFill
        return s
    }()

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
            VStack(spacing: 8) {
                topBar

                Spacer()

                HStack {
                    FarmerGuideView()

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 4)

                seedBar
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 50)
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .shop: ShopView(state: state)
            case .animals: AnimalsView(state: state)
            case .bakery: BakeryView(state: state)
            case .mine: MineView(state: state)
            case .cheats: CheatsView(state: state)
            case .market: MarketView()
            case .quests: NavigationStack {
                       QuestsView(farm: state)
                   }
            case .dairy:
                    DairyView(state: state)
            }
        }
        .onReceive(state.$bakeryOpen) { open in
            if open {
                DispatchQueue.main.async {
                    sheet = .bakery
                    state.bakeryOpen = false
                }
            }
        }
        .onReceive(state.$dairyOpen) { open in
                    if open {
                        DispatchQueue.main.async {
                            sheet = .dairy
                            state.dairyOpen = false
                        }
                    }
                }
        .onReceive(state.$mineOpen) { open in
            if open {
                DispatchQueue.main.async {
                    sheet = .mine
                    state.mineOpen = false
                }
            }
        }
        .onReceive(state.$marketOpen) { open in
            if open {
                DispatchQueue.main.async {
                    sheet = .market
                    state.marketOpen = false
                }
            }
        }
    }

    func pill(_ text: String) -> some View {
        Text(text).font(.subheadline.bold())
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
    }

    var topBar: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    sheet = .quests
                } label: {
                    Label(
                        "Квесты фермера",
                        systemImage: "list.bullet.clipboard"
                    )
                    .font(.subheadline.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        .regularMaterial,
                        in: Capsule()
                    )
                }
                .tint(.brown)

                Spacer()
            }
            HStack(spacing: 6) {
                Text("🪙 \(state.coins)")
                    .font(.title3.bold())
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                Spacer()
                Button { sheet = .bakery } label: { pill("🍞") }
                Button {
                    sheet = .dairy
                } label: {
                    pill("🧀")
                }
                .accessibilityLabel("Сыроварня")
                Button { sheet = .mine } label: { pill("⛏") }
                Button { sheet = .animals } label: { pill("🐾") }
                Button { sheet = .shop } label: { pill("🛒") }
                #if DEBUG
                Button { sheet = .cheats } label: { pill("🛠") }
                #endif
            }
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        let items = Item.allCases.filter { state.count($0) > 0 }
                        if items.isEmpty {
                            Text("Склад пуст").foregroundColor(.secondary)
                        }
                        ForEach(items) { i in
                            Text("\(i.emoji) \(state.count(i))")
                        }
                    }
                    .font(.headline)
                    .padding(.horizontal, 12)
                }
                .frame(height: 36)
                .background(.ultraThinMaterial, in: Capsule())

                Button {
                    sheet = .market
                } label: {
                    Text("Прилавок")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.brown, in: Capsule())
                        .foregroundColor(.white)
                }
            }
        }
    }

    var seedBar: some View {
        HStack(spacing: 10) {
            ForEach(Crop.allCases) { c in
                Button { state.selected = c } label: {
                    VStack(spacing: 2) {
                        Text(c.emoji).font(.title)
                        Text("\(c.seedCost) 🪙").font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(state.selected == c ? Color.yellow.opacity(0.9) : Color.white.opacity(0.7),
                                in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.brown, lineWidth: state.selected == c ? 3 : 1))
                    .foregroundColor(.black)
                }
            }
        }
    }
}

struct ShopView: View {
    @ObservedObject var state: GameState

    var body: some View {
        NavigationStack {
            List(Upgrade.allCases) { u in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(u.title)  \(state.level(u))/\(u.maxLevel)").font(.headline)
                        Text(u.info).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if state.level(u) >= u.maxLevel {
                        Text("MAX").bold()
                    } else {
                        Button("\(state.cost(of: u)) 🪙") { state.buy(u) }
                            .buttonStyle(.borderedProminent)
                            .disabled(state.coins < state.cost(of: u))
                    }
                }
            }
            .navigationTitle("Улучшения")
        }
        .presentationDetents([.medium, .large])
    }
}

struct AnimalsView: View {
    @ObservedObject var state: GameState

    var body: some View {
        NavigationStack {
            List {
                ForEach(AnimalType.allCases) { t in
                    Section("\(t.emoji) \(t.title)") {
                        if !state.penUnlocked.contains(t) {
                            Button("Открыть загон — \(t.penCost) 🪙") { _ = state.unlockPen(t) }
                                .buttonStyle(.borderedProminent)
                                .disabled(state.coins < t.penCost)
                        } else {
                            HStack {
                                Text("Сейчас: \(state.animalCount(t)) / \(state.capacity(t))").font(.headline)
                                Spacer()
                                if state.animalCount(t) >= state.capacity(t) {
                                    Text("Загон полон").foregroundColor(.secondary)
                                } else {
                                    Button("Купить \(state.animalCost(t)) 🪙") { state.buyAnimal(t) }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(state.coins < state.animalCost(t))
                                }
                            }
                            Text(t.careInfo(state))
                                .font(.caption).foregroundColor(.secondary)
                            HStack {
                                Text("На мясо: \(t.meat.emoji) \(t.meat.price) 🪙")
                                Spacer()
                                Button("Забить") { state.slaughter(t) }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                    .disabled(state.animalCount(t) == 0)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Животные")
        }
        .presentationDetents([.medium, .large])
    }
}

struct BakeryView: View {
    @ObservedObject var state: GameState

    var body: some View {
        NavigationStack {
            List {
                upgradeSection
                fuelSection
                breadSection
                pieSection
            }
            .navigationTitle("Пекарня")
        }
        .presentationDetents([.medium, .large])
    }

    private var upgradeSection: some View {
        Section("Уровень пекарни") {
            Text("Уровень \(state.bakeryLevel) из 3")
                .font(.headline)

            Text(
                "Хлеб: \(mmss(Int(ceil(state.breadDuration))))"
                + " · Пирог: \(mmss(Int(ceil(state.pieDuration))))"
            )

            Text(
                "Уровень сокращает время следующих партий. "
                + "Хлеб и пироги выпекаются в отдельных очередях."
            )
            .font(.caption)
            .foregroundColor(.secondary)

            if let cost = state.bakeryUpgradeCost {
                Button("Улучшить — \(cost) монет") {
                    state.upgradeBakery()
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.coins < cost)
            } else {
                Text("Максимальный уровень")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var fuelSection: some View {
        Section("Топливо") {
            Text("Уголь на складе: \(state.count(.coal))")

            Button("Купить уголь — \(Balance.coalPrice) монет") {
                state.buyCoal()
            }
            .buttonStyle(.bordered)
            .disabled(state.coins < Balance.coalPrice)

            Text("Уголь также можно добыть в шахте.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var breadSection: some View {
        Section("Хлеб") {
            Text(
                "\(Balance.breadWheat) пшеницы"
                + " + \(Balance.coalPerBatch) угля → 1 хлеб"
            )
            .font(.headline)

            Text("Пшеница на складе: \(state.count(.wheat))")

            Text("В очереди, включая текущий: \(state.bakeQueue)")

            if state.bakeQueue > 0 {
                ProgressView(value: state.bakeProgress)
            }

            Button("Добавить хлеб в очередь") {
                state.queueBake()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!state.canBake)

            Text("Готового хлеба: \(state.count(.bread))")

            Text("Базовая цена: \(Item.bread.price) монет")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var pieSection: some View {
        Section("Пироги") {
            Text("2 пшеницы + 1 молоко + 1 яйцо + 1 уголь")
                .font(.headline)

            Text(
                "Пшеница: \(state.count(.wheat))"
                + " · Молоко: \(state.count(.milk))"
                + " · Яйца: \(state.count(.egg))"
            )
            .font(.caption)

            Text("В очереди, включая текущий: \(state.pieQueue)")

            if state.pieIsBaking {
                Text("До следующего пирога: \(mmss(state.pieSeconds))")
                ProgressView(value: state.pieProgress)
            }

            Button("Добавить пирог в очередь") {
                state.startPie()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!state.canBakePie)

            Text("Готовых пирогов: \(state.count(.pie))")

            Text("Базовая цена: \(Item.pie.price) монет")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Готовая выпечка автоматически поступает на склад.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CheatsView: View {
    @ObservedObject var state: GameState

    var body: some View {
        NavigationStack {
            List {
                Section("Деньги и склад") {
                    Button("+1 000 🪙") { state.cheatCoins(1_000) }
                    Button("+100 000 🪙") { state.cheatCoins(100_000) }
                    Button("+10 каждого предмета") { state.cheatItems(10) }
                    Button("+20 угля 🪨") { state.cheatCoal(20) }
                }
                Section("Мир") {
                    Button("Открыть все поля и загоны") { state.cheatUnlockAll() }
                    Button("Максимум всех улучшений") { state.cheatMaxUpgrades() }
                    Button("Вырастить все посевы") { state.growAllRequested = true }
                }
                Section("Время") {
                    Picker("Скорость игры", selection: $state.gameSpeed) {
                        Text("x1").tag(1.0)
                        Text("x5").tag(5.0)
                        Text("x20").tag(20.0)
                    }
                    .pickerStyle(.segmented)
                    Button("Завершить поход в шахту") { state.cheatFinishMine() }
                    Button("Сбросить отдых шахты") { state.cheatResetRest() }
                    Button("Допечь весь хлеб") { state.cheatFinishBake() }
                }
                Section("Опасно") {
                    Button("Сбросить прогресс (закроет приложение)", role: .destructive) {
                        state.cheatResetAll()
                    }
                }
            }
            .navigationTitle("🛠 Читы")
        }
        .presentationDetents([.medium, .large])
    }
}
struct MineView: View {
    @ObservedObject var state: GameState

    var body: some View {
        NavigationStack {
            List {
                mineInfoSection
                statusSection
                upgradeSection
            }
            .navigationTitle("Шахта")
        }
        .presentationDetents([.medium, .large])
    }

    private var mineInfoSection: some View {
        Section("Шахта") {
            Text(
                "Кирка: \(state.pickaxeName)"
                + " (ур. \(state.level(.pickaxe)))"
            )
            .font(.headline)

            Text(
                "Поход: \(mmss(Int(state.tripDuration)))"
                + " · Добыча: \(state.mineYield) угля"
                + " · Отдых: \(mmss(Int(Balance.mineRestTime)))"
            )
            .font(.caption)
            .foregroundColor(.secondary)

            Text("Уголь на складе: \(state.count(.coal))")
        }
    }

    private var statusSection: some View {
        Section("Статус") {
            switch state.minePhase {
            case .idle:
                Button("Отправиться в шахту") {
                    state.startMineTrip()
                }
                .buttonStyle(.borderedProminent)

            case .mining:
                Text(
                    "Шахтёр копает… осталось "
                    + mmss(state.mineSeconds)
                )

                ProgressView(value: state.mineProgress)

            case .resting:
                Text(
                    "Шахтёр отдыхает: "
                    + mmss(state.mineSeconds)
                )
            }
        }
    }

    private var upgradeSection: some View {
        Section("Улучшение") {
            if state.level(.pickaxe) >= Upgrade.pickaxe.maxLevel {
                Text("Кирка максимального уровня")
                    .foregroundColor(.secondary)
            } else {
                Button(
                    "Улучшить кирку — "
                    + "\(state.cost(of: .pickaxe)) монет"
                ) {
                    state.buy(.pickaxe)
                }
                .buttonStyle(.bordered)
                .disabled(
                    state.coins < state.cost(of: .pickaxe)
                )
            }
        }
    }
}
