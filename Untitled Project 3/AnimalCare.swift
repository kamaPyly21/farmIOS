import SpriteKit
import UIKit

// MARK: - Подсказки в интерфейсе
extension AnimalType {
    func careInfo(_ state: GameState) -> String {
        let t = Int(state.productInterval(self))
        switch self {
        case .chicken: return "🥚 несётся раз в \(t) с, цена \(product.price) 🪙"
        case .sheep: return "🧶 стрижка: шерсть отрастает за \(mmss(t)), цена \(product.price) 🪙"
        case .cow: return "🥛 дойка: молоко накапливается \(mmss(t)), цена \(product.price) 🪙"
        }
    }
}

// MARK: - Стрижка овец и дойка коров
extension GameScene {
    func updateAnimals(_ dt: Double) {
        for a in animals {
            switch a.type {
            case .chicken:
                guard a.product == nil else { continue }
                a.timer += dt
                if a.timer >= state.productInterval(.chicken) { spawnProduct(a) }
            case .sheep, .cow:
                a.timer = min(a.timer + dt, state.productInterval(a.type))
                updateCareVisual(a)
            }
        }
    }

    func careProgress(_ a: AnimalRef) -> Double {
        min(1, a.timer / max(1, state.productInterval(a.type)))
    }

    func updateCareVisual(_ a: AnimalRef) {
        let p = CGFloat(careProgress(a))
        let flip = a.node.childNode(withName: "flip")
        if a.type == .sheep, let wool = flip?.childNode(withName: "wool") {
            wool.isHidden = p < 0.02
            wool.setScale(0.2 + 0.8 * p)
        } else if a.type == .cow, let udder = flip?.childNode(withName: "udder") {
            udder.setScale(0.4 + 0.6 * p)
        }
        a.node.childNode(withName: "ready")?.isHidden = p < 1
    }

    /// true, если тап обработан как стрижка/дойка/подсказка
    func tryCare(_ a: AnimalRef) -> Bool {
        guard a.type != .chicken else { return false }
        if careProgress(a) >= 1 {
            state.add(a.type.product)
            QuestState.shared.recordHarvest(a.type.product)
            floatText("+1 \(a.type.product.emoji)", at: a.node.position)
            careBurst(a)
            a.timer = 0
            updateCareVisual(a)
        } else {
            let left = Int(state.productInterval(a.type) - a.timer)
            let text = a.type == .sheep ? "Шерсть отрастает: " : "Молоко копится: "
            floatText(text + mmss(left), at: a.node.position)
        }
        return true
    }

    func careBurst(_ a: AnimalRef) {
        for _ in 0..<7 {
            let c = SKShapeNode(circleOfRadius: a.type == .sheep ? 7 : 4)
            c.fillColor = a.type == .sheep ? UIColor(white: 0.97, alpha: 1) : UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 1)
            c.strokeColor = ink
            c.lineWidth = 1.5
            c.position = CGPoint(x: a.node.position.x, y: a.node.position.y + 10)
            c.zPosition = 650
            addChild(c)
            let dy: CGFloat = a.type == .sheep ? .random(in: 20...60) : -.random(in: 10...30)
            c.run(.sequence([
                .group([.moveBy(x: .random(in: -40...40), y: dy, duration: 0.6), .fadeOut(withDuration: 0.6)]),
                .removeFromParent()
            ]))
        }
        a.node.childNode(withName: "flip")?.run(.sequence([
            .rotate(toAngle: 0.15, duration: 0.08),
            .rotate(toAngle: -0.15, duration: 0.08),
            .rotate(toAngle: 0, duration: 0.08)
        ]))
    }

    func addReadyBubble(to root: SKNode?, emoji: String) {
        let bubble = SKLabelNode(text: emoji)
        bubble.name = "ready"
        bubble.fontSize = 28
        bubble.verticalAlignmentMode = .center
        bubble.position = CGPoint(x: 0, y: 58)
        bubble.zPosition = 5
        bubble.isHidden = true
        bubble.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 6, duration: 0.5),
            .moveBy(x: 0, y: -6, duration: 0.5)
        ])))
        root?.addChild(bubble)
    }

    // MARK: Рисование
    func drawSheep(_ flip: SKNode) {
        let dark = UIColor(red: 0.28, green: 0.24, blue: 0.22, alpha: 1)
        flip.addChild(legs([-12, -4, 6, 14], top: -8, bottom: -19, color: dark, width: 3.5))

        let skin = ellipse(34, 20, UIColor(red: 0.93, green: 0.80, blue: 0.78, alpha: 1), line: 2.5)
        flip.addChild(skin)

        let wool = SKNode()
        wool.name = "wool"
        flip.addChild(wool)
        let woolColor = UIColor(white: 0.97, alpha: 1)
        for (x, y, r) in [(-14 as CGFloat, 0 as CGFloat, 14 as CGFloat), (0, 5, 17), (14, 0, 14), (0, -4, 15)] {
            let c = circle(r, woolColor)
            c.position = CGPoint(x: x, y: y)
            wool.addChild(c)
        }

        let head = ellipse(16, 18, dark, line: 2)
        head.position = CGPoint(x: 26, y: 4)
        flip.addChild(head)
        let ear = ellipse(10, 5, dark, line: 1.5)
        ear.position = CGPoint(x: 21, y: 12)
        ear.zRotation = 0.5
        flip.addChild(ear)
        let eye = SKShapeNode(circleOfRadius: 1.8)
        eye.fillColor = .white
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 29, y: 7)
        flip.addChild(eye)

        addReadyBubble(to: flip.parent, emoji: "✂️")
    }

    func drawCow(_ flip: SKNode) {
        let dark = UIColor(red: 0.22, green: 0.18, blue: 0.16, alpha: 1)
        flip.addChild(legs([-20, -10, 12, 22], top: -10, bottom: -22, color: ink, width: 4.5))

        let udder = ellipse(18, 14, UIColor(red: 0.97, green: 0.70, blue: 0.70, alpha: 1), line: 2)
        udder.name = "udder"
        udder.position = CGPoint(x: 8, y: -17)
        flip.addChild(udder)

        let tail = UIBezierPath()
        tail.move(to: CGPoint(x: -30, y: 6))
        tail.addQuadCurve(to: CGPoint(x: -38, y: -12), controlPoint: CGPoint(x: -42, y: 4))
        let tailNode = SKShapeNode(path: tail.cgPath)
        tailNode.strokeColor = ink
        tailNode.lineWidth = 2.5
        flip.addChild(tailNode)

        flip.addChild(ellipse(64, 36, .white, line: 3))
        for (x, y, w, h) in [(-12 as CGFloat, 6 as CGFloat, 18 as CGFloat, 14 as CGFloat),
                             (10, -4, 16, 12), (-2, -8, 10, 8)] {
            let spot = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
            spot.fillColor = dark
            spot.strokeColor = .clear
            spot.position = CGPoint(x: x, y: y)
            flip.addChild(spot)
        }
        let head = ellipse(24, 22, .white, line: 2.5)
        head.position = CGPoint(x: 36, y: 8)
        flip.addChild(head)
        let snout = ellipse(14, 11, UIColor(red: 0.97, green: 0.70, blue: 0.70, alpha: 1), line: 2)
        snout.position = CGPoint(x: 43, y: 3)
        flip.addChild(snout)
        let horns = UIBezierPath()
        horns.move(to: CGPoint(x: 30, y: 17)); horns.addLine(to: CGPoint(x: 27, y: 25))
        horns.move(to: CGPoint(x: 41, y: 17)); horns.addLine(to: CGPoint(x: 44, y: 25))
        let hornNode = SKShapeNode(path: horns.cgPath)
        hornNode.strokeColor = ink
        hornNode.lineWidth = 3
        flip.addChild(hornNode)
        let eye = SKShapeNode(circleOfRadius: 2)
        eye.fillColor = ink
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 38, y: 12)
        flip.addChild(eye)

        addReadyBubble(to: flip.parent, emoji: "🥛")
    }
}
