import SpriteKit
import UIKit

final class Plot {
    let node = SKNode()
    let plant = SKNode()
    let field: Int
    var crop: Crop?
    var plantedAt: TimeInterval = 0
    var ripe = false
    init(field: Int) { self.field = field }
}

final class AnimalRef {
    let type: AnimalType
    let node: SKNode
    var timer: Double
    var product: SKNode?
    init(type: AnimalType, node: SKNode, timer: Double) {
        self.type = type
        self.node = node
        self.timer = timer
    }
}

final class WorkerRef {
    let node: SKNode
    var busy = false
    init(node: SKNode) { self.node = node }
}

final class GameScene: SKScene {
    let state = GameState.shared
    let worldSize = CGSize(width: 3800, height: 2600)
    let ink = UIColor(red: 0.35, green: 0.24, blue: 0.11, alpha: 1)

    let cam = SKCameraNode()
    var velocity = CGVector.zero
    var isPanning = false
    var startScale: CGFloat = 1

    var animals: [AnimalRef] = []
    var plots: [Plot] = []
    var workers: [WorkerRef] = []
    var stockkeepers: [WorkerRef] = []
    var reservedAnimals = Set<ObjectIdentifier>()
    var reserved = Set<ObjectIdentifier>()
    var lockNodes: [String: SKNode] = [:]
    var lastCrop: Crop = .wheat
    var mineLabel: SKLabelNode?

    var gameTime: TimeInterval = 0
    var lastUpdate: TimeInterval = 0
    var lockCheckTimer: Double = 0

    let housePos = CGPoint(x: 1500, y: 1500)
    let barnPos = CGPoint(x: 2000, y: 1500)
    let bakeryPos = CGPoint(x: 1150, y: 1500)
    let dairyPos = CGPoint(x: 3000, y: 1500)
    var dairyMapNode: SKNode?
    var dairyRenderedLevel = -1
    let minePos = CGPoint(x: 560, y: 1800)
    let marketPos = CGPoint(x: 1850, y: 1800)
    let pondPos = CGPoint(x: 600, y: 1250)
    let pens: [AnimalType: CGRect] = [
        .chicken: CGRect(x: 1600, y: 900, width: 420, height: 260),
        .sheep: CGRect(x: 2150, y: 880, width: 460, height: 300),
        .cow: CGRect(x: 2150, y: 440, width: 500, height: 320)
    ]
    let fieldRects: [CGRect] = [
        CGRect(x: 1000, y: 900, width: 420, height: 280),
        CGRect(x: 1000, y: 650, width: 420, height: 200),
        CGRect(x: 1500, y: 650, width: 300, height: 200)
    ]

    func penRect(_ t: AnimalType) -> CGRect { pens[t] ?? .zero }

    // MARK: - Setup
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.55, green: 0.75, blue: 0.39, alpha: 1)
        addChild(cam)
        camera = cam
        cam.position = CGPoint(x: 1700, y: 1100)
        cam.setScale(1.3)

        buildGround()
        buildFields()
        for t in AnimalType.allCases { buildPen(t) }
        buildPond()
        buildGrass()
        buildTrees()
        buildHouse()
        buildBarn()
        buildBakery()
        buildMine()
        buildMarket()
        buildDairyDistrict()
        syncAnimals()
        syncWorkers()
        startSmoke()

        state.onMineFinished = { [weak self] y in
            guard let self = self else { return }
            self.floatText("+\(y) 🪨", at: CGPoint(x: self.minePos.x, y: self.minePos.y + 60))
        }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(tap)
    }

    // MARK: - Gestures

    @objc func handlePan(_ g: UIPanGestureRecognizer) {
        guard let v = view else { return }

        switch g.state {
        case .began:
            isPanning = true
            velocity = .zero

        case .changed:
            let t = g.translation(in: v)
            g.setTranslation(.zero, in: v)

            let dx = -t.x * cam.xScale
            let dy = t.y * cam.xScale

            cam.position.x += dx
            cam.position.y += dy

            velocity = CGVector(dx: dx, dy: dy)
            clampCamera()

        default:
            isPanning = false
        }
    }

    @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
        if g.state == .began {
            startScale = cam.xScale
        }

        let newScale = min(
            2.6,
            max(0.45, startScale / g.scale)
        )

        cam.setScale(newScale)
        clampCamera()
    }

    @objc func handleTap(_ g: UITapGestureRecognizer) {
        guard let v = view else { return }

        let p = convertPoint(fromView: g.location(in: v))
        if dairyTapArea.contains(p) {
            state.dairyOpen = true
            return
        }
        let marketArea = CGRect(
            x: marketPos.x - 140,
            y: marketPos.y - 130,
            width: 280,
            height: 250
        )

        if marketArea.contains(p) {
            state.marketOpen = true
            return
        }

        // Подбор продуктов, лежащих на земле.
        for a in animals {
            if let product = a.product {
                let distance = hypot(
                    product.position.x - p.x,
                    product.position.y - p.y
                )

                if distance < 40 {
                    collectProduct(a: a)
                    return
                }
            }
        }

        // Стрижка овец, дойка коров или реакция курицы.
        for a in animals {
            let distance = hypot(
                a.node.position.x - p.x,
                a.node.position.y - p.y
            )

            if distance < 50 {
                if !tryCare(a) {
                    speak(a)
                }
                return
            }
        }

        // Открытие окна шахты.
        let mineArea = CGRect(
            x: minePos.x - 170,
            y: minePos.y - 100,
            width: 340,
            height: 260
        )

        if mineArea.contains(p) {
            state.mineOpen = true
            return
        }

        // Открытие окна пекарни.
        let bakeryArea = CGRect(
            x: bakeryPos.x - 110,
            y: bakeryPos.y - 80,
            width: 220,
            height: 220
        )

        if bakeryArea.contains(p) {
            state.bakeryOpen = true
            return
        }

        // Посадка, сбор урожая или покупка поля.
        for plot in plots {
            let q = plot.node.position

            if abs(q.x - p.x) < 30 && abs(q.y - p.y) < 30 {
                tapPlot(plot)
                return
            }
        }

        // Покупка закрытого загона.
        for type in AnimalType.allCases {
            let lockKey = "pen_" + type.rawValue

            if lockNodes[lockKey] != nil &&
                penRect(type).contains(p) {

                if state.unlockPen(type) {
                    floatText("Загон открыт!", at: p)
                } else {
                    floatText(
                        "Нужно \(type.penCost) 🪙",
                        at: p
                    )
                }

                return
            }
        }
    }

    func clampCamera() {
        let halfW = size.width * cam.xScale / 2
        let halfH = size.height * cam.yScale / 2

        if halfW * 2 >= worldSize.width {
            cam.position.x = worldSize.width / 2
        } else {
            cam.position.x = min(
                max(cam.position.x, halfW),
                worldSize.width - halfW
            )
        }

        if halfH * 2 >= worldSize.height {
            cam.position.y = worldSize.height / 2
        } else {
            cam.position.y = min(
                max(cam.position.y, halfH),
                worldSize.height - halfH
            )
        }
    }
    // MARK: - Game loop
    override func update(_ currentTime: TimeInterval) {
        let rawDt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 0.1)
        lastUpdate = currentTime
        let dt = rawDt * state.gameSpeed
        gameTime += dt

        if !isPanning && (abs(velocity.dx) > 0.05 || abs(velocity.dy) > 0.05) {
            cam.position.x += velocity.dx
            cam.position.y += velocity.dy
            velocity.dx *= 0.93
            velocity.dy *= 0.93
            clampCamera()
        }
        for a in animals { a.node.zPosition = -a.node.position.y / 10 }
        for w in workers { w.node.zPosition = -w.node.position.y / 10 }

        if state.growAllRequested {
            state.growAllRequested = false
            for p in plots where p.crop != nil && !p.ripe { p.plantedAt = -1_000_000 }
        }

        updateCrops()
        updateAnimals(dt)
        updateWorkers()
        updateStockkeepers()
        state.tick(dt)
        syncDairyBuilding()
        updateMarketCustomer()

        lockCheckTimer += rawDt
        if lockCheckTimer > 0.4 {
            lockCheckTimer = 0
            syncAnimals()
            syncWorkers()
            updateMineLabel()
            for key in Array(lockNodes.keys) where isOpen(key) {
                lockNodes[key]?.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
                lockNodes[key] = nil
            }
        }
    }

    func updateMineLabel() {
        guard let label = mineLabel else { return }
        switch state.minePhase {
        case .idle: label.text = "⛏ Шахта готова"
        case .mining: label.text = "⛏ Копаем \(mmss(state.mineSeconds))"
        case .resting: label.text = "💤 Отдых \(mmss(state.mineSeconds))"
        }
    }

    func isOpen(_ key: String) -> Bool {
        if key.hasPrefix("field") {
            return state.unlocked.contains(Int(key.dropFirst(5)) ?? 0)
        }
        if key.hasPrefix("pen_"), let t = AnimalType(rawValue: String(key.dropFirst(4))) {
            return state.penUnlocked.contains(t)
        }
        return true
    }

    func updateCrops() {
        for p in plots {
            guard let crop = p.crop, !p.ripe else { continue }
            let duration = crop.growTime * state.growMultiplier
            let progress = (gameTime - p.plantedAt) / duration
            if progress >= 1 {
                p.ripe = true
                p.plant.setScale(1)
                p.plant.run(.repeatForever(.sequence([
                    .scale(to: 1.15, duration: 0.5),
                    .scale(to: 1.0, duration: 0.5)
                ])), withKey: "ripe")
            } else {
                p.plant.setScale(0.3 + 0.7 * CGFloat(progress))
            }
        }
    }

   

    // MARK: - Workers
    func syncWorkers() {
        let want = state.workerCount
        while workers.count < want {
            let node = makeWorkerNode()
            node.position = CGPoint(x: housePos.x - 150 + CGFloat(workers.count) * 36, y: housePos.y - 130)
            addChild(node)
            workers.append(WorkerRef(node: node))
        }
    }

    func updateWorkers() {
        for w in workers where !w.busy {
            guard let p = plots.first(where: {
                $0.ripe && state.unlocked.contains($0.field) && !reserved.contains(ObjectIdentifier($0))
            }) else { break }
            assign(w, to: p)
        }
    }

    func assign(_ w: WorkerRef, to p: Plot) {
        w.busy = true
        reserved.insert(ObjectIdentifier(p))
        let target = CGPoint(x: p.node.position.x + 20, y: p.node.position.y - 26)
        let dx = target.x - w.node.position.x
        let dist = hypot(dx, target.y - w.node.position.y)
        let flip = w.node.childNode(withName: "flip")
        if abs(dx) > 2 { flip?.xScale = dx > 0 ? 1 : -1 }
        let bob = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 4, duration: 0.1),
            .moveBy(x: 0, y: -4, duration: 0.1)
        ]))
        flip?.run(bob, withKey: "bob")
        let work = SKAction.sequence([
            .rotate(toAngle: 0.25, duration: 0.15),
            .rotate(toAngle: -0.25, duration: 0.15),
            .rotate(toAngle: 0, duration: 0.15)
        ])
        w.node.run(.sequence([
            .move(to: target, duration: max(0.2, Double(dist) / 120)),
            .run { flip?.removeAction(forKey: "bob"); flip?.position = .zero },
            .run { flip?.run(work) },
            .wait(forDuration: 0.5),
            .run { [weak self] in
                guard let self = self else { return }
                self.finishWork(w: w, p: p)
            }
        ]),
                   withKey: "work")
    }

    func finishWork(w: WorkerRef, p: Plot) {
        reserved.remove(ObjectIdentifier(p))

        if p.ripe, let crop = p.crop {
            harvest(p: p)

            if state.gardenerAutoPlant,
               state.payForGardenerPlanting(crop) {
                plant(p, crop)
            }
        }

        w.busy = false
    }

    func makeWorkerNode() -> SKNode {
        let root = SKNode()
        let flip = SKNode()
        flip.name = "flip"
        root.addChild(flip)
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 26, height: 8))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.12)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -16)
        root.addChild(shadow)
        flip.addChild(legs([-4, 4], top: -8, bottom: -15, color: ink, width: 3.5))
        flip.addChild(rect(18, 22, UIColor(red: 0.25, green: 0.45, blue: 0.75, alpha: 1), r: 5))
        let head = circle(8, UIColor(red: 0.96, green: 0.80, blue: 0.65, alpha: 1))
        head.position = CGPoint(x: 0, y: 19)
        flip.addChild(head)
        let brim = ellipse(30, 9, UIColor(red: 0.92, green: 0.80, blue: 0.40, alpha: 1), line: 2)
        brim.position = CGPoint(x: 0, y: 25)
        flip.addChild(brim)
        let dome = ellipse(16, 10, UIColor(red: 0.92, green: 0.80, blue: 0.40, alpha: 1), line: 2)
        dome.position = CGPoint(x: 0, y: 29)
        flip.addChild(dome)
        return root
    }

    // MARK: - Tycoon actions
    func tapPlot(_ p: Plot) {
        if !state.unlocked.contains(p.field) {
            let cost = GameState.fieldCosts[p.field]
            if state.unlockField(p.field) {
                floatText("Поле открыто!", at: p.node.position)
            } else {
                floatText("Нужно \(cost) 🪙", at: p.node.position)
            }
            return
        }
        if p.ripe {
            harvest(p: p)
        } else if p.crop == nil {
            let c = state.selected
            if state.spend(c.seedCost) {
                plant(p, c)
            } else {
                floatText("Не хватает 🪙", at: p.node.position)
            }
        }
    }

    func plant(_ p: Plot, _ crop: Crop) {
        p.crop = crop
        lastCrop = crop
        p.plantedAt = gameTime
        p.ripe = false
        p.plant.removeAllActions()
        p.plant.removeAllChildren()
        p.plant.addChild(makePlantVisual(crop))
        p.plant.setScale(0.3)
    }

    func harvest(p: Plot) {
        guard let crop = p.crop else { return }

        state.add(crop.item)
        QuestState.shared.recordHarvest(crop.item)
        floatText("1 \(crop.emoji)", at: p.node.position)

        p.crop = nil
        p.ripe = false
        p.plant.removeAllActions()
        p.plant.removeAllChildren()
    }

    func spawnProduct(_ a: AnimalRef) {
        let node = makeProductNode(a.type.product)
        node.position = CGPoint(x: a.node.position.x, y: a.node.position.y - 12)
        node.zPosition = -node.position.y / 10 + 1
        node.setScale(0.1)
        addChild(node)
        node.run(.scale(to: 1, duration: 0.25))
        a.product = node
        node.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 4, duration: 0.5),
            .moveBy(x: 0, y: -4, duration: 0.5)
        ])), withKey: "pulse")
    }

    func collectProduct(a: AnimalRef) {
        guard let prod = a.product else { return }

        state.add(a.type.product)
        QuestState.shared.recordHarvest(a.type.product)
        floatText("1 \(a.type.product.emoji)", at: prod.position)

        prod.removeFromParent()
        a.product = nil
        a.timer = 0
    }

    func speak(_ a: AnimalRef) {
        floatText(a.type.sound, at: a.node.position)
        if let flip = a.node.childNode(withName: "flip") {
            flip.run(.sequence([.moveBy(x: 0, y: 16, duration: 0.12), .moveBy(x: 0, y: -16, duration: 0.12)]))
        }
    }

    func syncAnimals() {
        for t in AnimalType.allCases {
            let want = state.penUnlocked.contains(t) ? state.animalCount(t) : 0
            let current = animals.filter { $0.type == t }.count
            if current < want {
                for _ in current..<want { addAnimal(t) }
            } else if current > want {
                for _ in want..<current { removeAnimal(t) }
            }
        }
    }

    func addAnimal(_ t: AnimalType) {
        let r = penRect(t)
        let node = makeAnimalNode(t)
        node.position = CGPoint(x: .random(in: r.minX + 50...r.maxX - 50),
                                y: .random(in: r.minY + 50...r.maxY - 50))
        addChild(node)
        let ref = AnimalRef(type: t, node: node,
                            timer: t == .chicken ? Double.random(in: 0...state.productInterval(t) * 0.6)
                                                 : state.productInterval(t))
        animals.append(ref)
        wander(ref)
    }

    func removeAnimal(_ t: AnimalType) {
        guard let idx = animals.lastIndex(where: { $0.type == t }) else { return }
        let a = animals.remove(at: idx)
        floatText("💨", at: a.node.position)
        a.product?.removeFromParent()
        a.node.removeFromParent()
    }

    func floatText(_ s: String, at p: CGPoint) {
        let l = SKLabelNode(text: s)
        l.fontName = "AvenirNext-Heavy"
        l.fontSize = 24
        l.fontColor = .white
        l.position = CGPoint(x: p.x, y: p.y + 30)
        l.zPosition = 700
        addChild(l)
        l.run(.sequence([
            .group([.moveBy(x: 0, y: 50, duration: 0.9), .fadeOut(withDuration: 0.9)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Helpers
    func shape(_ node: SKShapeNode, fill: UIColor, line: CGFloat = 3) -> SKShapeNode {
        node.fillColor = fill
        node.strokeColor = ink
        node.lineWidth = line
        return node
    }

    func rect(_ w: CGFloat, _ h: CGFloat, _ fill: UIColor, r: CGFloat = 5) -> SKShapeNode {
        shape(SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: r), fill: fill)
    }

    func circle(_ r: CGFloat, _ fill: UIColor) -> SKShapeNode {
        shape(SKShapeNode(circleOfRadius: r), fill: fill)
    }

    func ellipse(_ w: CGFloat, _ h: CGFloat, _ fill: UIColor, line: CGFloat = 2.5) -> SKShapeNode {
        shape(SKShapeNode(ellipseOf: CGSize(width: w, height: h)), fill: fill, line: line)
    }

    func sway(_ n: SKNode, angle: CGFloat, duration: TimeInterval) {
        let a = SKAction.rotate(toAngle: angle, duration: duration)
        let b = SKAction.rotate(toAngle: -angle, duration: duration)
        a.timingMode = .easeInEaseOut
        b.timingMode = .easeInEaseOut
        n.run(.sequence([
            .wait(forDuration: .random(in: 0...duration)),
            .repeatForever(.sequence([a, b]))
        ]))
    }

    func inAnyZone(_ p: CGPoint) -> Bool {
        // Не размещаем декорации на площадке сыроварни.
        if dairyReservedArea.contains(p) {
            return true
        }

        for t in AnimalType.allCases
        where penRect(t).insetBy(dx: -60, dy: -60).contains(p) {
            return true
        }

        if hypot(
            p.x - pondPos.x,
            (p.y - pondPos.y) * 1.5
        ) < 230 {
            return true
        }

        if CGRect(
            x: 1000,
            y: 1380,
            width: 1100,
            height: 300
        ).contains(p) {
            return true
        }

        if CGRect(
            x: minePos.x - 240,
            y: minePos.y - 140,
            width: 480,
            height: 360
        ).contains(p) {
            return true
        }

        return fieldRects.contains {
            $0.insetBy(dx: -30, dy: -30).contains(p)
        }
    }

    func addLock(key: String, rect r: CGRect, cost: Int) {
        let lock = SKNode()
        lock.position = CGPoint(x: r.midX, y: r.midY)
        lock.zPosition = -940
        let dark = SKShapeNode(rectOf: r.size, cornerRadius: 12)
        dark.fillColor = UIColor.black.withAlphaComponent(0.55)
        dark.strokeColor = .clear
        lock.addChild(dark)
        let label = SKLabelNode(text: "🔒 \(cost) 🪙")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 36
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        lock.addChild(label)
        addChild(lock)
        lockNodes[key] = lock
    }

    func makePlantVisual(_ crop: Crop) -> SKNode {
        let n = SKNode()
        let stemPath = UIBezierPath()
        stemPath.move(to: .zero)
        stemPath.addQuadCurve(to: CGPoint(x: 0, y: 18), controlPoint: CGPoint(x: 3, y: 9))
        let stem = SKShapeNode(path: stemPath.cgPath)
        stem.strokeColor = ink
        stem.lineWidth = 2
        n.addChild(stem)

        switch crop {
        case .wheat:
            let head = ellipse(12, 24, UIColor(red: 0.93, green: 0.78, blue: 0.29, alpha: 1), line: 2)
            head.position = CGPoint(x: 0, y: 28)
            n.addChild(head)
        case .carrot:
            let tri = UIBezierPath()
            tri.move(to: CGPoint(x: -9, y: 30))
            tri.addLine(to: CGPoint(x: 9, y: 30))
            tri.addLine(to: CGPoint(x: 0, y: 6))
            tri.close()
            let body = shape(SKShapeNode(path: tri.cgPath),
                             fill: UIColor(red: 0.95, green: 0.50, blue: 0.15, alpha: 1), line: 2)
            n.addChild(body)
            let leaves = UIBezierPath()
            leaves.move(to: CGPoint(x: 0, y: 30)); leaves.addLine(to: CGPoint(x: -6, y: 42))
            leaves.move(to: CGPoint(x: 0, y: 30)); leaves.addLine(to: CGPoint(x: 6, y: 42))
            let l = SKShapeNode(path: leaves.cgPath)
            l.strokeColor = UIColor(red: 0.30, green: 0.65, blue: 0.25, alpha: 1)
            l.lineWidth = 3
            n.addChild(l)
        case .cabbage:
            let head = shape(SKShapeNode(circleOfRadius: 13),
                             fill: UIColor(red: 0.55, green: 0.80, blue: 0.40, alpha: 1), line: 2)
            head.position = CGPoint(x: 0, y: 20)
            n.addChild(head)
            let inner = SKShapeNode(circleOfRadius: 6)
            inner.fillColor = UIColor(red: 0.75, green: 0.92, blue: 0.60, alpha: 1)
            inner.strokeColor = .clear
            inner.position = CGPoint(x: 0, y: 20)
            n.addChild(inner)
        }
        return n
    }

    func makeProductNode(_ item: Item) -> SKNode {
        let n = SKNode()
        switch item {
        case .wool:
            n.addChild(circle(13, UIColor(white: 0.97, alpha: 1)))
            let b = circle(8, UIColor(white: 0.97, alpha: 1))
            b.position = CGPoint(x: 12, y: 6)
            n.addChild(b)
            let c = circle(8, UIColor(white: 0.97, alpha: 1))
            c.position = CGPoint(x: -12, y: 5)
            n.addChild(c)
        case .milk:
            n.addChild(rect(16, 24, UIColor(white: 0.98, alpha: 1), r: 4))
            let cap = rect(10, 6, UIColor(red: 0.35, green: 0.60, blue: 0.90, alpha: 1), r: 2)
            cap.position = CGPoint(x: 0, y: 14)
            n.addChild(cap)
        default:
            n.addChild(ellipse(16, 20, UIColor(red: 1, green: 0.96, blue: 0.85, alpha: 1), line: 2))
        }
        return n
    }

    // MARK: - World
    func buildGround() {
        let ground = SKSpriteNode(color: UIColor(red: 0.55, green: 0.75, blue: 0.39, alpha: 1), size: worldSize)
        ground.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        ground.zPosition = -1000
        addChild(ground)

        for _ in 0..<60 {
            let r = CGFloat.random(in: 80...240)
            let p = SKShapeNode(circleOfRadius: r)
            p.position = CGPoint(x: .random(in: 0...worldSize.width), y: .random(in: 0...worldSize.height))
            p.fillColor = Bool.random()
                ? UIColor(red: 0.59, green: 0.79, blue: 0.42, alpha: 1)
                : UIColor(red: 0.52, green: 0.72, blue: 0.35, alpha: 1)
            p.strokeColor = .clear
            p.zPosition = -990
            addChild(p)
        }

        let road = UIBezierPath()
        road.move(to: CGPoint(x: 2100, y: 1250))
        road.addLine(to: CGPoint(x: 1150, y: 1250))
        road.move(to: CGPoint(x: 1800, y: 1250))
        road.addLine(to: CGPoint(x: 1800, y: 1400))
        road.move(to: CGPoint(x: 1150, y: 1250))
        road.addLine(to: CGPoint(x: 1150, y: 1400))
        road.move(to: CGPoint(x: 2100, y: 1250))
        road.addLine(to: CGPoint(x: 2100, y: 600))
        road.move(to: CGPoint(x: 1150, y: 1650))
        road.addCurve(to: CGPoint(x: 700, y: 1740), controlPoint1: CGPoint(x: 1000, y: 1700), controlPoint2: CGPoint(x: 850, y: 1750))
        for (w, c) in [(36 as CGFloat, UIColor(red: 0.85, green: 0.77, blue: 0.54, alpha: 1)),
                       (28 as CGFloat, UIColor(red: 0.91, green: 0.85, blue: 0.66, alpha: 1))] {
            let s = SKShapeNode(path: road.cgPath)
            s.strokeColor = c
            s.lineWidth = w
            s.lineCap = .round
            s.zPosition = w > 30 ? -970 : -969
            addChild(s)
        }
    }

    func buildFields() {
        let soilColor = UIColor(red: 0.60, green: 0.42, blue: 0.24, alpha: 1)
        let cell: CGFloat = 60
        for (idx, r) in fieldRects.enumerated() {
            let f = rect(r.width, r.height, soilColor, r: 12)
            f.position = CGPoint(x: r.midX, y: r.midY)
            f.zPosition = -960
            addChild(f)

            let cols = Int(r.width / cell)
            let rows = Int(r.height / cell)
            let ox = r.minX + (r.width - CGFloat(cols) * cell) / 2
            let oy = r.minY + (r.height - CGFloat(rows) * cell) / 2
            for row in stride(from: rows - 1, through: 0, by: -1) {
                for col in 0..<cols {
                    let plot = Plot(field: idx)
                    plot.node.position = CGPoint(x: ox + (CGFloat(col) + 0.5) * cell,
                                                 y: oy + (CGFloat(row) + 0.5) * cell)
                    plot.node.zPosition = -955
                    let soil = rect(50, 50, UIColor(red: 0.50, green: 0.34, blue: 0.19, alpha: 1), r: 8)
                    soil.lineWidth = 2
                    plot.node.addChild(soil)
                    plot.plant.position = CGPoint(x: 0, y: -8)
                    plot.node.addChild(plot.plant)
                    addChild(plot.node)
                    plots.append(plot)
                }
            }
            if !state.unlocked.contains(idx) {
                addLock(key: "field\(idx)", rect: r, cost: GameState.fieldCosts[idx])
            }
        }
    }

    func buildPen(_ t: AnimalType) {
        let pen = penRect(t)
        let floor = SKShapeNode(rect: pen)
        floor.fillColor = t == .cow
            ? UIColor(red: 0.66, green: 0.82, blue: 0.48, alpha: 1)
            : UIColor(red: 0.72, green: 0.85, blue: 0.53, alpha: 1)
        floor.strokeColor = .clear
        floor.zPosition = -950
        addChild(floor)

        func fence(y: CGFloat, z: CGFloat) {
            let n = SKNode()
            n.zPosition = z
            let rail = SKShapeNode(rect: CGRect(x: pen.minX, y: y + 4, width: pen.width, height: 4))
            rail.fillColor = UIColor(red: 0.54, green: 0.35, blue: 0.17, alpha: 1)
            rail.strokeColor = ink
            rail.lineWidth = 2
            n.addChild(rail)
            var x = pen.minX
            while x <= pen.maxX {
                let post = SKShapeNode(rect: CGRect(x: x - 3, y: y - 10, width: 6, height: 28))
                post.fillColor = UIColor(red: 0.62, green: 0.42, blue: 0.21, alpha: 1)
                post.strokeColor = ink
                post.lineWidth = 2
                n.addChild(post)
                x += 28
            }
            addChild(n)
        }
        fence(y: pen.maxY, z: -pen.maxY / 10)
        fence(y: pen.minY, z: -pen.minY / 10 + 5)

        for side in [pen.minX, pen.maxX] {
            let s = SKShapeNode(rect: CGRect(x: side - 2, y: pen.minY, width: 4, height: pen.height))
            s.fillColor = UIColor(red: 0.54, green: 0.35, blue: 0.17, alpha: 1)
            s.strokeColor = ink
            s.lineWidth = 2
            s.zPosition = -pen.midY / 10
            addChild(s)
        }

        if !state.penUnlocked.contains(t) {
            addLock(key: "pen_" + t.rawValue, rect: pen, cost: t.penCost)
        }
    }

    func buildPond() {
        let sand = SKShapeNode(ellipseOf: CGSize(width: 360, height: 240))
        sand.position = pondPos
        sand.fillColor = UIColor(red: 0.85, green: 0.77, blue: 0.54, alpha: 1)
        sand.strokeColor = .clear
        sand.zPosition = -980
        addChild(sand)

        let water = ellipse(340, 220, UIColor(red: 0.37, green: 0.70, blue: 0.86, alpha: 1), line: 3)
        water.position = pondPos
        water.zPosition = -979
        addChild(water)

        for i in 0..<3 {
            let ring = SKShapeNode(ellipseOf: CGSize(width: 40, height: 20))
            ring.strokeColor = UIColor.white.withAlphaComponent(0.7)
            ring.lineWidth = 2
            ring.fillColor = .clear
            ring.position = CGPoint(x: pondPos.x + CGFloat(i - 1) * 80, y: pondPos.y + CGFloat(i % 2) * 30 - 15)
            ring.zPosition = -978
            addChild(ring)
            ring.run(.sequence([
                .wait(forDuration: Double(i) * 0.8),
                .repeatForever(.group([
                    .sequence([.scale(to: 1.6, duration: 1.8), .scale(to: 0.6, duration: 0)]),
                    .sequence([.fadeAlpha(to: 0, duration: 1.8), .fadeAlpha(to: 0.9, duration: 0)])
                ]))
            ]))
        }
    }

    func buildGrass() {
        let colors = [UIColor(red: 0.31, green: 0.60, blue: 0.23, alpha: 1),
                      UIColor(red: 0.42, green: 0.69, blue: 0.29, alpha: 1)]
        var count = 0
        while count < 600 {
            let p = CGPoint(x: .random(in: 0...worldSize.width), y: .random(in: 0...worldSize.height))
            if inAnyZone(p) { continue }
            let path = UIBezierPath()
            for k in -1...1 {
                let kx = CGFloat(k)
                path.move(to: CGPoint(x: kx * 4, y: 0))
                path.addQuadCurve(to: CGPoint(x: kx * 7, y: 17), controlPoint: CGPoint(x: kx * 5, y: 9))
            }
            let t = SKShapeNode(path: path.cgPath)
            t.strokeColor = colors.randomElement()!
            t.lineWidth = 2.5
            t.lineCap = .round
            t.position = p
            t.zPosition = -p.y / 10
            t.setScale(.random(in: 0.8...1.5))
            addChild(t)
            sway(t, angle: 0.22, duration: Double.random(in: 0.9...1.5))
            count += 1
        }
    }

    func buildTrees() {
        var count = 0
        let keepOut = CGRect(x: 850, y: 400, width: 1900, height: 1350)
        while count < 60 {
            let p = CGPoint(x: .random(in: 0...worldSize.width), y: .random(in: 80...worldSize.height))
            if inAnyZone(p) || keepOut.contains(p) { continue }
            let tree = SKNode()
            tree.position = p
            tree.zPosition = -p.y / 10
            tree.setScale(.random(in: 0.8...1.5))
            let shadow = SKShapeNode(ellipseOf: CGSize(width: 70, height: 22))
            shadow.fillColor = UIColor.black.withAlphaComponent(0.1)
            shadow.strokeColor = .clear
            tree.addChild(shadow)
            let trunk = rect(16, 44, UIColor(red: 0.54, green: 0.35, blue: 0.17, alpha: 1), r: 4)
            trunk.position = CGPoint(x: 0, y: 22)
            tree.addChild(trunk)
            let crown = circle(42, UIColor(red: 0.25, green: 0.56, blue: 0.23, alpha: 1))
            crown.position = CGPoint(x: 0, y: 80)
            tree.addChild(crown)
            let light = SKShapeNode(circleOfRadius: 20)
            light.fillColor = UIColor(red: 0.35, green: 0.68, blue: 0.29, alpha: 1)
            light.strokeColor = .clear
            light.position = CGPoint(x: -12, y: 90)
            tree.addChild(light)
            addChild(tree)
            sway(tree, angle: 0.03, duration: 1.8)
            count += 1
        }
    }

    func buildHouse() {
        let h = SKNode()
        h.position = housePos
        h.zPosition = -(housePos.y - 75) / 10
        let chimney = rect(28, 50, UIColor(red: 0.6, green: 0.54, blue: 0.48, alpha: 1), r: 3)
        chimney.position = CGPoint(x: 55, y: 120)
        h.addChild(chimney)
        let body = rect(220, 150, UIColor(red: 0.95, green: 0.87, blue: 0.69, alpha: 1), r: 6)
        h.addChild(body)
        let door = rect(50, 60, UIColor(red: 0.66, green: 0.41, blue: 0.23, alpha: 1), r: 4)
        door.position = CGPoint(x: -50, y: -45)
        h.addChild(door)
        let window = rect(55, 45, UIColor(red: 0.62, green: 0.84, blue: 0.93, alpha: 1), r: 4)
        window.position = CGPoint(x: 40, y: -5)
        h.addChild(window)
        let roofPath = UIBezierPath()
        roofPath.move(to: CGPoint(x: -130, y: 72))
        roofPath.addLine(to: CGPoint(x: 0, y: 155))
        roofPath.addLine(to: CGPoint(x: 130, y: 72))
        roofPath.close()
        let roof = shape(SKShapeNode(path: roofPath.cgPath), fill: UIColor(red: 0.77, green: 0.29, blue: 0.18, alpha: 1))
        roof.zPosition = 1
        h.addChild(roof)
        addChild(h)
    }

    func buildBarn() {
        let b = SKNode()
        b.position = barnPos
        b.zPosition = -(barnPos.y - 75) / 10
        let body = rect(200, 150, UIColor(red: 0.72, green: 0.27, blue: 0.18, alpha: 1), r: 6)
        b.addChild(body)
        let door = rect(80, 100, UIColor(red: 0.96, green: 0.91, blue: 0.82, alpha: 1), r: 4)
        door.position = CGPoint(x: 0, y: -25)
        b.addChild(door)
        let x = UIBezierPath()
        x.move(to: CGPoint(x: -40, y: 25)); x.addLine(to: CGPoint(x: 40, y: -75))
        x.move(to: CGPoint(x: 40, y: 25)); x.addLine(to: CGPoint(x: -40, y: -75))
        let cross = SKShapeNode(path: x.cgPath)
        cross.strokeColor = ink
        cross.lineWidth = 3
        cross.zPosition = 1
        b.addChild(cross)
        let roofPath = UIBezierPath()
        roofPath.move(to: CGPoint(x: -114, y: 72))
        roofPath.addLine(to: CGPoint(x: 0, y: 150))
        roofPath.addLine(to: CGPoint(x: 114, y: 72))
        roofPath.close()
        let roof = shape(SKShapeNode(path: roofPath.cgPath), fill: UIColor(red: 0.49, green: 0.23, blue: 0.16, alpha: 1))
        roof.zPosition = 1
        b.addChild(roof)
        addChild(b)
    }

    func buildBakery() {
        let b = SKNode()
        b.position = bakeryPos
        b.zPosition = -(bakeryPos.y - 65) / 10
        let chimney = rect(24, 44, UIColor(red: 0.6, green: 0.54, blue: 0.48, alpha: 1), r: 3)
        chimney.position = CGPoint(x: -50, y: 105)
        b.addChild(chimney)
        let body = rect(190, 130, UIColor(red: 0.93, green: 0.78, blue: 0.55, alpha: 1), r: 6)
        b.addChild(body)
        let door = rect(44, 56, UIColor(red: 0.55, green: 0.33, blue: 0.2, alpha: 1), r: 4)
        door.position = CGPoint(x: 45, y: -35)
        b.addChild(door)
        let sign = SKLabelNode(text: "🍞 🥧")
        sign.fontSize = 32
        sign.verticalAlignmentMode = .center
        sign.position = CGPoint(x: -25, y: -5)
        sign.zPosition = 2
        b.addChild(sign)
        let roofPath = UIBezierPath()
        roofPath.move(to: CGPoint(x: -112, y: 62))
        roofPath.addLine(to: CGPoint(x: 0, y: 135))
        roofPath.addLine(to: CGPoint(x: 112, y: 62))
        roofPath.close()
        let roof = shape(SKShapeNode(path: roofPath.cgPath), fill: UIColor(red: 0.55, green: 0.33, blue: 0.2, alpha: 1))
        roof.zPosition = 1
        b.addChild(roof)
        addChild(b)

        let spawn = SKAction.run { [weak self] in
            guard let self = self, self.state.bakeQueue > 0 else { return }
            let puff = SKShapeNode(circleOfRadius: 7)
            puff.fillColor = UIColor(white: 0.95, alpha: 0.9)
            puff.strokeColor = .clear
            puff.position = CGPoint(x: self.bakeryPos.x - 50, y: self.bakeryPos.y + 135)
            puff.zPosition = 500
            self.addChild(puff)
            puff.run(.sequence([
                .group([.moveBy(x: 30, y: 100, duration: 3), .scale(to: 3, duration: 3), .fadeOut(withDuration: 3)]),
                .removeFromParent()
            ]))
        }
        run(.repeatForever(.sequence([spawn, .wait(forDuration: 0.4)])))
    }

    func buildMine() {
        let m = SKNode()
        m.position = minePos
        m.zPosition = -(minePos.y - 60) / 10

        let rock = UIColor(red: 0.62, green: 0.62, blue: 0.66, alpha: 1)
        let rockLight = UIColor(red: 0.74, green: 0.74, blue: 0.78, alpha: 1)
        let base = ellipse(320, 190, rock, line: 3)
        base.position = CGPoint(x: 0, y: 20)
        m.addChild(base)
        let top = ellipse(210, 120, rockLight, line: 3)
        top.position = CGPoint(x: 0, y: 70)
        m.addChild(top)

        let arch = UIBezierPath()
        arch.move(to: CGPoint(x: -42, y: -50))
        arch.addLine(to: CGPoint(x: -42, y: 5))
        arch.addArc(withCenter: CGPoint(x: 0, y: 5), radius: 42, startAngle: .pi, endAngle: 0, clockwise: false)
        arch.addLine(to: CGPoint(x: 42, y: -50))
        arch.close()
        let hole = shape(SKShapeNode(path: arch.cgPath), fill: UIColor(red: 0.12, green: 0.10, blue: 0.10, alpha: 1))
        hole.zPosition = 1
        m.addChild(hole)

        for x in [-50 as CGFloat, 50] {
            let post = rect(10, 80, UIColor(red: 0.54, green: 0.35, blue: 0.17, alpha: 1), r: 2)
            post.position = CGPoint(x: x, y: -10)
            post.zPosition = 2
            m.addChild(post)
        }
        let beam = rect(120, 12, UIColor(red: 0.54, green: 0.35, blue: 0.17, alpha: 1), r: 2)
        beam.position = CGPoint(x: 0, y: 32)
        beam.zPosition = 2
        m.addChild(beam)

        for (x, y, r) in [(-120 as CGFloat, -40 as CGFloat, 14 as CGFloat), (-100, -55, 10), (120, -45, 16)] {
            let s = circle(r, rock)
            s.position = CGPoint(x: x, y: y)
            s.zPosition = 2
            m.addChild(s)
        }
        for (x, y) in [(95 as CGFloat, -52 as CGFloat), (112, -62), (130, -50)] {
            let c = circle(9, UIColor(red: 0.16, green: 0.15, blue: 0.16, alpha: 1))
            c.position = CGPoint(x: x, y: y)
            c.zPosition = 3
            m.addChild(c)
        }

        let sign = SKLabelNode(text: "⛏")
        sign.fontSize = 36
        sign.verticalAlignmentMode = .center
        sign.position = CGPoint(x: 0, y: 95)
        sign.zPosition = 4
        m.addChild(sign)

        let label = SKLabelNode(text: "⛏ Шахта")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 26
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: 140)
        label.zPosition = 5
        m.addChild(label)
        mineLabel = label

        addChild(m)
        updateMineLabel()
    }

    func startSmoke() {
        let spawn = SKAction.run { [weak self] in
            guard let self = self else { return }
            let puff = SKShapeNode(circleOfRadius: 8)
            puff.fillColor = UIColor(white: 0.93, alpha: 0.9)
            puff.strokeColor = .clear
            puff.position = CGPoint(x: self.housePos.x + 55, y: self.housePos.y + 150)
            puff.zPosition = 500
            self.addChild(puff)
            let drift = CGFloat.random(in: 20...60)
            puff.run(.sequence([
                .group([
                    .moveBy(x: drift, y: 120, duration: 3.5),
                    .scale(to: 3.2, duration: 3.5),
                    .fadeOut(withDuration: 3.5)
                ]),
                .removeFromParent()
            ]))
        }
        run(.repeatForever(.sequence([spawn, .wait(forDuration: 0.3)])))
    }

    // MARK: - Animals
    func makeAnimalNode(_ t: AnimalType) -> SKNode {
        let root = SKNode()
        let flip = SKNode()
        flip.name = "flip"
        root.addChild(flip)

        let shadowW: CGFloat = t == .cow ? 60 : (t == .sheep ? 44 : 32)
        let shadow = SKShapeNode(ellipseOf: CGSize(width: shadowW, height: 10))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.12)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: t == .chicken ? -14 : -20)
        root.addChild(shadow)

        switch t {
        case .chicken: drawChicken(flip)
        case .sheep: drawSheep(flip)
        case .cow: drawCow(flip)
        }
        return root
    }

    func legs(_ xs: [CGFloat], top: CGFloat, bottom: CGFloat, color: UIColor, width: CGFloat = 3) -> SKShapeNode {
        let p = UIBezierPath()
        for x in xs {
            p.move(to: CGPoint(x: x, y: top))
            p.addLine(to: CGPoint(x: x, y: bottom))
        }
        let s = SKShapeNode(path: p.cgPath)
        s.strokeColor = color
        s.lineWidth = width
        return s
    }

    func drawChicken(_ flip: SKNode) {
        flip.addChild(legs([-4, 4], top: -8, bottom: -15, color: UIColor(red: 0.91, green: 0.63, blue: 0.19, alpha: 1)))
        flip.addChild(ellipse(30, 24, .white))
        let wing = SKShapeNode(ellipseOf: CGSize(width: 16, height: 12))
        wing.fillColor = UIColor(white: 0.92, alpha: 1)
        wing.strokeColor = .clear
        wing.position = CGPoint(x: -4, y: 0)
        flip.addChild(wing)
        let head = circle(8, .white)
        head.position = CGPoint(x: 12, y: 10)
        flip.addChild(head)
        let comb = SKShapeNode(circleOfRadius: 4)
        comb.fillColor = UIColor(red: 0.88, green: 0.25, blue: 0.19, alpha: 1)
        comb.strokeColor = .clear
        comb.position = CGPoint(x: 12, y: 19)
        flip.addChild(comb)
        let beakPath = UIBezierPath()
        beakPath.move(to: CGPoint(x: 19, y: 11))
        beakPath.addLine(to: CGPoint(x: 26, y: 9))
        beakPath.addLine(to: CGPoint(x: 19, y: 7))
        beakPath.close()
        let beak = SKShapeNode(path: beakPath.cgPath)
        beak.fillColor = UIColor(red: 0.94, green: 0.63, blue: 0.13, alpha: 1)
        beak.strokeColor = .clear
        flip.addChild(beak)
        let eye = SKShapeNode(circleOfRadius: 1.8)
        eye.fillColor = ink
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 14, y: 12)
        flip.addChild(eye)
    }

    func wander(_ a: AnimalRef) {
        guard let flip = a.node.childNode(withName: "flip") else { return }
        if Int.random(in: 0..<10) < 3 {
            a.node.run(.sequence([
                .wait(forDuration: .random(in: 1...3)),
                .run { [weak self] in self?.wander(a) }
            ]), withKey: "wander")
            return
        }
        let r = penRect(a.type)
        let target = CGPoint(x: .random(in: r.minX + 50...r.maxX - 50),
                             y: .random(in: r.minY + 50...r.maxY - 50))
        let dx = target.x - a.node.position.x
        if abs(dx) > 2 { flip.xScale = dx > 0 ? 1 : -1 }
        let dist = hypot(dx, target.y - a.node.position.y)
        let bob = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 4, duration: 0.12),
            .moveBy(x: 0, y: -4, duration: 0.12)
        ]))
        flip.run(bob, withKey: "bob")
        a.node.run(.sequence([
            .move(to: target, duration: Double(dist) / a.type.speed),
            .run { flip.removeAction(forKey: "bob"); flip.position = .zero },
            .wait(forDuration: .random(in: 0.5...2)),
            .run { [weak self] in self?.wander(a) }
        ]), withKey: "wander")
    }
}
