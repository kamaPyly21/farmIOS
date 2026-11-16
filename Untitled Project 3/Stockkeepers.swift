//
//  Stockkeepers.swift
//  Untitled Project 3
//
//  Created by камиль on 16.11.2026.
//

import SpriteKit
import UIKit

extension GameScene {

    // MARK: - Обновление животноводов

    func updateStockkeepers() {
        syncStockkeepers()

        for keeper in stockkeepers {
            keeper.node.zPosition = -keeper.node.position.y / 10

            guard !keeper.busy else { continue }

            guard let animal = nearestAvailableAnimal(
                to: keeper.node.position
            ) else {
                continue
            }

            assignStockkeeper(keeper, to: animal)
        }
    }

    // MARK: - Найм

    func syncStockkeepers() {
        let wantedCount = state.stockkeeperCount

        while stockkeepers.count < wantedCount {
            let node = makeStockkeeperNode()

            node.position = CGPoint(
                x: barnPos.x - 100
                    + CGFloat(stockkeepers.count) * 35,
                y: barnPos.y - 130
            )

            addChild(node)

            let keeper = WorkerRef(node: node)
            stockkeepers.append(keeper)
        }
    }

    // MARK: - Поиск задания

    func animalNeedsCollection(_ animal: AnimalRef) -> Bool {
        switch animal.type {
        case .chicken:
            return animal.product != nil

        case .sheep, .cow:
            return careProgress(animal) >= 1
        }
    }

    func nearestAvailableAnimal(
        to position: CGPoint
    ) -> AnimalRef? {
        var nearest: AnimalRef?
        var nearestDistance = CGFloat.greatestFiniteMagnitude

        for animal in animals {
            let animalID = ObjectIdentifier(animal)

            guard !reservedAnimals.contains(animalID) else {
                continue
            }

            guard animalNeedsCollection(animal) else {
                continue
            }

            let destination = collectionPosition(for: animal)

            let distance = hypot(
                destination.x - position.x,
                destination.y - position.y
            )

            if distance < nearestDistance {
                nearestDistance = distance
                nearest = animal
            }
        }

        return nearest
    }

    func collectionPosition(
        for animal: AnimalRef
    ) -> CGPoint {
        if animal.type == .chicken,
           let egg = animal.product {
            return egg.position
        }

        return animal.node.position
    }

    // MARK: - Выполнение задания

    func assignStockkeeper(
        _ keeper: WorkerRef,
        to animal: AnimalRef
    ) {
        keeper.busy = true
        reservedAnimals.insert(ObjectIdentifier(animal))

        // Овца или корова ждёт, пока к ней подойдут.
        // Курица продолжает ходить: работник идёт к яйцу.
        if animal.type != .chicken {
            animal.node.removeAction(forKey: "wander")

            if let flip = animal.node.childNode(
                withName: "flip"
            ) {
                flip.removeAction(forKey: "bob")
                flip.position = .zero
            }
        }

        let destination = collectionPosition(for: animal)

        let target = CGPoint(
            x: destination.x - 28,
            y: destination.y - 18
        )

        let dx = target.x - keeper.node.position.x
        let dy = target.y - keeper.node.position.y
        let distance = hypot(dx, dy)

        let flip = keeper.node.childNode(withName: "flip")

        if abs(dx) > 2 {
            flip?.xScale = dx > 0 ? 1 : -1
        }

        let walking = SKAction.repeatForever(
            .sequence([
                .moveBy(x: 0, y: 4, duration: 0.12),
                .moveBy(x: 0, y: -4, duration: 0.12)
            ])
        )

        flip?.run(walking, withKey: "bob")

        let action = SKAction.sequence([
            .move(
                to: target,
                duration: max(0.2, Double(distance) / 120)
            ),

            .run { [weak self, weak keeper, weak animal] in
                guard let self = self,
                      let keeper = keeper,
                      let animal = animal else {
                    return
                }

                self.beginStockkeeperWork(
                    keeper,
                    animal: animal
                )
            }
        ])

        keeper.node.run(action, withKey: "stockkeeperTask")
    }

    func beginStockkeeperWork(
        _ keeper: WorkerRef,
        animal: AnimalRef
    ) {
        let flip = keeper.node.childNode(withName: "flip")

        flip?.removeAction(forKey: "bob")
        flip?.position = .zero

        // Животное могли отправить на мясо,
        // пока работник шёл к нему.
        guard animals.contains(where: { $0 === animal }),
              animalNeedsCollection(animal) else {
            releaseStockkeeper(keeper, animal: animal)
            return
        }

        showStockkeeperTool(keeper, animal: animal)

        let working = SKAction.repeatForever(
            .sequence([
                .rotate(toAngle: 0.12, duration: 0.2),
                .rotate(toAngle: -0.12, duration: 0.2)
            ])
        )

        flip?.run(working, withKey: "working")

        keeper.node.run(
            .sequence([
                .wait(forDuration: 2.0),

                .run { [weak self, weak keeper, weak animal] in
                    guard let self = self,
                          let keeper = keeper,
                          let animal = animal else {
                        return
                    }

                    self.finishStockkeeperWork(
                        keeper,
                        animal: animal
                    )
                }
            ]),
            withKey: "stockkeeperTask"
        )
    }

    func finishStockkeeperWork(
        _ keeper: WorkerRef,
        animal: AnimalRef
    ) {
        if animals.contains(where: { $0 === animal }),
           animalNeedsCollection(animal) {

            switch animal.type {
            case .chicken:
                collectProduct(a: animal)

            case .sheep, .cow:
                _ = tryCare(animal)
            }
        }

        releaseStockkeeper(keeper, animal: animal)
    }

    func releaseStockkeeper(
        _ keeper: WorkerRef,
        animal: AnimalRef
    ) {
        reservedAnimals.remove(ObjectIdentifier(animal))

        keeper.node.childNode(
            withName: "tool"
        )?.removeFromParent()

        if let flip = keeper.node.childNode(
            withName: "flip"
        ) {
            flip.removeAction(forKey: "bob")
            flip.removeAction(forKey: "working")
            flip.position = .zero
            flip.zRotation = 0
        }

        if animal.type != .chicken,
           animals.contains(where: { $0 === animal }) {
            wander(animal)
        }

        keeper.busy = false
    }

    // MARK: - Внешний вид

    func makeStockkeeperNode() -> SKNode {
        let root = makeWorkerNode()

        // У существующего работника тело —
        // прямоугольник 18 × 22 внутри узла flip.
        if let flip = root.childNode(withName: "flip") {
            for child in flip.children {
                guard let shape = child as? SKShapeNode,
                      let path = shape.path else {
                    continue
                }

                let bounds = path.boundingBox

                if abs(bounds.width - 18) < 0.5,
                   abs(bounds.height - 22) < 0.5 {
                    shape.fillColor = UIColor(
                        red: 0.24,
                        green: 0.60,
                        blue: 0.32,
                        alpha: 1
                    )
                }
            }
        }

        return root
    }

    func showStockkeeperTool(
        _ keeper: WorkerRef,
        animal: AnimalRef
    ) {
        keeper.node.childNode(
            withName: "tool"
        )?.removeFromParent()

        let tool = SKLabelNode()

        switch animal.type {
        case .chicken:
            tool.text = "🥚"

        case .sheep:
            tool.text = "✂️"

        case .cow:
            tool.text = "🪣"
        }

        tool.name = "tool"
        tool.fontSize = 24
        tool.position = CGPoint(x: 22, y: 10)
        tool.zPosition = 10

        keeper.node.addChild(tool)
    }
}
