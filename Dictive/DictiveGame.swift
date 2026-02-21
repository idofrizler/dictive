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

    init(paletteCount: Int = 8) {
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

    private static func makeCanvas(width: Int, height: Int, fill: Int) -> [Int] {
        Array(repeating: fill, count: width * height)
    }

    private static func setPixel(_ colors: inout [Int], width: Int, height: Int, x: Int, y: Int, color: Int) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        colors[(y * width) + x] = color
    }

    private static func fillRect(_ colors: inout [Int], width: Int, height: Int, xRange: ClosedRange<Int>, yRange: ClosedRange<Int>, color: Int) {
        for y in yRange {
            for x in xRange {
                setPixel(&colors, width: width, height: height, x: x, y: y, color: color)
            }
        }
    }

    private static func fillCircle(_ colors: inout [Int], width: Int, height: Int, centerX: Int, centerY: Int, radius: Int, color: Int) {
        let radiusSq = radius * radius
        for y in (centerY - radius)...(centerY + radius) {
            for x in (centerX - radius)...(centerX + radius) {
                let dx = x - centerX
                let dy = y - centerY
                if (dx * dx) + (dy * dy) <= radiusSq {
                    setPixel(&colors, width: width, height: height, x: x, y: y, color: color)
                }
            }
        }
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

    private static func makeSmiley() -> DrawingTemplate {
        let width = 15
        let height = 15
        var colors = makeCanvas(width: width, height: height, fill: 7)
        fillCircle(&colors, width: width, height: height, centerX: 7, centerY: 7, radius: 6, color: 3)
        fillCircle(&colors, width: width, height: height, centerX: 5, centerY: 5, radius: 1, color: 0)
        fillCircle(&colors, width: width, height: height, centerX: 9, centerY: 5, radius: 1, color: 0)
        fillRect(&colors, width: width, height: height, xRange: 4...10, yRange: 9...10, color: 6)
        fillRect(&colors, width: width, height: height, xRange: 5...9, yRange: 8...8, color: 3)

        return DrawingTemplate(id: "smiley", name: "Smiley", width: width, height: height, colors: colors)
    }

    private static func makeRocket() -> DrawingTemplate {
        let width = 15
        let height = 15
        var colors = makeCanvas(width: width, height: height, fill: 7)
        fillRect(&colors, width: width, height: height, xRange: 6...8, yRange: 3...11, color: 4)
        fillRect(&colors, width: width, height: height, xRange: 5...9, yRange: 4...9, color: 4)
        fillRect(&colors, width: width, height: height, xRange: 5...9, yRange: 10...11, color: 2)
        fillCircle(&colors, width: width, height: height, centerX: 7, centerY: 6, radius: 1, color: 0)
        fillRect(&colors, width: width, height: height, xRange: 4...5, yRange: 8...10, color: 1)
        fillRect(&colors, width: width, height: height, xRange: 9...10, yRange: 8...10, color: 1)
        fillRect(&colors, width: width, height: height, xRange: 6...8, yRange: 12...13, color: 6)

        return DrawingTemplate(id: "rocket", name: "Rocket", width: width, height: height, colors: colors)
    }

    private static func makeHeart() -> DrawingTemplate {
        let width = 15
        let height = 15
        var colors = makeCanvas(width: width, height: height, fill: 7)

        fillCircle(&colors, width: width, height: height, centerX: 5, centerY: 5, radius: 3, color: 0)
        fillCircle(&colors, width: width, height: height, centerX: 9, centerY: 5, radius: 3, color: 0)
        fillRect(&colors, width: width, height: height, xRange: 4...10, yRange: 6...8, color: 0)
        fillRect(&colors, width: width, height: height, xRange: 5...9, yRange: 9...10, color: 0)
        fillRect(&colors, width: width, height: height, xRange: 6...8, yRange: 11...11, color: 0)
        fillRect(&colors, width: width, height: height, xRange: 7...7, yRange: 12...12, color: 0)

        return DrawingTemplate(id: "heart", name: "Heart", width: width, height: height, colors: colors)
    }

    private static func makeStar() -> DrawingTemplate {
        let width = 15
        let height = 15
        var colors = makeCanvas(width: width, height: height, fill: 7)

        fillRect(&colors, width: width, height: height, xRange: 6...8, yRange: 3...11, color: 3)
        fillRect(&colors, width: width, height: height, xRange: 3...11, yRange: 6...8, color: 3)
        fillRect(&colors, width: width, height: height, xRange: 4...10, yRange: 4...10, color: 3)
        fillCircle(&colors, width: width, height: height, centerX: 7, centerY: 7, radius: 1, color: 6)

        return DrawingTemplate(id: "star", name: "Star", width: width, height: height, colors: colors)
    }

    private static func makeFlower() -> DrawingTemplate {
        let width = 15
        let height = 15
        var colors = makeCanvas(width: width, height: height, fill: 7)

        fillCircle(&colors, width: width, height: height, centerX: 7, centerY: 7, radius: 2, color: 3)
        fillCircle(&colors, width: width, height: height, centerX: 7, centerY: 3, radius: 2, color: 0)
        fillCircle(&colors, width: width, height: height, centerX: 11, centerY: 7, radius: 2, color: 6)
        fillCircle(&colors, width: width, height: height, centerX: 7, centerY: 11, radius: 2, color: 0)
        fillCircle(&colors, width: width, height: height, centerX: 3, centerY: 7, radius: 2, color: 6)
        fillRect(&colors, width: width, height: height, xRange: 7...7, yRange: 9...14, color: 2)

        return DrawingTemplate(id: "flower", name: "Flower", width: width, height: height, colors: colors)
    }

    private static func makeFish() -> DrawingTemplate {
        let width = 15
        let height = 15
        var colors = makeCanvas(width: width, height: height, fill: 7)

        fillRect(&colors, width: width, height: height, xRange: 4...10, yRange: 5...9, color: 6)
        fillCircle(&colors, width: width, height: height, centerX: 10, centerY: 7, radius: 2, color: 6)
        fillRect(&colors, width: width, height: height, xRange: 2...4, yRange: 6...8, color: 3)
        fillRect(&colors, width: width, height: height, xRange: 6...8, yRange: 4...4, color: 2)
        fillCircle(&colors, width: width, height: height, centerX: 11, centerY: 6, radius: 0, color: 0)

        return DrawingTemplate(id: "fish", name: "Fish", width: width, height: height, colors: colors)
    }

    private static func makeHouse() -> DrawingTemplate {
        let width = 15
        let height = 15
        var colors = makeCanvas(width: width, height: height, fill: 7)

        fillRect(&colors, width: width, height: height, xRange: 4...10, yRange: 6...12, color: 5)
        for y in 3...6 {
            fillRect(&colors, width: width, height: height, xRange: (7 - (y - 3))...(7 + (y - 3)), yRange: y...y, color: 0)
        }
        fillRect(&colors, width: width, height: height, xRange: 6...8, yRange: 9...12, color: 2)
        fillRect(&colors, width: width, height: height, xRange: 5...5, yRange: 8...8, color: 1)
        fillRect(&colors, width: width, height: height, xRange: 9...9, yRange: 8...8, color: 6)

        return DrawingTemplate(id: "house", name: "House", width: width, height: height, colors: colors)
    }

    private static func makeTree() -> DrawingTemplate {
        let width = 15
        let height = 15
        var colors = makeCanvas(width: width, height: height, fill: 7)

        fillRect(&colors, width: width, height: height, xRange: 6...8, yRange: 9...13, color: 1)
        fillCircle(&colors, width: width, height: height, centerX: 7, centerY: 6, radius: 4, color: 2)
        fillCircle(&colors, width: width, height: height, centerX: 5, centerY: 7, radius: 2, color: 6)
        fillCircle(&colors, width: width, height: height, centerX: 9, centerY: 7, radius: 2, color: 2)

        return DrawingTemplate(id: "tree", name: "Tree", width: width, height: height, colors: colors)
    }
}
