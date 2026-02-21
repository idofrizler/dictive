import Foundation

struct BubbleCell: Identifiable {
    let id = UUID()
    let targetColorIndex: Int
    var isPainted: Bool = false
}

enum BubbleTapResult {
    case match
    case mismatch
    case alreadyPainted
}

struct TapGame {
    private(set) var cells: [BubbleCell]
    private(set) var selectedColorIndex: Int
    private(set) var score: Int
    private(set) var streak: Int

    let paletteCount: Int

    var paintedCount: Int { cells.filter(\.isPainted).count }
    var totalCount: Int { cells.count }
    var completion: Double { Double(paintedCount) / Double(totalCount) }
    var isCompleted: Bool { paintedCount == totalCount }

    init(cellCount: Int = 30, paletteCount: Int = 6) {
        self.paletteCount = paletteCount
        self.selectedColorIndex = 0
        self.score = 0
        self.streak = 0
        self.cells = (0..<cellCount).map { _ in
            BubbleCell(targetColorIndex: Int.random(in: 0..<paletteCount))
        }
    }

    mutating func selectColor(_ index: Int) {
        guard (0..<paletteCount).contains(index) else { return }
        selectedColorIndex = index
    }

    mutating func tapCell(_ id: UUID) -> BubbleTapResult {
        guard let idx = cells.firstIndex(where: { $0.id == id }) else { return .alreadyPainted }
        guard !cells[idx].isPainted else { return .alreadyPainted }

        if cells[idx].targetColorIndex == selectedColorIndex {
            cells[idx].isPainted = true
            streak += 1
            score += 5 + min(streak, 6)
            return .match
        }

        streak = 0
        score = max(0, score - 1)
        return .mismatch
    }

    func remainingCount(for colorIndex: Int) -> Int {
        cells.filter { !$0.isPainted && $0.targetColorIndex == colorIndex }.count
    }

    mutating func newBoard(cellCount: Int = 30) {
        score = 0
        streak = 0
        selectedColorIndex = 0
        cells = (0..<cellCount).map { _ in
            BubbleCell(targetColorIndex: Int.random(in: 0..<paletteCount))
        }
    }
}
