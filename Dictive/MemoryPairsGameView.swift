import SwiftUI
import Combine

struct MemoryPairsGameView: View {
    @StateObject private var session = MemoryPairsSession()

    private let gameGradient = LinearGradient(
        colors: [Color(red: 0.08, green: 0.12, blue: 0.28), Color(red: 0.16, green: 0.30, blue: 0.52), Color(red: 0.37, green: 0.72, blue: 0.86)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Animal Memory Match")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.white)

                Text("Flip two cards to find matching icon friends.")
                    .foregroundStyle(.white.opacity(0.84))
                    .multilineTextAlignment(.center)

                Picker("Board Size", selection: $session.boardSize) {
                    ForEach(MemoryBoardSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 8) {
                    ProgressView(value: session.game.completion)
                        .tint(.mint)
                    Text("Pairs found: \(session.game.matchCount)/\(session.game.totalPairs) • Moves: \(session.game.moveCount)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.86))
                }

                Text(session.feedback)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: session.boardColumns, spacing: 12) {
                    ForEach(session.game.cards) { card in
                        Button {
                            let result = session.game.tapCard(card.id)
                            switch result {
                            case .firstReveal:
                                session.feedback = "Nice pick! Find its matching card."
                            case .match:
                                session.feedback = "Great match!"
                            case .mismatch:
                                session.feedback = "Almost! Keep trying."
                            case .ignored:
                                break
                            }
                        } label: {
                            MemoryCardView(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))

                if session.game.isCompleted {
                    VStack(spacing: 8) {
                        Text("You matched all the cards! 🎉")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Button("Play Again") {
                            session.reset()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(gameGradient.ignoresSafeArea())
        .navigationTitle("Memory Match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    session.reset()
                }
                .foregroundStyle(.white)
            }
        }
    }
}

private struct MemoryCardView: View {
    let card: MemoryCard

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(cardFill)
            .frame(height: 96)
            .overlay {
                if card.isFaceUp || card.isMatched {
                    Text(card.symbol)
                        .font(.system(size: 40))
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            }
    }

    private var cardFill: Color {
        if card.isMatched {
            return Color(red: 0.50, green: 0.90, blue: 0.70).opacity(0.9)
        }
        if card.isFaceUp {
            return Color.white
        }
        return Color(red: 0.23, green: 0.39, blue: 0.78)
    }
}

final class MemoryPairsSession: ObservableObject {
    @Published var boardSize: MemoryBoardSize {
        didSet {
            if oldValue != boardSize {
                newGame()
            }
            persist()
        }
    }
    @Published var game: MemoryPairsGame {
        didSet { persist() }
    }
    @Published var feedback: String {
        didSet { persist() }
    }

    private let gameKey = "dictive.memorypairs.state"
    private let feedbackKey = "dictive.memorypairs.feedback"
    private let boardSizeKey = "dictive.memorypairs.boardSize"
    private let stateVersionKey = "dictive.memorypairs.stateVersion"

    init() {
        let defaults = UserDefaults.standard
        let initialBoardSize = MemoryBoardSize(rawValue: defaults.string(forKey: boardSizeKey) ?? "") ?? .medium
        boardSize = initialBoardSize
        let savedVersion = defaults.integer(forKey: stateVersionKey)
        if savedVersion == MemoryPairsGame.persistenceVersion,
           let data = defaults.data(forKey: gameKey),
           let decoded = try? JSONDecoder().decode(MemoryPairsGame.self, from: data) {
            game = decoded
        } else {
            game = Self.makeGame(pairCount: initialBoardSize.pairCount)
            defaults.set(MemoryPairsGame.persistenceVersion, forKey: stateVersionKey)
        }
        feedback = defaults.string(forKey: feedbackKey) ?? "Tap a card to begin."
    }

    var boardColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 72, maximum: 100), spacing: 12), count: boardSize.columnCount)
    }

    func reset() {
        newGame()
        feedback = "Fresh cards ready. Have fun!"
    }

    private func newGame() {
        game = Self.makeGame(pairCount: boardSize.pairCount)
    }

    private static func makeGame(pairCount: Int) -> MemoryPairsGame {
        MemoryPairsGame(
            pairCount: pairCount,
            symbols: MemoryPairsGame.defaultSymbols,
            selectionSeed: UInt64.random(in: 1...UInt64.max),
            shuffleSeed: UInt64.random(in: 1...UInt64.max)
        )
    }

    private func persist() {
        let defaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(game) {
            defaults.set(encoded, forKey: gameKey)
        }
        defaults.set(MemoryPairsGame.persistenceVersion, forKey: stateVersionKey)
        defaults.set(feedback, forKey: feedbackKey)
        defaults.set(boardSize.rawValue, forKey: boardSizeKey)
    }
}

enum MemoryBoardSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var pairCount: Int {
        (columnCount * rowCount) / 2
    }

    var rowCount: Int {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 6
        }
    }

    var columnCount: Int {
        switch self {
        case .small: return 3
        case .medium: return 4
        case .large: return 6
        }
    }

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

#Preview {
    NavigationStack {
        MemoryPairsGameView()
    }
}
