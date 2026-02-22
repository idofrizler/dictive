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
    static let persistenceVersion = 2

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

        var paintedCount: Int { cells.filter(\.isPainted).count }
        var completion: Double { Double(paintedCount) / Double(cells.count) }
        var isCompleted: Bool { paintedCount == cells.count }
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
    var totalCount: Int { currentDrawing?.cells.count ?? 0 }
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
            let normalizedColors = template.colors.map { $0 % max(1, paletteCount) }
            return DrawingState(
                template: template,
                cells: normalizedColors.map { BubbleCell(targetColorIndex: $0) }
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
            drawings[drawingIndex].cells[idx].isPainted = false
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

// Used palette indexes: 2:green, 3:orange, 4:purple, 5:yellow, 6:red, 7:teal
private static func makeSmiley() -> DrawingTemplate {
            let width = 15
            let height = 15
            let colors = [
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 4, 4, 4, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 4, 3, 5, 5, 5, 3, 4, 7, 7, 7, 7,
                7, 7, 7, 4, 3, 5, 5, 5, 5, 5, 3, 4, 7, 7, 7,
                7, 7, 7, 3, 5, 3, 3, 5, 3, 3, 5, 3, 7, 7, 7,
                7, 7, 4, 5, 5, 2, 2, 5, 2, 2, 5, 5, 4, 7, 7,
                7, 7, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 7, 7,
                7, 7, 4, 5, 3, 5, 5, 5, 5, 5, 3, 5, 4, 7, 7,
                7, 7, 7, 3, 2, 2, 2, 2, 2, 2, 2, 3, 7, 7, 7,
                7, 7, 7, 4, 3, 6, 6, 6, 6, 6, 3, 4, 7, 7, 7,
                7, 7, 7, 7, 4, 3, 3, 3, 3, 3, 4, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 4, 4, 4, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
            ]
            return DrawingTemplate(id: "smiley", name: "Smiley", width: width, height: height, colors: colors)
        }

// Used palette indexes: 0:pink, 2:green, 3:orange, 4:purple, 5:yellow, 6:red, 7:teal
private static func makeRocket() -> DrawingTemplate {
            let width = 15
            let height = 15
            let colors = [
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 4, 4, 0, 4, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 6, 6, 0, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 6, 6, 4, 7, 6, 4, 7, 7,
                7, 7, 7, 7, 7, 7, 6, 6, 6, 4, 4, 6, 4, 7, 7,
                7, 7, 7, 7, 2, 2, 6, 6, 6, 6, 6, 6, 7, 7, 7,
                7, 7, 4, 2, 7, 2, 6, 2, 6, 6, 6, 7, 7, 7, 7,
                7, 7, 7, 4, 2, 2, 2, 6, 6, 6, 7, 7, 7, 7, 7,
                7, 7, 7, 4, 2, 2, 2, 2, 2, 7, 7, 7, 7, 7, 7,
                7, 7, 4, 3, 5, 3, 2, 7, 2, 7, 7, 7, 7, 7, 7,
                7, 7, 2, 5, 3, 4, 4, 2, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 4, 2, 4, 7, 7, 4, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
            ]
            return DrawingTemplate(id: "rocket", name: "Rocket", width: width, height: height, colors: colors)
        }

// Used palette indexes: 2:green, 4:purple, 6:red, 7:teal
private static func makeHeart() -> DrawingTemplate {
            let width = 15
            let height = 15
            let colors = [
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 4, 4, 4, 7, 4, 4, 4, 7, 7, 7, 7,
                7, 7, 7, 6, 6, 6, 6, 2, 6, 6, 6, 6, 7, 7, 7,
                7, 7, 4, 6, 6, 6, 6, 6, 6, 6, 6, 6, 4, 7, 7,
                7, 7, 4, 6, 6, 6, 6, 6, 6, 6, 6, 6, 4, 7, 7,
                7, 7, 4, 6, 6, 6, 6, 6, 6, 6, 6, 6, 4, 7, 7,
                7, 7, 7, 4, 6, 6, 6, 6, 6, 6, 6, 4, 7, 7, 7,
                7, 7, 7, 7, 2, 6, 6, 6, 6, 6, 2, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 6, 6, 6, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 4, 6, 4, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
            ]
            return DrawingTemplate(id: "heart", name: "Heart", width: width, height: height, colors: colors)
        }

// Used palette indexes: 2:green, 3:orange, 4:purple, 5:yellow, 7:teal
private static func makeStar() -> DrawingTemplate {
            let width = 15
            let height = 15
            let colors = [
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 2, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 4, 3, 4, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 2, 5, 2, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 4, 2, 5, 5, 5, 2, 4, 7, 7, 7, 7,
                7, 7, 2, 3, 5, 5, 5, 5, 5, 5, 5, 3, 2, 7, 7,
                7, 7, 7, 3, 5, 5, 5, 5, 5, 5, 5, 3, 7, 7, 7,
                7, 7, 7, 7, 2, 5, 5, 5, 5, 5, 2, 7, 7, 7, 7,
                7, 7, 7, 7, 2, 5, 5, 5, 5, 5, 2, 7, 7, 7, 7,
                7, 7, 7, 7, 2, 5, 5, 5, 5, 5, 2, 7, 7, 7, 7,
                7, 7, 7, 7, 3, 5, 2, 4, 2, 5, 3, 7, 7, 7, 7,
                7, 7, 7, 7, 2, 4, 7, 7, 7, 4, 2, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
            ]
            return DrawingTemplate(id: "star", name: "Star", width: width, height: height, colors: colors)
        }

// Used palette indexes: 0:pink, 2:green, 4:purple, 7:teal
private static func makeFlower() -> DrawingTemplate {
            let width = 15
            let height = 15
            let colors = [
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 2, 4, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 4, 4, 4, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 4, 4, 2, 4, 4, 2, 4, 4, 7, 7, 7,
                7, 7, 7, 7, 2, 4, 4, 2, 2, 4, 4, 2, 7, 7, 7,
                7, 7, 7, 2, 4, 2, 4, 2, 0, 4, 2, 7, 7, 7, 7,
                7, 7, 4, 2, 2, 2, 4, 4, 4, 4, 4, 7, 7, 7, 7,
                7, 7, 7, 2, 2, 4, 4, 2, 2, 4, 0, 7, 7, 7, 7,
                7, 7, 7, 4, 2, 2, 4, 4, 7, 4, 4, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 4, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 4, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 4, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 4, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
            ]
            return DrawingTemplate(id: "flower", name: "Flower", width: width, height: height, colors: colors)
        }

// Used palette indexes: 2:green, 4:purple, 7:teal
private static func makeFish() -> DrawingTemplate {
            let width = 15
            let height = 15
            let colors = [
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 2, 7, 2, 7, 7, 7, 7, 7,
                7, 7, 4, 2, 4, 7, 4, 2, 7, 7, 2, 4, 7, 7, 7,
                7, 7, 2, 7, 2, 4, 2, 7, 7, 7, 7, 7, 2, 7, 7,
                7, 7, 4, 7, 7, 2, 7, 7, 2, 7, 7, 7, 7, 4, 7,
                7, 7, 4, 2, 7, 7, 7, 7, 7, 7, 7, 7, 2, 4, 7,
                7, 7, 2, 7, 7, 2, 7, 7, 7, 7, 7, 7, 2, 7, 7,
                7, 7, 2, 7, 2, 7, 4, 2, 7, 7, 7, 2, 4, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 2, 7, 2, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 4, 4, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
            ]
            return DrawingTemplate(id: "fish", name: "Fish", width: width, height: height, colors: colors)
        }

// Used palette indexes: 2:green, 4:purple, 6:red, 7:teal
private static func makeHouse() -> DrawingTemplate {
            let width = 15
            let height = 15
            let colors = [
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 2, 2, 6, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 4, 6, 6, 6, 6, 6, 4, 7, 7, 7, 7,
                7, 7, 7, 7, 2, 6, 6, 6, 6, 6, 2, 7, 7, 7, 7,
                7, 7, 7, 4, 7, 7, 7, 7, 7, 7, 7, 4, 7, 7, 7,
                7, 7, 7, 4, 4, 2, 2, 4, 4, 2, 4, 7, 7, 7, 7,
                7, 7, 7, 4, 4, 2, 6, 4, 2, 2, 4, 7, 7, 7, 7,
                7, 7, 7, 4, 4, 2, 6, 4, 7, 7, 7, 4, 7, 7, 7,
                7, 7, 7, 7, 2, 2, 2, 2, 4, 4, 2, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
            ]
            return DrawingTemplate(id: "house", name: "House", width: width, height: height, colors: colors)
        }

// Used palette indexes: 2:green, 3:orange, 4:purple, 5:yellow, 7:teal
private static func makeTree() -> DrawingTemplate {
            let width = 15
            let height = 15
            let colors = [
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 4, 4, 2, 4, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 2, 2, 5, 5, 2, 2, 7, 7, 7, 7, 7,
                7, 7, 7, 4, 2, 5, 5, 5, 5, 5, 2, 2, 4, 7, 7,
                7, 7, 7, 2, 5, 5, 5, 5, 5, 5, 5, 5, 2, 7, 7,
                7, 7, 4, 2, 5, 5, 5, 5, 5, 5, 5, 5, 3, 4, 7,
                7, 7, 2, 5, 5, 5, 5, 5, 2, 2, 5, 5, 2, 7, 7,
                7, 7, 2, 5, 5, 5, 5, 2, 2, 2, 2, 2, 7, 7, 7,
                7, 7, 4, 2, 2, 2, 2, 2, 2, 2, 2, 4, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 4, 4, 2, 4, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 4, 2, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 4, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 4, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
                7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
            ]
            return DrawingTemplate(id: "tree", name: "Tree", width: width, height: height, colors: colors)
        }

}
