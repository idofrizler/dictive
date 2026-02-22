import SwiftUI
import Combine

struct NumberSprintGameView: View {
    @StateObject private var session = NumberSprintSession()
    private let gameGradient = LinearGradient(
        colors: [Color(red: 0.08, green: 0.10, blue: 0.23), Color(red: 0.18, green: 0.27, blue: 0.56), Color(red: 0.28, green: 0.64, blue: 0.71)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Number Trail")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.white)

                Text("Chain adjacent numbers to hit the target exactly.")
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                hudView

                Text(session.feedback)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if session.game.isAwaitingNextLevel {
                    levelClearedView
                }

                boardView

                controlsView

                if session.game.roundState != .inProgress {
                    VStack(spacing: 8) {
                        Text(session.game.roundState == .won ? "You Win! 🎯" : "Round Over")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Score: \(session.game.score) • Level: \(session.game.currentLevel)")
                            .foregroundStyle(.white.opacity(0.9))
                        Button("Play Again") {
                            session.reset()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
        }
        .background(gameGradient.ignoresSafeArea())
        .navigationTitle("Number Trail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hudView: some View {
        VStack(spacing: 8) {
            Text("Target \(session.game.targetSum)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Trail \(session.game.currentSum) • \(session.game.hits) out of \(session.game.requiredHits) • L\(session.game.currentLevel)")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            HStack(spacing: 8) {
                statPill("Mistakes \(session.game.movesRemaining)")
                statPill("Score \(session.game.score)")
                if session.game.combo > 1 {
                    statPill("x\(session.game.combo)")
                }
            }

        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
    }

    private func statPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private var boardView: some View {
        GeometryReader { proxy in
            let boardSize = min(proxy.size.width, 332)
            let cellSize = boardSize / CGFloat(session.game.gridWidth)
            let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: session.game.gridWidth)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(session.game.tiles) { tile in
                    Button {
                        let result = session.game.tapTile(tile.id)
                        switch result {
                        case .started(let sum), .extended(let sum):
                            session.feedback = "Trail sum: \(sum) / \(session.game.targetSum)"
                        case .backtracked(let sum):
                            session.feedback = "Backtracked. Trail sum \(sum)."
                        case .invalidMove:
                            session.feedback = "Pick a neighboring tile or tap the last tile to undo."
                        case .waitingForNextLevel:
                            session.feedback = "Nice clear. Tap Next Level when ready."
                        case .levelCleared(let points, let nextLevel):
                            session.feedback = "Level clear! +\(points) points. Ready for level \(nextLevel)."
                        case .bust(let target):
                            session.feedback = "Bust. You went over \(target)."
                        case .wonRound:
                            session.feedback = "Excellent route planning. You cleared the round!"
                        case .lostRound:
                            session.feedback = "Out of moves. Try a different path strategy."
                        case .ignored:
                            break
                        }
                    } label: {
                        ZStack {
                            Rectangle()
                                .fill(tileBackground(tile.id))
                            Text("\(tile.value)")
                                .font(.title3.bold())
                                .foregroundStyle(.black)
                        }
                        .frame(width: cellSize, height: cellSize)
                        .overlay(Rectangle().stroke(.black.opacity(0.22), lineWidth: 0.5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(session.game.roundState != .inProgress || session.game.isAwaitingNextLevel)
                }
            }
            .frame(width: boardSize, height: boardSize)
            .background(.white.opacity(0.2))
            .clipShape(Rectangle())
            .frame(maxWidth: .infinity)
        }
        .frame(height: 332)
    }

    private var controlsView: some View {
        VStack(spacing: 10) {
            if session.game.isAwaitingNextLevel {
                Button("Next Level") {
                    if session.game.advanceToNextLevel() {
                        session.feedback = "Level \(session.game.currentLevel). New target: \(session.game.targetSum)."
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                Button("Hint") {
                    if let _ = session.game.revealHint() {
                        session.feedback = "Hint revealed: follow the highlighted next tile."
                    } else {
                        session.feedback = "No hint available right now."
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(session.game.roundState != .inProgress || session.game.isAwaitingNextLevel)

                Button("Clear Path") {
                    session.game.clearPath()
                    session.feedback = "Path cleared. Try a new route."
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(session.game.selectedTileIDs.isEmpty || session.game.roundState != .inProgress || session.game.isAwaitingNextLevel)

                Button("Reset") {
                    session.reset()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var levelClearedView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Level Cleared")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Trail locked in. Press Next Level when ready.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Text("L\(session.game.currentLevel + 1)")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.2), in: Capsule())
        }
        .padding(12)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
    }

    private func tileBackground(_ id: UUID) -> Color {
        if session.game.hintedTileID == id {
            return Color(red: 0.55, green: 0.80, blue: 1.0)
        }
        if session.game.selectedTileIDSet.contains(id) {
            return Color(red: 0.98, green: 0.86, blue: 0.38)
        }
        return .white.opacity(0.9)
    }
}

final class NumberSprintSession: ObservableObject {
    @Published var game: NumberSprintGame {
        didSet { persist() }
    }
    @Published var feedback: String {
        didSet { persist() }
    }

    private let gameKey = "dictive.numbersprint.state"
    private let feedbackKey = "dictive.numbersprint.feedback"
    private let stateVersionKey = "dictive.numbersprint.stateVersion"

    init() {
        let defaults = UserDefaults.standard
        let savedVersion = defaults.integer(forKey: stateVersionKey)
        if savedVersion == NumberSprintGame.persistenceVersion,
           let data = defaults.data(forKey: gameKey),
           let decoded = try? JSONDecoder().decode(NumberSprintGame.self, from: data) {
            game = decoded
        } else {
            game = Self.makeGame()
            defaults.set(NumberSprintGame.persistenceVersion, forKey: stateVersionKey)
        }
        feedback = defaults.string(forKey: feedbackKey) ?? "Hit the target sum by chaining adjacent tiles."
    }

    func reset() {
        game = Self.makeGame()
        feedback = "Fresh board loaded. Find your first route."
    }

    private static func makeGame() -> NumberSprintGame {
        NumberSprintGame(
            gridWidth: 5,
            gridHeight: 5,
            maxMoves: 18,
            requiredHits: 8,
            seed: UInt64.random(in: 1...UInt64.max)
        )
    }

    private func persist() {
        let defaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(game) {
            defaults.set(encoded, forKey: gameKey)
        }
        defaults.set(NumberSprintGame.persistenceVersion, forKey: stateVersionKey)
        defaults.set(feedback, forKey: feedbackKey)
    }
}

#Preview {
    NavigationStack {
        NumberSprintGameView()
    }
}
