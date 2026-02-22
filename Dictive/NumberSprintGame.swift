import Foundation

struct NumberTrailTile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var value: Int
}

enum NumberTrailTapResult: Equatable {
    case started(sum: Int)
    case extended(sum: Int)
    case backtracked(sum: Int)
    case invalidMove
    case waitingForNextLevel
    case levelCleared(points: Int, nextLevel: Int)
    case bust(target: Int)
    case wonRound
    case lostRound
    case ignored
}

enum NumberTrailRoundState: String, Codable {
    case inProgress
    case won
    case lost
}

struct NumberSprintGame: Codable {
    static let persistenceVersion = 6

    private(set) var tiles: [NumberTrailTile]
    private(set) var targetSum: Int
    private(set) var currentSum: Int
    private(set) var selectedTileIDs: [UUID]
    private(set) var targetTrailTileIDs: [UUID]
    private(set) var minimalTrailLength: Int
    private(set) var hintedTileID: UUID?
    private(set) var score: Int
    private(set) var combo: Int
    private(set) var hits: Int
    private(set) var movesRemaining: Int
    private(set) var roundState: NumberTrailRoundState
    private(set) var currentLevel: Int
    private(set) var isAwaitingNextLevel: Bool

    private(set) var randomState: UInt64

    let gridWidth: Int
    let gridHeight: Int
    let maxMoves: Int
    let requiredHits: Int

    init(
        gridWidth: Int = 5,
        gridHeight: Int = 5,
        maxMoves: Int = 18,
        requiredHits: Int = 8,
        seed: UInt64 = 1,
        presetValues: [Int]? = nil,
        targetSum: Int? = nil
    ) {
        self.gridWidth = max(2, gridWidth)
        self.gridHeight = max(2, gridHeight)
        self.maxMoves = max(1, maxMoves)
        self.requiredHits = max(1, requiredHits)
        var localState = max(1, seed)
        self.randomState = localState

        let count = self.gridWidth * self.gridHeight
        if let presetValues, presetValues.count == count {
            tiles = presetValues.map { NumberTrailTile(value: min(9, max(1, $0))) }
        } else {
            tiles = (0..<count).map { _ in
                NumberTrailTile(value: Self.nextRandomInt(in: 1...9, using: &localState))
            }
        }

        selectedTileIDs = []
        targetTrailTileIDs = []
        minimalTrailLength = 3
        hintedTileID = nil
        currentSum = 0
        score = 0
        combo = 0
        hits = 0
        movesRemaining = self.maxMoves
        roundState = .inProgress
        currentLevel = 1
        isAwaitingNextLevel = false
        self.targetSum = 0
        self.randomState = localState

        if let targetSum {
            if let generated = chooseExactTrail(for: targetSum) {
                self.targetSum = generated.sum
                targetTrailTileIDs = generated.tileIDs
                minimalTrailLength = generated.minimalLength
            } else {
                let generated = generateLevelTarget(minimumSum: max(10, targetSum))
                self.targetSum = generated.sum
                targetTrailTileIDs = generated.tileIDs
                minimalTrailLength = generated.minimalLength
            }
        } else {
            let generated = generateLevelTarget(minimumSum: 10)
            self.targetSum = generated.sum
            targetTrailTileIDs = generated.tileIDs
            minimalTrailLength = generated.minimalLength
        }
    }

    var selectedTileIDSet: Set<UUID> { Set(selectedTileIDs) }

    var completion: Double {
        Double(hits) / Double(max(1, requiredHits))
    }

    var hasPlayableTargetTrail: Bool {
        targetTrailTileIDs.count >= 3
    }

    mutating func tapTile(_ id: UUID) -> NumberTrailTapResult {
        guard roundState == .inProgress else {
            return roundState == .won ? .wonRound : .lostRound
        }
        guard !isAwaitingNextLevel else { return .waitingForNextLevel }
        guard let tappedIndex = indexForTile(id) else { return .ignored }

        hintedTileID = nil

        if let selectedIndex = selectedTileIDs.firstIndex(of: id) {
            if selectedIndex == selectedTileIDs.count - 1 {
                selectedTileIDs.removeLast()
                currentSum = selectedTileIDs.reduce(0) { partial, tileID in
                    guard let index = indexForTile(tileID) else { return partial }
                    return partial + tiles[index].value
                }
                return .backtracked(sum: currentSum)
            }
            return .invalidMove
        }

        if let lastID = selectedTileIDs.last,
           let lastIndex = indexForTile(lastID),
           !areAdjacent(lastIndex, tappedIndex) {
            return .invalidMove
        }

        selectedTileIDs.append(id)
        currentSum += tiles[tappedIndex].value

        if currentSum < targetSum {
            return selectedTileIDs.count == 1 ? .started(sum: currentSum) : .extended(sum: currentSum)
        }

        if currentSum == targetSum {
            hits += 1
            combo += 1
            let points = scoreForClearedLevel(pathLength: selectedTileIDs.count)
            score += points

            if hits >= requiredHits {
                roundState = .won
                return .wonRound
            }

            isAwaitingNextLevel = true
            return .levelCleared(points: points, nextLevel: currentLevel + 1)
        }

        combo = 0
        let bustTarget = targetSum
        clearPath()
        consumeMove()
        if roundState == .lost {
            return .lostRound
        }
        return .bust(target: bustTarget)
    }

    mutating func clearPath() {
        guard !isAwaitingNextLevel else { return }
        selectedTileIDs.removeAll(keepingCapacity: true)
        currentSum = 0
        hintedTileID = nil
    }

    mutating func revealHint() -> UUID? {
        guard roundState == .inProgress, !isAwaitingNextLevel, hasPlayableTargetTrail else { return nil }

        if selectedTileIDs.isEmpty {
            hintedTileID = targetTrailTileIDs.first
            return hintedTileID
        }

        for (index, tileID) in selectedTileIDs.enumerated() {
            guard targetTrailTileIDs.indices.contains(index), targetTrailTileIDs[index] == tileID else {
                hintedTileID = targetTrailTileIDs.first
                return hintedTileID
            }
        }

        let nextIndex = selectedTileIDs.count
        guard targetTrailTileIDs.indices.contains(nextIndex) else {
            hintedTileID = nil
            return nil
        }

        hintedTileID = targetTrailTileIDs[nextIndex]
        return hintedTileID
    }

    mutating func advanceToNextLevel() -> Bool {
        guard roundState == .inProgress, isAwaitingNextLevel else { return false }

        let previousTarget = targetSum
        replaceSelectedTiles()
        selectedTileIDs.removeAll(keepingCapacity: true)
        currentSum = 0
        hintedTileID = nil
        isAwaitingNextLevel = false

        currentLevel += 1
        let generated = generateLevelTarget(minimumSum: previousTarget + 1)
        targetSum = generated.sum
        targetTrailTileIDs = generated.tileIDs
        minimalTrailLength = generated.minimalLength
        return true
    }

    mutating func reset(seed: UInt64 = 1) {
        self = NumberSprintGame(
            gridWidth: gridWidth,
            gridHeight: gridHeight,
            maxMoves: maxMoves,
            requiredHits: requiredHits,
            seed: seed
        )
    }

    private mutating func consumeMove() {
        movesRemaining = max(0, movesRemaining - 1)
        if movesRemaining == 0, hits < requiredHits {
            roundState = .lost
        }
    }

    private mutating func replaceSelectedTiles() {
        for tileID in selectedTileIDs {
            guard let index = indexForTile(tileID) else { continue }
            tiles[index].value = nextRandomInt(in: 1...9)
        }
    }

    private mutating func generateLevelTarget(minimumSum: Int) -> (sum: Int, tileIDs: [UUID], minimalLength: Int) {
        let clampedMinimum = max(6, minimumSum)

        for _ in 0..<10 {
            let options = trailOptions(minLength: 3, maxLength: 7, minimumSum: clampedMinimum, exactSum: false)
            if !options.isEmpty {
                let selected = options[nextRandomInt(in: 0...(options.count - 1))]
                let exactOptions = trailOptions(minLength: 3, maxLength: 7, minimumSum: selected.sum, exactSum: true)
                let best = exactOptions.min { lhs, rhs in
                    if lhs.indices.count != rhs.indices.count { return lhs.indices.count < rhs.indices.count }
                    return lhs.sum < rhs.sum
                } ?? selected
                return (selected.sum, best.indices.map { tiles[$0].id }, best.indices.count)
            }
            boostBoardValues()
        }

        let fallback = trailOptions(minLength: 3, maxLength: 7, minimumSum: 0, exactSum: false)
        if let best = fallback.max(by: { $0.sum < $1.sum }) {
            let exactOptions = trailOptions(minLength: 3, maxLength: 7, minimumSum: best.sum, exactSum: true)
            let shortest = exactOptions.min { $0.indices.count < $1.indices.count } ?? best
            return (best.sum, shortest.indices.map { tiles[$0].id }, shortest.indices.count)
        }

        return (clampedMinimum, tiles.prefix(3).map(\.id), 3)
    }

    private func chooseExactTrail(for sum: Int) -> (sum: Int, tileIDs: [UUID], minimalLength: Int)? {
        let options = trailOptions(minLength: 3, maxLength: 7, minimumSum: sum, exactSum: true)
        guard let shortest = options.min(by: { $0.indices.count < $1.indices.count }) else { return nil }
        return (shortest.sum, shortest.indices.map { tiles[$0].id }, shortest.indices.count)
    }

    private func scoreForClearedLevel(pathLength: Int) -> Int {
        let minimal = max(1, minimalTrailLength)
        let overhead = max(0, pathLength - minimal)
        let efficiencyBonus = max(0, 16 - (overhead * 4))
        let base = 10 + (minimal * 3)
        return base + efficiencyBonus + (combo * 3)
    }

    private mutating func boostBoardValues() {
        for index in tiles.indices where tiles[index].value < 9 {
            tiles[index].value += 1
        }
    }

    private struct TrailOption: Equatable {
        let indices: [Int]
        let sum: Int
    }

    private func trailOptions(minLength: Int, maxLength: Int, minimumSum: Int, exactSum: Bool) -> [TrailOption] {
        guard !tiles.isEmpty else { return [] }

        let cappedMaxLength = min(maxLength, tiles.count)
        guard minLength <= cappedMaxLength else { return [] }

        var options: [TrailOption] = []
        for start in tiles.indices {
            collectTrails(
                from: start,
                path: [start],
                sum: tiles[start].value,
                minLength: minLength,
                maxLength: cappedMaxLength,
                minimumSum: minimumSum,
                exactSum: exactSum,
                options: &options
            )
        }
        return options
    }

    private func collectTrails(
        from current: Int,
        path: [Int],
        sum: Int,
        minLength: Int,
        maxLength: Int,
        minimumSum: Int,
        exactSum: Bool,
        options: inout [TrailOption]
    ) {
        if path.count >= minLength {
            if exactSum {
                if sum == minimumSum {
                    options.append(TrailOption(indices: path, sum: sum))
                }
            } else if sum >= minimumSum {
                options.append(TrailOption(indices: path, sum: sum))
            }
        }

        if path.count == maxLength { return }

        for neighbor in neighborIndices(of: current) where !path.contains(neighbor) {
            collectTrails(
                from: neighbor,
                path: path + [neighbor],
                sum: sum + tiles[neighbor].value,
                minLength: minLength,
                maxLength: maxLength,
                minimumSum: minimumSum,
                exactSum: exactSum,
                options: &options
            )
        }
    }

    private func indexForTile(_ id: UUID) -> Int? {
        tiles.firstIndex(where: { $0.id == id })
    }

    private func areAdjacent(_ lhs: Int, _ rhs: Int) -> Bool {
        let lRow = lhs / gridWidth
        let lCol = lhs % gridWidth
        let rRow = rhs / gridWidth
        let rCol = rhs % gridWidth
        return abs(lRow - rRow) + abs(lCol - rCol) == 1
    }

    private func neighborIndices(of index: Int) -> [Int] {
        let row = index / gridWidth
        let col = index % gridWidth
        let candidates = [(row - 1, col), (row + 1, col), (row, col - 1), (row, col + 1)]

        return candidates.compactMap { row, col in
            guard row >= 0, row < gridHeight, col >= 0, col < gridWidth else { return nil }
            return (row * gridWidth) + col
        }
    }

    private mutating func nextRandomInt(in range: ClosedRange<Int>) -> Int {
        Self.nextRandomInt(in: range, using: &randomState)
    }

    private static func nextRandomInt(in range: ClosedRange<Int>, using state: inout UInt64) -> Int {
        state = 2862933555777941757 &* state &+ 3037000493
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        let value = Int(state % span)
        return range.lowerBound + value
    }
}
