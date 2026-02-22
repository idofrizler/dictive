//
//  ContentView.swift
//  Dictive
//
//  Created by Ido Frizler on 21/02/2026.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var session = TapGameSession()
    private let portalGradient = LinearGradient(
        colors: [Color(red: 0.11, green: 0.10, blue: 0.22), Color(red: 0.28, green: 0.16, blue: 0.40), Color(red: 0.93, green: 0.42, blue: 0.36)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Game Portal")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.white)
                    Text("Dictive")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.white)
                    Text("Play ad-free mini-games in a polished portal experience.")
                        .foregroundStyle(.white.opacity(0.82))

                    VStack(spacing: 12) {
                        NavigationLink {
                            BubbleColoringGameView(session: session)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "paintpalette.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Magic Bubble Coloring")
                                        .font(.title3)
                                        .bold()
                                        .foregroundStyle(.white)
                                    Text("Choose a drawing, then color by tap or drag to reveal it.")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.82))
                                }
                                Spacer()
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            MemoryPairsGameView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Animal Memory Match")
                                        .font(.title3)
                                        .bold()
                                        .foregroundStyle(.white)
                                    Text("Flip cards to find pairs in a calm, kid-friendly memory game.")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.82))
                                }
                                Spacer()
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(portalGradient.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .tint(.white)
        }
    }
}

private struct BubbleColoringGameView: View {
    enum GalleryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case inProgress = "In Progress"
        case notStarted = "Not Started"
        case completed = "Completed"

        var id: String { rawValue }
    }

    @ObservedObject var session: TapGameSession
    @State private var lastDragCellID: UUID?
    @State private var galleryFilter: GalleryFilter = .all

    private let paletteColumns = [GridItem(.adaptive(minimum: 68, maximum: 82), spacing: 12)]
    private let gameGradient = LinearGradient(
        colors: [Color(red: 0.09, green: 0.11, blue: 0.20), Color(red: 0.15, green: 0.24, blue: 0.36), Color(red: 0.80, green: 0.33, blue: 0.49)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if session.game.currentDrawingID == nil {
                    gallerySection
                } else {
                    drawingSection
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(gameGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(session.game.currentDrawingID != nil)
        .toolbar {
            if session.game.currentDrawingID != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        session.game.leaveDrawing()
                        session.feedback = "Pick another drawing."
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        session.game.resetCurrentDrawing()
                        session.feedback = "Drawing reset. Start coloring again!"
                    }
                }
            }
        }
    }

    private var gallerySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Magic Bubble Coloring")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)
            Text("Pick a drawing. In-progress drawings keep your painted pixels.")
                .foregroundStyle(.white.opacity(0.82))

            HStack {
                Text("Gallery")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Menu {
                    ForEach(GalleryFilter.allCases) { filter in
                        Button(filter.rawValue) {
                            galleryFilter = filter
                        }
                    }
                } label: {
                    Label(galleryFilter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.white)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 156, maximum: 220), spacing: 12)], spacing: 12) {
                ForEach(filteredGalleryItems) { item in
                    Button {
                        session.game.selectDrawing(item.id)
                        session.feedback = "Drawing loaded: \(item.name)."
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            PixelThumbnailView(
                                cells: item.cells,
                                width: item.width,
                                height: item.height,
                                palette: thumbnailPalette(for: item)
                            )
                            .frame(height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            Text(item.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(Int(item.completion * 100))% complete")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.isCompleted ? "Completed" : (item.isInProgress ? "In progress" : "Not started"))
                                .font(.caption2.bold())
                                .foregroundStyle(item.isCompleted ? .green : (item.isInProgress ? .blue : .clear))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var drawingSection: some View {
        VStack(spacing: 14) {
            Text(session.game.currentDrawingName)
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                ProgressView(value: session.game.completion)
                    .tint(.mint)
                Text("\(session.game.paintedCount)/\(session.game.totalCount)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.88))
            }

            Text(session.feedback)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            LazyVGrid(columns: paletteColumns, spacing: 12) {
                ForEach(sortedAvailableColorIndices, id: \.self) { index in
                    let color = colorForIndex(index)
                    Button {
                        session.game.selectColor(index)
                        session.feedback = "Color \(index + 1) selected."
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(color)
                                .frame(width: 42, height: 42)
                                .overlay {
                                    if session.game.selectedColorIndex == index {
                                        Circle().stroke(.white, lineWidth: 4)
                                        Circle().stroke(.black.opacity(0.22), lineWidth: 1)
                                    }
                                }
                            Text("\(session.game.remainingCount(for: index)) left")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.white.opacity(session.game.selectedColorIndex == index ? 0.95 : 0.72), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            boardView
                .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))

            if session.game.isCompleted {
                Text("Finished: \(session.game.currentDrawingName)!")
                    .font(.title3)
                    .bold()
            }
        }
    }

    private var filteredGalleryItems: [DrawingGalleryItem] {
        switch galleryFilter {
        case .all:
            return session.game.galleryItems
        case .inProgress:
            return session.game.galleryItems.filter(\.isInProgress)
        case .notStarted:
            return session.game.galleryItems.filter { $0.completion == 0 }
        case .completed:
            return session.game.galleryItems.filter(\.isCompleted)
        }
    }

    private var sortedAvailableColorIndices: [Int] {
        session.game.availableColorIndices.sorted()
    }

    private func colorForIndex(_ index: Int) -> Color {
        colorForIndex(index, drawingID: session.game.currentDrawingID)
    }

    private func colorForIndex(_ index: Int, drawingID: String?) -> Color {
        paletteMap(for: drawingID)[index] ?? defaultPaletteColor(index)
    }

    private func thumbnailPalette(for item: DrawingGalleryItem) -> [Color] {
        let indices = Array(Set(item.cells.map(\.targetColorIndex).filter { $0 >= 0 })).sorted()
        let maxIndex = max(indices.max() ?? 0, 0)
        var palette = Array(repeating: rgb(210, 210, 210), count: maxIndex + 1)
        for index in indices {
            palette[index] = colorForIndex(index, drawingID: item.id)
        }
        return palette
    }

    private func defaultPaletteColor(_ index: Int) -> Color {
        let colors: [Color] = [
            rgb(230, 57, 70), rgb(244, 162, 97), rgb(233, 196, 106), rgb(76, 175, 80),
            rgb(42, 157, 143), rgb(141, 110, 99), rgb(47, 47, 47), rgb(176, 190, 197),
            rgb(33, 150, 243), rgb(63, 81, 181), rgb(156, 39, 176), rgb(233, 30, 99),
            rgb(255, 112, 67), rgb(255, 235, 59), rgb(0, 150, 136), rgb(121, 85, 72),
            rgb(96, 125, 139), rgb(158, 158, 158), rgb(69, 90, 100), rgb(255, 87, 34),
            rgb(205, 220, 57), rgb(139, 195, 74), rgb(0, 188, 212), rgb(3, 169, 244),
            rgb(103, 58, 183), rgb(255, 64, 129), rgb(255, 152, 0), rgb(250, 250, 250),
            rgb(84, 110, 122), rgb(255, 167, 192), rgb(66, 66, 66), rgb(0, 0, 0)
        ]
        guard colors.indices.contains(index) else { return rgb(210, 210, 210) }
        return colors[index]
    }

    private func paletteMap(for drawingID: String?) -> [Int: Color] {
        switch drawingID {
        case "smiley":
            return [
                2: rgb(252, 252, 252),
                3: rgb(250, 168, 37),
                4: rgb(20, 20, 20),
                5: rgb(250, 230, 45),
                6: rgb(238, 88, 66),
                7: rgb(251, 251, 252)
            ]
        case "rocket":
            return [
                0: rgb(255, 105, 180),
                2: rgb(122, 181, 164),
                3: rgb(243, 194, 66),
                4: rgb(34, 34, 34),
                5: rgb(255, 233, 64),
                6: rgb(222, 88, 72),
                7: rgb(249, 250, 251)
            ]
        case "heart":
            return [
                2: rgb(255, 237, 239),
                4: rgb(158, 45, 60),
                6: rgb(232, 86, 72),
                7: rgb(252, 252, 252)
            ]
        case "star":
            return [
                2: rgb(255, 244, 176),
                3: rgb(247, 197, 67),
                4: rgb(34, 34, 34),
                5: rgb(248, 224, 56),
                7: rgb(250, 250, 251)
            ]
        case "flower":
            return [
                0: rgb(242, 108, 167),
                2: rgb(120, 168, 87),
                4: rgb(194, 98, 171),
                7: rgb(252, 252, 252)
            ]
        case "fish":
            return [
                2: rgb(69, 163, 205),
                4: rgb(35, 35, 35),
                7: rgb(228, 241, 246)
            ]
        case "house":
            return [
                2: rgb(145, 97, 66),
                4: rgb(78, 78, 82),
                6: rgb(209, 84, 64),
                7: rgb(249, 250, 250)
            ]
        case "tree":
            return [
                2: rgb(95, 140, 55),
                3: rgb(138, 167, 37),
                4: rgb(122, 82, 52),
                5: rgb(170, 201, 58),
                7: rgb(251, 251, 251)
            ]
        default:
            return [:]
        }
    }

    private var boardView: some View {
        GeometryReader { proxy in
            let boardWidth = proxy.size.width
            let width = max(1, session.game.currentGridWidth)
            let height = max(1, session.game.currentGridHeight)
            let cellSize = boardWidth / CGFloat(width)
            let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: width)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(session.game.cells) { cell in
                    Rectangle()
                        .fill(cellFill(for: cell))
                        .frame(width: cellSize, height: cellSize)
                        .overlay {
                            if !cell.isPainted && cell.targetColorIndex >= 0 {
                                Text("\(cell.targetColorIndex + 1)")
                                    .font(.system(size: max(7, cellSize * 0.25), weight: .semibold))
                                    .foregroundStyle(cell.targetColorIndex == session.game.selectedColorIndex ? .primary : .secondary)
                            }
                        }
                        .overlay {
                            Rectangle()
                                .stroke(.black.opacity(0.08), lineWidth: 0.5)
                        }
                }
            }
            .frame(width: boardWidth, height: cellSize * CGFloat(height), alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handlePaint(at: value.location, boardWidth: boardWidth, cellSize: cellSize)
                    }
                    .onEnded { _ in
                        lastDragCellID = nil
                    }
            )
        }
        .aspectRatio(CGFloat(max(1, session.game.currentGridWidth)) / CGFloat(max(1, session.game.currentGridHeight)), contentMode: .fit)
    }

    private func cellFill(for cell: BubbleCell) -> Color {
        if cell.targetColorIndex < 0 {
            return .white.opacity(0.94)
        }
        if cell.isPainted {
            return colorForIndex(cell.targetColorIndex)
        }

        if cell.targetColorIndex == session.game.selectedColorIndex {
            return colorForIndex(cell.targetColorIndex).opacity(0.24)
        }

        return .white.opacity(0.94)
    }

    private func handlePaint(at location: CGPoint, boardWidth: CGFloat, cellSize: CGFloat) {
        let width = session.game.currentGridWidth
        let height = session.game.currentGridHeight
        guard width > 0, height > 0, boardWidth > 0, cellSize > 0 else { return }

        let col = Int(location.x / cellSize)
        let row = Int(location.y / cellSize)
        let index = row * width + col

        guard col >= 0, col < width, row >= 0, row < height, index < session.game.cells.count else { return }

        let cellID = session.game.cells[index].id
        guard lastDragCellID != cellID else { return }
        lastDragCellID = cellID

        let result = session.game.tapCell(cellID)
        switch result {
        case .match:
            session.feedback = "Nice! Keep going!"
        case .mismatch:
            session.feedback = "Try the highlighted color targets."
        case .alreadyPainted:
            break
        }
    }

}

final class TapGameSession: ObservableObject {
    @Published var game: TapGame {
        didSet { persist() }
    }
    @Published var feedback: String {
        didSet { persist() }
    }

    private let gameKey = "dictive.tapgame.state"
    private let feedbackKey = "dictive.tapgame.feedback"
    private let stateVersionKey = "dictive.tapgame.stateVersion"

    init() {
        let defaults = UserDefaults.standard
        let savedVersion = defaults.integer(forKey: stateVersionKey)
        if savedVersion == TapGame.persistenceVersion,
           let data = defaults.data(forKey: gameKey),
           let decoded = try? JSONDecoder().decode(TapGame.self, from: data) {
            game = decoded
        } else {
            game = TapGame()
            defaults.set(TapGame.persistenceVersion, forKey: stateVersionKey)
        }
        feedback = defaults.string(forKey: feedbackKey) ?? "Pick a drawing from the gallery."
    }

    private func persist() {
        let defaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(game) {
            defaults.set(encoded, forKey: gameKey)
        }
        defaults.set(TapGame.persistenceVersion, forKey: stateVersionKey)
        defaults.set(feedback, forKey: feedbackKey)
    }
}

private struct PixelThumbnailView: View {
    let cells: [BubbleCell]
    let width: Int
    let height: Int
    let palette: [Color]

    var body: some View {
        GeometryReader { proxy in
            let cellSize = min(proxy.size.width / CGFloat(max(1, width)), proxy.size.height / CGFloat(max(1, height)))
            let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: max(1, width))

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(cells) { cell in
                    Rectangle()
                        .fill(cell.isPainted && cell.targetColorIndex >= 0 ? palette[cell.targetColorIndex] : Color.white.opacity(0.85))
                        .frame(width: cellSize, height: cellSize)
                }
            }
        }
    }
}

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
    Color(red: r / 255.0, green: g / 255.0, blue: b / 255.0)
}

#Preview {
    ContentView()
}
