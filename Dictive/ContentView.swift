//
//  ContentView.swift
//  Tap Game
//
//  Created by Ido Frizler on 21/02/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var game = TapGame()
    @State private var feedback = "Pick a color and pop matching bubbles!"

    private let palette: [Color] = [.pink, .blue, .green, .orange, .purple, .yellow]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Magic Bubble Coloring").font(.largeTitle).bold()
                Text("Score \(game.score)  •  Streak \(game.streak)")
                    .font(.headline)
                ProgressView(value: game.completion).tint(.mint)
                Text("\(game.paintedCount)/\(game.totalCount) bubbles done")
                    .font(.subheadline)
                Text(feedback)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(Array(palette.enumerated()), id: \.offset) { index, color in
                        Button {
                            game.selectColor(index)
                            feedback = "Color \(index + 1) selected."
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 42, height: 42)
                                    .overlay {
                                        if game.selectedColorIndex == index {
                                            Circle().stroke(.white, lineWidth: 3)
                                        }
                                    }
                                Text("\(game.remainingCount(for: index))")
                                    .font(.caption2)
                            }
                        }
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(game.cells) { cell in
                        Button {
                            let result = game.tapCell(cell.id)
                            switch result {
                            case .match:
                                feedback = "Nice! Keep going!"
                            case .mismatch:
                                feedback = "Try a different color for this bubble."
                            case .alreadyPainted:
                                feedback = "That bubble is already done."
                            }
                        } label: {
                            Circle()
                                .fill(cell.isPainted ? palette[cell.targetColorIndex] : .white.opacity(0.92))
                                .frame(height: 54)
                                .overlay {
                                    if !cell.isPainted {
                                        Text("\(cell.targetColorIndex + 1)")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if game.isCompleted {
                    Text("Board complete!").font(.title2).bold()
                    Button("New Board") {
                        game.newBoard()
                        feedback = "New board ready!"
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .background(
            LinearGradient(colors: [.mint.opacity(0.2), .cyan.opacity(0.25)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

#Preview {
    ContentView()
}
