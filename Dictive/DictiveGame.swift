import Foundation

struct BubbleCell: Identifiable, Codable {
    var id: UUID = UUID()
    let targetColorIndex: Int
    var isPainted: Bool = false
}

enum BubbleTapResult: Equatable {
    case match
    case mismatch
    case alreadyPainted
}

struct DrawingGalleryItem: Identifiable {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let cells: [BubbleCell]
    let completion: Double
    let isCompleted: Bool

    var isInProgress: Bool {
        completion > 0 && !isCompleted
    }
}

struct TapGame: Codable {
    static let persistenceVersion = 5
    static let transparentColorIndex = -1

    struct DrawingTemplate: Codable {
        let id: String
        let name: String
        let width: Int
        let height: Int
        let colors: [Int]
    }

    struct DrawingState: Codable {
        let template: DrawingTemplate
        var cells: [BubbleCell]
        var score: Int = 0
        var streak: Int = 0

        var paintedCount: Int { cells.filter { $0.targetColorIndex >= 0 && $0.isPainted }.count }
        var paintableCount: Int { cells.filter { $0.targetColorIndex >= 0 }.count }
        var completion: Double {
            guard paintableCount > 0 else { return 1 }
            return Double(paintedCount) / Double(paintableCount)
        }
        var isCompleted: Bool { paintedCount == paintableCount }
    }

    private(set) var drawings: [DrawingState]
    private(set) var selectedColorIndex: Int
    private(set) var currentDrawingID: String?

    let paletteCount: Int

    var galleryItems: [DrawingGalleryItem] {
        drawings.map {
            DrawingGalleryItem(
                id: $0.template.id,
                name: $0.template.name,
                width: $0.template.width,
                height: $0.template.height,
                cells: $0.cells,
                completion: $0.completion,
                isCompleted: $0.isCompleted
            )
        }
    }

    var currentDrawingName: String {
        currentDrawing?.template.name ?? ""
    }

    var currentGridWidth: Int {
        currentDrawing?.template.width ?? 0
    }

    var currentGridHeight: Int {
        currentDrawing?.template.height ?? 0
    }

    var cells: [BubbleCell] { currentDrawing?.cells ?? [] }
    var score: Int { currentDrawing?.score ?? 0 }
    var streak: Int { currentDrawing?.streak ?? 0 }
    var paintedCount: Int { currentDrawing?.paintedCount ?? 0 }
    var totalCount: Int { currentDrawing?.paintableCount ?? 0 }
    var completion: Double { currentDrawing?.completion ?? 0 }
    var isCompleted: Bool { currentDrawing?.isCompleted ?? false }

    private var currentDrawing: DrawingState? {
        guard let idx = currentDrawingIndex else { return nil }
        return drawings[idx]
    }

    private var currentDrawingIndex: Int? {
        guard let currentDrawingID else { return nil }
        return drawings.firstIndex(where: { $0.template.id == currentDrawingID })
    }

    var availableColorIndices: [Int] {
        guard let drawing = currentDrawing else { return [] }
        return (0..<paletteCount).filter { colorIndex in
            drawing.cells.contains(where: { $0.targetColorIndex == colorIndex })
        }
    }

    init(paletteCount: Int = 32) {
        self.paletteCount = paletteCount
        self.selectedColorIndex = 0
        self.currentDrawingID = nil
        self.drawings = Self.templates().map { template in
            let normalizedColors = template.colors.map { $0 < 0 ? Self.transparentColorIndex : ($0 % max(1, paletteCount)) }
            return DrawingState(
                template: template,
                cells: normalizedColors.map { BubbleCell(targetColorIndex: $0, isPainted: $0 < 0) }
            )
        }
    }

    mutating func selectColor(_ index: Int) {
        guard (0..<paletteCount).contains(index) else { return }
        selectedColorIndex = index
    }

    mutating func selectDrawing(_ drawingID: String) {
        guard let drawingIndex = drawings.firstIndex(where: { $0.template.id == drawingID }) else { return }
        currentDrawingID = drawingID
        selectedColorIndex = firstAvailableColor(in: drawings[drawingIndex]) ?? 0
    }

    mutating func leaveDrawing() {
        currentDrawingID = nil
    }

    mutating func tapCell(_ id: UUID) -> BubbleTapResult {
        guard let drawingIndex = currentDrawingIndex else { return .alreadyPainted }
        guard let cellIndex = drawings[drawingIndex].cells.firstIndex(where: { $0.id == id }) else { return .alreadyPainted }
        guard drawings[drawingIndex].cells[cellIndex].targetColorIndex >= 0 else { return .alreadyPainted }
        guard !drawings[drawingIndex].cells[cellIndex].isPainted else { return .alreadyPainted }

        if drawings[drawingIndex].cells[cellIndex].targetColorIndex == selectedColorIndex {
            drawings[drawingIndex].cells[cellIndex].isPainted = true
            drawings[drawingIndex].streak += 1
            drawings[drawingIndex].score += 5 + min(drawings[drawingIndex].streak, 6)
            return .match
        }

        drawings[drawingIndex].streak = 0
        drawings[drawingIndex].score = max(0, drawings[drawingIndex].score - 1)
        return .mismatch
    }

    mutating func eraseCell(_ id: UUID) -> Bool {
        guard let drawingIndex = currentDrawingIndex else { return false }
        guard let cellIndex = drawings[drawingIndex].cells.firstIndex(where: { $0.id == id }) else { return false }
        guard drawings[drawingIndex].cells[cellIndex].targetColorIndex >= 0 else { return false }
        guard drawings[drawingIndex].cells[cellIndex].isPainted else { return false }

        drawings[drawingIndex].cells[cellIndex].isPainted = false
        drawings[drawingIndex].streak = 0
        drawings[drawingIndex].score = max(0, drawings[drawingIndex].score - 1)
        return true
    }

    func remainingCount(for colorIndex: Int) -> Int {
        guard let drawing = currentDrawing else { return 0 }
        return drawing.cells.filter { !$0.isPainted && $0.targetColorIndex == colorIndex }.count
    }

    func totalCount(for colorIndex: Int) -> Int {
        guard let drawing = currentDrawing else { return 0 }
        return drawing.cells.filter { $0.targetColorIndex == colorIndex }.count
    }

    mutating func resetCurrentDrawing() {
        guard let drawingIndex = currentDrawingIndex else { return }
        drawings[drawingIndex].score = 0
        drawings[drawingIndex].streak = 0
        for idx in drawings[drawingIndex].cells.indices {
            drawings[drawingIndex].cells[idx].isPainted = drawings[drawingIndex].cells[idx].targetColorIndex < 0
        }
        selectedColorIndex = firstAvailableColor(in: drawings[drawingIndex]) ?? 0
    }

    mutating func newBoard() {
        resetCurrentDrawing()
    }

    private static func templates() -> [DrawingTemplate] {
        [
            upscaled(makeSmiley(), factor: 2),
            upscaled(makeRocket(), factor: 2),
            upscaled(makeHeart(), factor: 2),
            upscaled(makeStar(), factor: 2),
            upscaled(makeFlower(), factor: 2),
            upscaled(makeFish(), factor: 2),
            upscaled(makeHouse(), factor: 2),
            upscaled(makeTree(), factor: 2)
        ]
    }

    private func firstAvailableColor(in drawing: DrawingState) -> Int? {
        (0..<paletteCount).first(where: { colorIndex in
            drawing.cells.contains(where: { $0.targetColorIndex == colorIndex })
        })
    }

    private static func upscaled(_ template: DrawingTemplate, factor: Int) -> DrawingTemplate {
        guard factor > 1 else { return template }
        let upscaledWidth = template.width * factor
        let upscaledHeight = template.height * factor
        var upscaledColors = Array(repeating: 0, count: upscaledWidth * upscaledHeight)

        for y in 0..<template.height {
            for x in 0..<template.width {
                let sourceColor = template.colors[(y * template.width) + x]
                for dy in 0..<factor {
                    for dx in 0..<factor {
                        let ny = (y * factor) + dy
                        let nx = (x * factor) + dx
                        upscaledColors[(ny * upscaledWidth) + nx] = sourceColor
                    }
                }
            }
        }

        return DrawingTemplate(
            id: template.id,
            name: template.name,
            width: upscaledWidth,
            height: upscaledHeight,
            colors: upscaledColors
        )
    }

// Used palette indexes (32 fixed buckets): 5:brown, 6:charcoal, 13:gold, 15:umber, 16:slate, 17:gray, 20:lime, 21:leaf, 28:storm, 30:darkgray, 31:black
private static func makeSmiley() -> DrawingTemplate {
            let width = 18
            let height = 18
            let colors = [
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, 17, 5, 15, 15, 5, 17, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 15, 20, 13, 13, 13, 13, 20, 15, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, 15, 13, 13, 13, 13, 13, 13, 13, 13, 15, -1, -1, -1, -1,
                -1, -1, -1, 17, 20, 13, 20, 21, 13, 13, 21, 20, 13, 20, 17, -1, -1, -1,
                -1, -1, -1, 15, 13, 13, 30, 31, 13, 13, 31, 30, 13, 13, 15, -1, -1, -1,
                -1, -1, -1, 15, 13, 13, 15, 6, 13, 13, 6, 15, 13, 13, 15, -1, -1, -1,
                -1, -1, -1, 15, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 15, -1, -1, -1,
                -1, -1, -1, 15, 13, 15, 5, 21, 21, 21, 21, 5, 15, 13, 15, -1, -1, -1,
                -1, -1, -1, 17, 20, 15, 28, 5, 16, 16, 5, 28, 15, 20, 17, -1, -1, -1,
                -1, -1, -1, -1, 15, 20, 30, 15, 15, 15, 15, 6, 20, 15, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 15, 20, 21, 5, 5, 21, 20, 15, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, 17, 5, 21, 21, 5, 17, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
            ]
            return DrawingTemplate(id: "smiley", name: "Smiley", width: width, height: height, colors: colors)
        }

// Used palette indexes (32 fixed buckets): 0:red, 4:teal, 5:brown, 6:charcoal, 7:lightgray, 8:sky, 12:coral, 13:gold, 15:umber, 16:slate, 17:gray, 18:bluegray, 20:lime, 21:leaf, 27:white, 28:storm, 30:darkgray
private static func makeRocket() -> DrawingTemplate {
            let width = 18
            let height = 18
            let colors = [
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 7, 7, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 17, 15, 15, 0, 15, 7, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, 15, 0, 15, 15, 12, 0, 7, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 15, 12, 15, 7, 27, 15, 15, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, 5, 0, 12, 15, 17, 7, 15, 15, -1, -1, -1,
                -1, -1, -1, -1, -1, 16, 18, 15, 12, 0, 12, 15, 15, 0, 17, -1, -1, -1,
                -1, -1, -1, 7, 16, 7, 16, 0, 15, 15, 12, 12, 12, 15, -1, -1, -1, -1,
                -1, -1, -1, 18, 16, 7, 30, 30, 16, 12, 12, 0, 15, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, 7, 28, 30, 4, 5, 0, 15, 15, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, 5, 21, 16, 17, 6, 28, 18, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, 5, 20, 13, 20, 18, 8, 8, 16, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, 21, 13, 20, 5, 7, 16, 18, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, 7, 15, 15, 5, -1, -1, 18, 7, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
            ]
            return DrawingTemplate(id: "rocket", name: "Rocket", width: width, height: height, colors: colors)
        }

// Used palette indexes (32 fixed buckets): 0:red, 5:brown, 7:lightgray, 12:coral, 15:umber, 17:gray
private static func makeHeart() -> DrawingTemplate {
            let width = 18
            let height = 18
            let colors = [
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, 5, 15, 15, 15, 7, 7, 15, 15, 15, 5, -1, -1, -1, -1,
                -1, -1, -1, 5, 0, 12, 12, 12, 15, 15, 12, 12, 12, 0, 5, -1, -1, -1,
                -1, -1, -1, 15, 12, 0, 0, 12, 12, 12, 12, 0, 0, 12, 15, -1, -1, -1,
                -1, -1, -1, 15, 12, 0, 12, 12, 12, 12, 12, 12, 0, 12, 15, -1, -1, -1,
                -1, -1, -1, 15, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 15, -1, -1, -1,
                -1, -1, -1, 7, 15, 12, 0, 12, 12, 12, 12, 0, 12, 15, 7, -1, -1, -1,
                -1, -1, -1, -1, 17, 0, 12, 0, 12, 12, 0, 12, 0, 17, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 5, 0, 12, 0, 0, 12, 0, 5, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, 15, 12, 12, 12, 12, 15, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, 15, 12, 12, 15, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, 7, 15, 15, 7, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 17, 17, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
            ]
            return DrawingTemplate(id: "heart", name: "Heart", width: width, height: height, colors: colors)
        }

// Used palette indexes (32 fixed buckets): 5:brown, 7:lightgray, 13:gold, 15:umber, 17:gray, 20:lime, 21:leaf, 28:storm
private static func makeStar() -> DrawingTemplate {
            let width = 18
            let height = 18
            let colors = [
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 7, 7, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 15, 15, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, 7, 21, 21, 7, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, 5, 13, 13, 5, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 7, 17, 21, 13, 13, 21, 17, 7, -1, -1, -1, -1, -1,
                -1, -1, 28, 15, 21, 21, 20, 13, 13, 13, 13, 20, 21, 21, 15, 28, -1, -1,
                -1, -1, 7, 15, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 15, 7, -1, -1,
                -1, -1, -1, -1, 15, 13, 13, 13, 13, 13, 13, 13, 13, 15, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 15, 13, 13, 13, 13, 13, 13, 15, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 5, 13, 13, 13, 13, 13, 13, 5, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 15, 13, 13, 13, 13, 13, 13, 15, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 21, 13, 21, 5, 5, 21, 13, 21, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, 7, 15, 5, 7, -1, -1, 7, 5, 15, 7, -1, -1, -1, -1,
                -1, -1, -1, -1, 7, 17, -1, -1, -1, -1, -1, -1, 17, 7, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
            ]
            return DrawingTemplate(id: "star", name: "Star", width: width, height: height, colors: colors)
        }

// Used palette indexes (32 fixed buckets): 3:green, 5:brown, 6:charcoal, 7:lightgray, 15:umber, 16:slate, 17:gray, 21:leaf, 27:white, 28:storm, 29:petalpink, 30:darkgray
private static func makeFlower() -> DrawingTemplate {
            let width = 18
            let height = 18
            let colors = [
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 7, 16, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 5, 17, 5, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 5, 27, 5, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 15, 5, 15, 15, 29, 15, 15, 5, 15, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 15, 29, 29, 5, 15, 5, 29, 27, 15, 7, -1, -1, -1,
                -1, -1, -1, 17, 7, 17, 5, 17, 15, 6, 5, 5, 5, 17, -1, -1, -1, -1,
                -1, -1, -1, 30, 3, 15, 28, 15, 17, 5, 29, 15, 17, -1, -1, -1, -1, -1,
                -1, -1, -1, 28, 21, 3, 5, 29, 29, 6, 29, 29, 5, 7, -1, -1, -1, -1,
                -1, -1, -1, 7, 30, 30, 5, 29, 15, 7, 5, 29, 5, 17, -1, -1, -1, -1,
                -1, -1, -1, -1, 17, 3, 30, 17, 16, 7, -1, 17, 16, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, 27, -1, 17, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, 17, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, 17, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, 17, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
            ]
            return DrawingTemplate(id: "flower", name: "Flower", width: width, height: height, colors: colors)
        }

// Used palette indexes (32 fixed buckets): 7:lightgray, 16:slate, 17:gray, 18:bluegray, 28:storm
private static func makeFish() -> DrawingTemplate {
            let width = 18
            let height = 18
            let colors = [
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 7, 17, 17, 7, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 16, 7, 7, 16, 17, -1, -1, -1, -1, -1,
                -1, -1, -1, 28, 16, 7, -1, -1, 28, 7, 7, 7, 28, 17, -1, -1, -1, -1,
                -1, -1, 7, 17, 7, 28, 17, 16, 16, 7, 7, 7, 7, 7, 28, 7, -1, -1,
                -1, -1, -1, 16, 7, 7, 18, 17, 7, 16, 16, 7, 7, 7, 7, 28, -1, -1,
                -1, -1, -1, 16, 7, 7, 7, 7, 7, 18, 7, 7, 7, 7, 7, 18, -1, -1,
                -1, -1, -1, 28, 7, 7, 7, 7, 7, 28, 17, 7, 7, 7, 7, 18, -1, -1,
                -1, -1, 17, 7, 7, 7, 18, 28, 7, 7, 7, 7, 7, 7, 7, 16, -1, -1,
                -1, -1, 17, 16, 16, 16, -1, 7, 28, 16, 7, 7, 7, 16, 16, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, 7, 28, 7, 28, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 16, 16, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
            ]
            return DrawingTemplate(id: "fish", name: "Fish", width: width, height: height, colors: colors)
        }

// Used palette indexes (32 fixed buckets): 0:red, 5:brown, 6:charcoal, 7:lightgray, 12:coral, 15:umber, 16:slate, 17:gray, 27:white, 28:storm, 30:darkgray
private static func makeHouse() -> DrawingTemplate {
            let width = 18
            let height = 18
            let colors = [
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 7, 30, 30, 15, 15, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 7, 6, 15, 12, 12, 15, 7, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 17, 15, 12, 12, 12, 12, 15, 7, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, 7, 6, 0, 15, 15, 15, 15, 0, 6, 7, -1, -1, -1, -1,
                -1, -1, -1, -1, 16, 7, 7, 7, 7, 7, 7, 7, 7, 16, -1, -1, -1, -1,
                -1, -1, -1, -1, 17, 27, 7, 7, 27, 27, 7, 7, 27, 17, -1, -1, -1, -1,
                -1, -1, -1, -1, 17, 7, 30, 15, 15, 7, 28, 16, 17, 17, -1, -1, -1, -1,
                -1, -1, -1, -1, 17, 7, 15, 5, 5, 7, 28, 28, 17, 17, -1, -1, -1, -1,
                -1, -1, -1, -1, 17, 27, 15, 5, 15, 27, 27, 27, 27, 17, -1, -1, -1, -1,
                -1, -1, -1, -1, 17, 17, 30, 15, 30, 7, 7, 7, 7, 16, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 7, 7, 7, 7, 7, 7, 7, 7, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
            ]
            return DrawingTemplate(id: "house", name: "House", width: width, height: height, colors: colors)
        }

// Used palette indexes (32 fixed buckets): 3:green, 5:brown, 6:charcoal, 7:lightgray, 15:umber, 16:slate, 17:gray, 20:lime, 21:leaf, 28:storm, 30:darkgray
private static func makeTree() -> DrawingTemplate {
            let width = 18
            let height = 18
            let colors = [
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, 7, 7, 7, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, 7, 15, 15, 21, 15, 15, 7, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, 7, 15, 20, 20, 20, 20, 20, 15, 17, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, 15, 20, 20, 20, 20, 20, 20, 20, 15, 15, 15, -1, -1, -1,
                -1, -1, -1, -1, 15, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 15, -1, -1,
                -1, -1, -1, 15, 21, 20, 20, 20, 20, 20, 20, 20, 20, 21, 20, 15, -1, -1,
                -1, -1, 5, 21, 20, 20, 20, 20, 20, 21, 21, 20, 20, 20, 21, 15, -1, -1,
                -1, -1, 15, 20, 20, 20, 20, 20, 21, 3, 3, 3, 21, 21, 15, -1, -1, -1,
                -1, -1, 17, 21, 20, 20, 20, 21, 21, 3, 3, 3, 3, 6, -1, -1, -1, -1,
                -1, -1, -1, 17, 5, 15, 5, 28, 30, 30, 30, 30, 30, 7, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, 17, -1, 7, 17, 7, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, 7, 16, 17, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 17, 17, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 7, 7, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, 17, 7, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
            ]
            return DrawingTemplate(id: "tree", name: "Tree", width: width, height: height, colors: colors)
        }

}
