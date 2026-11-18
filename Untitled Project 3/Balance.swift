import Foundation

/// Все числа баланса в одном месте. Меняйте их под себя.
enum Balance {
    // Скорость игры (чем больше, тем медленнее)
    static let growthTimeScale = 2.5
    static let animalTimeScale = 3.0
    static let regrowTime = 400.0
    
    // Пекарня и уголь
    static let bakeTime = 20.0
    static let breadWheat = 2
    static let coalPerBatch = 1
    static let coalPrice = 15

    // Шахта (секунды)
    static let mineTripTime = 60.0
    static let mineRestTime = 180.0
    static let mineBaseYield = 3
    static let pickaxeYieldStep = 2
    static let pickaxeTimeFactor = 0.9

    // Экономика
    static let startCoins = 300
    static let upgradeCostFactor = 2.0
    static let animalPriceStep = 0.3
    static let maxWorkers = 7
}
