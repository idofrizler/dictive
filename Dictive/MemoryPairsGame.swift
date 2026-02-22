import Foundation

struct MemoryCard: Identifiable, Codable {
    var id: UUID = UUID()
    let symbol: String
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

enum MemoryTapResult: Equatable {
    case firstReveal
    case match
    case mismatch
    case ignored
}

struct MemoryPairsGame: Codable {
    static let persistenceVersion = 2
    static let defaultSymbols = ["🐶", "🐱", "🐰", "🦊", "🐼", "🐸", "🦁", "🐵", "🐨", "🐧", "🐙", "🐢", "🦋", "🐠", "🦄", "🐞", "🦕", "🦜", "🐳", "🦓"]

    private(set) var cards: [MemoryCard]
    private(set) var moveCount: Int
    private(set) var matchCount: Int
    private(set) var mismatchCount: Int

    private var firstRevealedCardID: UUID?
    private var pendingMismatch: PendingMismatch?

    private struct PendingMismatch: Codable {
        let firstID: UUID
        let secondID: UUID
    }

    init(pairCount: Int = 6, symbols: [String] = MemoryPairsGame.defaultSymbols, selectionSeed: UInt64 = 1, shuffleSeed: UInt64 = 1) {
        let selected = Self.selectSymbols(pairCount: pairCount, from: symbols, selectionSeed: selectionSeed)
        var generated = selected.flatMap { symbol in
            [MemoryCard(symbol: symbol), MemoryCard(symbol: symbol)]
        }
        var generator = SeededGenerator(state: shuffleSeed)
        generated.shuffle(using: &generator)
        cards = generated
        moveCount = 0
        matchCount = 0
        mismatchCount = 0
    }

    var totalPairs: Int { cards.count / 2 }
    var isCompleted: Bool { matchCount == totalPairs }
    var completion: Double { totalPairs == 0 ? 1 : Double(matchCount) / Double(totalPairs) }

    mutating func tapCard(_ id: UUID) -> MemoryTapResult {
        resolvePendingMismatch()
        guard let tappedIndex = cards.firstIndex(where: { $0.id == id }) else { return .ignored }
        guard !cards[tappedIndex].isMatched, !cards[tappedIndex].isFaceUp else { return .ignored }

        cards[tappedIndex].isFaceUp = true
        if let firstID = firstRevealedCardID,
           let firstIndex = cards.firstIndex(where: { $0.id == firstID }) {
            moveCount += 1
            if cards[firstIndex].symbol == cards[tappedIndex].symbol {
                cards[firstIndex].isMatched = true
                cards[tappedIndex].isMatched = true
                matchCount += 1
                firstRevealedCardID = nil
                return .match
            }

            mismatchCount += 1
            pendingMismatch = PendingMismatch(firstID: cards[firstIndex].id, secondID: cards[tappedIndex].id)
            firstRevealedCardID = nil
            return .mismatch
        }

        firstRevealedCardID = cards[tappedIndex].id
        return .firstReveal
    }

    mutating func reset(pairCount: Int? = nil, symbols: [String] = MemoryPairsGame.defaultSymbols, selectionSeed: UInt64 = 1, shuffleSeed: UInt64 = 1) {
        self = MemoryPairsGame(pairCount: pairCount ?? totalPairs, symbols: symbols, selectionSeed: selectionSeed, shuffleSeed: shuffleSeed)
    }

    private mutating func resolvePendingMismatch() {
        guard let pendingMismatch else { return }
        for id in [pendingMismatch.firstID, pendingMismatch.secondID] {
            guard let index = cards.firstIndex(where: { $0.id == id }), !cards[index].isMatched else { continue }
            cards[index].isFaceUp = false
        }
        self.pendingMismatch = nil
    }

    private static func selectSymbols(pairCount: Int, from symbols: [String], selectionSeed: UInt64) -> [String] {
        let uniqueSymbols = Array(Set(symbols)).sorted()
        let safePairCount = max(2, min(pairCount, uniqueSymbols.count))
        var shuffledSymbols = uniqueSymbols
        var generator = SeededGenerator(state: selectionSeed)
        shuffledSymbols.shuffle(using: &generator)
        return Array(shuffledSymbols.prefix(safePairCount))
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }
}
