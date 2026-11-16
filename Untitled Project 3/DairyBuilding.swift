//
//  DairyBuilding.swift
//  Untitled Project 3
//
//  Created by камиль on 16.11.2026.
//
import SpriteKit
import UIKit

extension GameScene {

    var dairyReservedArea: CGRect {
        CGRect(
            x: dairyPos.x - 280,
            y: dairyPos.y - 220,
            width: 560,
            height: 520
        )
    }

    var dairyTapArea: CGRect {
        CGRect(
            x: dairyPos.x - 160,
            y: dairyPos.y - 100,
            width: 320,
            height: 310
        )
    }

    // MARK: - Район сыроварни

    func buildDairyDistrict() {
        let road = UIBezierPath()
        road.move(to: CGPoint(x: 2100, y: 1250))
        road.addLine(to: CGPoint(x: dairyPos.x, y: 1250))
        road.addLine(
            to: CGPoint(
                x: dairyPos.x,
                y: dairyPos.y - 90
            )
        )

        let border = SKShapeNode(path: road.cgPath)
        border.strokeColor = UIColor(
            red: 0.85,
            green: 0.77,
            blue: 0.54,
            alpha: 1
        )
        border.lineWidth = 36
        border.lineCap = .round
        border.lineJoin = .round
        border.zPosition = -970
        addChild(border)

        let center = SKShapeNode(path: road.cgPath)
        center.strokeColor = UIColor(
            red: 0.91,
            green: 0.85,
            blue: 0.66,
            alpha: 1
        )
        center.lineWidth = 28
        center.lineCap = .round
        center.lineJoin = .round
        center.zPosition = -969
        addChild(center)

        let yard = SKShapeNode(
            rectOf: CGSize(width: 350, height: 290),
            cornerRadius: 24
        )
        yard.position = CGPoint(
            x: dairyPos.x,
            y: dairyPos.y + 30
        )
        yard.fillColor = UIColor(
            red: 0.78,
            green: 0.74,
            blue: 0.54,
            alpha: 1
        )
        yard.strokeColor = .clear
        yard.zPosition = -965
        addChild(yard)

        syncDairyBuilding()
    }

    // MARK: - Обновление внешнего вида

    func syncDairyBuilding() {
        let newLevel = state.dairyLevel

        guard newLevel != dairyRenderedLevel else {
            return
        }

        let previousLevel = dairyRenderedLevel

        dairyMapNode?.removeFromParent()

        let root: SKNode

        if newLevel == 0 {
            root = makeDairyConstructionSite()
        } else {
            root = makeDairyBuilding(level: newLevel)
        }

        root.position = dairyPos
        root.zPosition = -(dairyPos.y - 75) / 10
        root.name = "dairyBuilding"

        addChild(root)

        dairyMapNode = root
        dairyRenderedLevel = newLevel

        // Анимация только при покупке или улучшении.
        // При загрузке сохранения её не проигрываем.
        if previousLevel >= 0 && newLevel > previousLevel {
            root.alpha = 0
            root.setScale(0.75)

            root.run(
                .group([
                    .fadeIn(withDuration: 0.45),
                    .scale(to: 1, duration: 0.45)
                ])
            )

            floatText(
                previousLevel == 0
                    ? "Сыроварня построена!"
                    : "Сыроварня улучшена!",
                at: CGPoint(
                    x: dairyPos.x,
                    y: dairyPos.y + 160
                )
            )
        }
    }

    // MARK: - Площадка до покупки

    func makeDairyConstructionSite() -> SKNode {
        let root = SKNode()

        let foundation = rect(
            240,
            140,
            UIColor(
                red: 0.65,
                green: 0.58,
                blue: 0.43,
                alpha: 1
            ),
            r: 8
        )
        root.addChild(foundation)

        for x: CGFloat in [-110, 110] {
            let post = rect(
                12,
                100,
                UIColor(
                    red: 0.55,
                    green: 0.36,
                    blue: 0.20,
                    alpha: 1
                ),
                r: 2
            )
            post.position = CGPoint(x: x, y: 0)
            root.addChild(post)
        }

        let board = rect(
            250,
            85,
            UIColor(
                red: 0.94,
                green: 0.85,
                blue: 0.64,
                alpha: 1
            ),
            r: 6
        )
        board.position = CGPoint(x: 0, y: 30)
        board.zPosition = 1
        root.addChild(board)

        addDairyLabel(
            "Сыроварня",
            to: root,
            at: CGPoint(x: 0, y: 45),
            size: 25
        )

        addDairyLabel(
            "Построить: 1000 монет",
            to: root,
            at: CGPoint(x: 0, y: 12),
            size: 17
        )

        return root
    }

    // MARK: - Готовое здание

    func makeDairyBuilding(level: Int) -> SKNode {
        let root = SKNode()

        let wall = rect(
            230,
            150,
            UIColor(
                red: 0.98,
                green: 0.90,
                blue: 0.66,
                alpha: 1
            ),
            r: 6
        )
        root.addChild(wall)

        let door = rect(
            48,
            70,
            UIColor(
                red: 0.49,
                green: 0.32,
                blue: 0.20,
                alpha: 1
            ),
            r: 4
        )
        door.position = CGPoint(x: 55, y: -40)
        door.zPosition = 1
        root.addChild(door)

        let window = rect(
            60,
            45,
            UIColor(
                red: 0.64,
                green: 0.85,
                blue: 0.94,
                alpha: 1
            ),
            r: 4
        )
        window.position = CGPoint(x: -55, y: -10)
        window.zPosition = 1
        root.addChild(window)

        let roofPath = UIBezierPath()
        roofPath.move(to: CGPoint(x: -135, y: 72))
        roofPath.addLine(to: CGPoint(x: 0, y: 155))
        roofPath.addLine(to: CGPoint(x: 135, y: 72))
        roofPath.close()

        let roof = shape(
            SKShapeNode(path: roofPath.cgPath),
            fill: UIColor(
                red: 0.76,
                green: 0.43,
                blue: 0.18,
                alpha: 1
            )
        )
        roof.zPosition = 2
        root.addChild(roof)

        addDairyLabel(
            "СЫРОВАРНЯ",
            to: root,
            at: CGPoint(x: 0, y: 45),
            size: 20
        )

        addDairyLabel(
            "Уровень \(level)",
            to: root,
            at: CGPoint(x: 0, y: 185),
            size: 22
        )

        // На втором уровне появляется ёмкость для молока.
        if level >= 2 {
            let tank = rect(
                40,
                75,
                UIColor(
                    red: 0.77,
                    green: 0.81,
                    blue: 0.84,
                    alpha: 1
                ),
                r: 12
            )
            tank.position = CGPoint(x: -145, y: -35)
            tank.zPosition = 1
            root.addChild(tank)
        }

        // На третьем уровне добавляются ящики продукции.
        if level >= 3 {
            for index in 0..<2 {
                let box = rect(
                    34,
                    30,
                    UIColor(
                        red: 0.79,
                        green: 0.59,
                        blue: 0.30,
                        alpha: 1
                    ),
                    r: 3
                )
                box.position = CGPoint(
                    x: 140 + CGFloat(index) * 12,
                    y: -58 + CGFloat(index) * 28
                )
                box.zPosition = CGFloat(index + 1)
                root.addChild(box)
            }
        }

        return root
    }

    private func addDairyLabel(
        _ text: String,
        to parent: SKNode,
        at position: CGPoint,
        size: CGFloat
    ) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = size
        label.fontColor = ink
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = 5
        parent.addChild(label)
    }
}
