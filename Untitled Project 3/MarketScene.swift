import SpriteKit
import UIKit

extension GameScene {

    // MARK: - Прилавок

    func buildMarket() {
        let root = SKNode()

        root.position = marketPos
        root.zPosition = -(marketPos.y - 40) / 10

        let ground = ellipse(
            240,
            150,
            UIColor(
                red: 0.86,
                green: 0.78,
                blue: 0.58,
                alpha: 1
            ),
            line: 2
        )

        ground.position = CGPoint(x: 0, y: -30)
        root.addChild(ground)

        for x in [CGFloat(-65), CGFloat(65)] {
            let leg = rect(
                12,
                42,
                UIColor(
                    red: 0.43,
                    green: 0.28,
                    blue: 0.16,
                    alpha: 1
                ),
                r: 2
            )

            leg.position = CGPoint(x: x, y: -18)
            root.addChild(leg)
        }

        let tabletop = rect(
            180,
            54,
            UIColor(
                red: 0.70,
                green: 0.48,
                blue: 0.27,
                alpha: 1
            ),
            r: 7
        )

        tabletop.position = CGPoint(x: 0, y: 12)
        tabletop.zPosition = 1
        root.addChild(tabletop)

        for x in [CGFloat(-48), CGFloat(0), CGFloat(48)] {
            let box = rect(
                36,
                25,
                UIColor(
                    red: 0.86,
                    green: 0.67,
                    blue: 0.39,
                    alpha: 1
                ),
                r: 3
            )

            box.position = CGPoint(x: x, y: 20)
            box.zPosition = 2
            root.addChild(box)
        }

        let label = SKLabelNode(text: "Прилавок")

        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 24
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: 78)
        label.zPosition = 4

        root.addChild(label)
        addChild(root)

        buildCustomerRoad()
    }

    // MARK: - Дорога покупателя

    private func customerRoute() -> [CGPoint] {
        [
            CGPoint(
                x: worldSize.width - 100,
                y: marketPos.y - 200
            ),

            CGPoint(
                x: marketPos.x,
                y: marketPos.y - 200
            ),

            CGPoint(
                x: marketPos.x,
                y: marketPos.y - 80
            )
        ]
    }

    private func buildCustomerRoad() {
        let points = customerRoute()

        let path = CGMutablePath()
        path.move(to: points[0])

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        let road = SKShapeNode(path: path)

        road.strokeColor = UIColor(
            red: 0.85,
            green: 0.77,
            blue: 0.54,
            alpha: 1
        )

        road.lineWidth = 32
        road.lineCap = .round
        road.lineJoin = .round
        road.zPosition = -965

        addChild(road)
    }

    // MARK: - Покупатель

    func updateMarketCustomer() {
        let market = MarketState.shared
        market.update()

        if market.phase == .pause {
            childNode(
                withName: "marketCustomer"
            )?.removeFromParent()

            return
        }

        let customer: SKNode

        if let existing = childNode(
            withName: "marketCustomer"
        ) {
            customer = existing
        } else {
            customer = makeMarketCustomer()
            customer.name = "marketCustomer"

            addChild(customer)
        }

        let route = customerRoute()

        let target: CGPoint

        switch market.phase {
        case .approaching:
            target = pointAlongRoute(
                route,
                progress: market.phaseProgress
            )

        case .waiting:
            target = route[route.count - 1]

        case .leaving:
            target = pointAlongRoute(
                route,
                progress: 1 - market.phaseProgress
            )

        case .pause:
            return
        }

        let dx = target.x - customer.position.x

        customer.position = target
        customer.zPosition = -target.y / 10

        let walking =
            market.phase == .approaching
            || market.phase == .leaving

        if let flip = customer.childNode(withName: "flip") {
            if walking {
                if abs(dx) > 0.01 {
                    flip.xScale = dx > 0 ? 1 : -1
                }

                if flip.action(forKey: "customerWalk") == nil {
                    flip.run(
                        .repeatForever(
                            .sequence([
                                .moveBy(
                                    x: 0,
                                    y: 4,
                                    duration: 0.15
                                ),

                                .moveBy(
                                    x: 0,
                                    y: -4,
                                    duration: 0.15
                                )
                            ])
                        ),
                        withKey: "customerWalk"
                    )
                }
            } else {
                flip.removeAction(forKey: "customerWalk")
                flip.position = .zero
            }
        }

        if let bubble = customer.childNode(
            withName: "customerBubble"
        ) as? SKLabelNode {

            if market.phase == .leaving {
                bubble.text = market.angry
                    ? "Слишком дорого или долго!"
                    : "До свидания!"
            } else if let order = market.order {
                var orderText = ""

                for (index, item) in order.items.enumerated() {
                    let quantity = order.quantities[index]

                    if !orderText.isEmpty {
                        orderText += "\n"
                    }

                    orderText += "\(item.emoji) × \(quantity)"
                }

                bubble.text = orderText
            }
        }
    }

    private func makeMarketCustomer() -> SKNode {
        let root = makeWorkerNode()

        // Начальное положение сразу у входа на дорогу.
        root.position = customerRoute()[0]

        let bubble = SKLabelNode()

        bubble.name = "customerBubble"
        bubble.fontName = "AvenirNext-Heavy"
        bubble.fontSize = 18
        bubble.fontColor = ink

        bubble.position = CGPoint(x: 0, y: 52)
        bubble.zPosition = 10

        root.addChild(bubble)

        return root
    }

    // MARK: - Движение по ломаной дороге

    private func pointAlongRoute(
        _ points: [CGPoint],
        progress: Double
    ) -> CGPoint {
        guard points.count >= 2 else {
            return points.first ?? .zero
        }

        var lengths: [CGFloat] = []
        var totalLength: CGFloat = 0

        for index in 0..<(points.count - 1) {
            let length = hypot(
                points[index + 1].x - points[index].x,
                points[index + 1].y - points[index].y
            )

            lengths.append(length)
            totalLength += length
        }

        var remaining =
            totalLength * CGFloat(min(1, max(0, progress)))

        for index in 0..<lengths.count {
            let length = lengths[index]

            if remaining <= length {
                let fraction = length > 0
                    ? remaining / length
                    : 0

                let start = points[index]
                let end = points[index + 1]

                return CGPoint(
                    x: start.x + (end.x - start.x) * fraction,
                    y: start.y + (end.y - start.y) * fraction
                )
            }

            remaining -= length
        }

        return points[points.count - 1]
    }
}
