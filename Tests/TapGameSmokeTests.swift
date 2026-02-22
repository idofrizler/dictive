import Foundation

@main
struct TapGameSmokeTests {
    static func main() {
        testInitialGalleryState()
        testSelectDrawingAndGridSize()
        testOnlyUsedColorsAreExposed()
        testTransparentPixelsAreNotPaintable()
        testMatchAndMismatchScoring()
        testProgressPersistsAcrossGalleryNavigation()
        testColorSelectionResetsBetweenDrawings()
        testEraseAndResetDrawing()
        testMemoryPairsInitialState()
        testMemoryPairsBoardSize()
        testMemoryPairsMatchFlow()
        testMemoryPairsMismatchFlow()
        testMemoryPairsResetRotatesSymbols()
        testNumberSprintInitialState()
        testNumberTrailAdjacencyRules()
        testNumberTrailHintFlow()
        testNumberTrailLevelAndTargetIncrease()
        testNumberTrailEfficiencyScoring()
        testNumberTrailHitAndWinFlow()
        testNumberTrailBustAndLossFlow()
        print("TapGame smoke tests passed")
    }

    private static func testInitialGalleryState() {
        let game = TapGame()
        precondition(game.galleryItems.count >= 6, "Expected multiple drawings in gallery")
        precondition(game.currentDrawingID == nil, "Game should start at gallery")
    }

    private static func testSelectDrawingAndGridSize() {
        var game = TapGame()
        guard let first = game.galleryItems.first else {
            preconditionFailure("Expected at least one drawing")
        }

        game.selectDrawing(first.id)
        precondition(game.currentDrawingID == first.id, "Expected selected drawing ID")
        precondition(game.cells.count >= 600, "Expected denser pixel grid")
        precondition(game.currentGridWidth * game.currentGridHeight == game.cells.count, "Grid dimensions should match cell count")
    }

    private static func testOnlyUsedColorsAreExposed() {
        var game = TapGame()
        guard let first = game.galleryItems.first else {
            preconditionFailure("Expected at least one drawing")
        }
        game.selectDrawing(first.id)

        let available = Set(game.availableColorIndices)
        let usedByCells = Set(game.cells.map(\.targetColorIndex).filter { $0 >= 0 })
        precondition(available == usedByCells, "Palette should only show colors used by drawing")
    }

    private static func testTransparentPixelsAreNotPaintable() {
        var game = TapGame()
        guard let star = game.galleryItems.first(where: { $0.id == "star" }) else {
            preconditionFailure("Expected star drawing")
        }
        game.selectDrawing(star.id)

        guard let transparentCell = game.cells.first(where: { $0.targetColorIndex < 0 }) else {
            preconditionFailure("Expected transparent background cells")
        }
        precondition(game.totalCount < game.cells.count, "Transparent cells should not count towards completion")
        precondition(transparentCell.isPainted, "Transparent cells should be prepainted")
        precondition(game.tapCell(transparentCell.id) == .alreadyPainted, "Transparent cells should be non-paintable")
    }

    private static func testMatchAndMismatchScoring() {
        var game = TapGame()
        guard let first = game.galleryItems.first else {
            preconditionFailure("Expected gallery item")
        }
        game.selectDrawing(first.id)

        guard let target = game.cells.first(where: { !$0.isPainted }) else {
            preconditionFailure("Expected at least one unpainted cell")
        }

        game.selectColor(target.targetColorIndex)
        let match = game.tapCell(target.id)
        precondition(match == .match, "Expected match")
        precondition(game.score > 0, "Score should increase on match")
        precondition(game.streak == 1, "Streak should increment")

        let mismatchColor = (target.targetColorIndex + 1) % game.paletteCount
        guard let mismatchCell = game.cells.first(where: { !$0.isPainted && $0.targetColorIndex != mismatchColor }) else {
            return
        }

        game.selectColor(mismatchColor)
        let mismatch = game.tapCell(mismatchCell.id)
        precondition(mismatch == .mismatch, "Expected mismatch")
        precondition(game.streak == 0, "Streak should reset on mismatch")
    }

    private static func testProgressPersistsAcrossGalleryNavigation() {
        var game = TapGame()
        guard game.galleryItems.count >= 2 else {
            preconditionFailure("Need at least two drawings")
        }

        let firstID = game.galleryItems[0].id
        let secondID = game.galleryItems[1].id

        game.selectDrawing(firstID)
        guard let paintable = game.cells.first(where: { $0.targetColorIndex >= 0 && !$0.isPainted }) else {
            preconditionFailure("Expected paintable cell")
        }
        game.selectColor(paintable.targetColorIndex)
        _ = game.tapCell(paintable.id)
        let paintedAfterTap = game.paintedCount

        game.leaveDrawing()
        game.selectDrawing(secondID)
        game.leaveDrawing()
        game.selectDrawing(firstID)

        precondition(game.paintedCount == paintedAfterTap, "Drawing progress should persist when switching drawings")
    }

    private static func testColorSelectionResetsBetweenDrawings() {
        var game = TapGame()
        guard game.galleryItems.count >= 2 else {
            preconditionFailure("Need at least two drawings")
        }

        game.selectDrawing(game.galleryItems[0].id)
        game.selectColor(game.paletteCount - 1)
        game.selectDrawing(game.galleryItems[1].id)

        let firstAvailableForSecond = game.availableColorIndices.first
        precondition(game.selectedColorIndex == firstAvailableForSecond, "Selected color should reset per drawing")
    }

    private static func testEraseAndResetDrawing() {
        var game = TapGame()
        guard let firstID = game.galleryItems.first?.id else {
            preconditionFailure("Expected drawing")
        }
        game.selectDrawing(firstID)

        guard let target = game.cells.first(where: { $0.targetColorIndex >= 0 && !$0.isPainted }) else {
            preconditionFailure("Expected paintable target")
        }
        game.selectColor(target.targetColorIndex)
        _ = game.tapCell(target.id)
        precondition(game.paintedCount == 1, "Expected one painted cell")

        let erased = game.eraseCell(target.id)
        precondition(erased, "Expected erase to succeed")
        precondition(game.paintedCount == 0, "Erase should clear painted pixel")

        game.selectColor(target.targetColorIndex)
        _ = game.tapCell(target.id)
        precondition(game.paintedCount == 1, "Expected repaint before reset")
        game.resetCurrentDrawing()
        precondition(game.paintedCount == 0, "Reset should clear drawing")
        precondition(game.score == 0, "Reset should clear score")
        precondition(game.streak == 0, "Reset should clear streak")
    }

    private static func testMemoryPairsInitialState() {
        let game = MemoryPairsGame(pairCount: 4, shuffleSeed: 7)
        precondition(game.cards.count == 8, "Expected two cards per pair")
        precondition(game.matchCount == 0, "Expected no matches initially")
        precondition(game.moveCount == 0, "Expected no moves initially")
    }

    private static func testMemoryPairsBoardSize() {
        let small = MemoryPairsGame(pairCount: 6, shuffleSeed: 2)
        let medium = MemoryPairsGame(pairCount: 12, shuffleSeed: 2)
        let large = MemoryPairsGame(pairCount: 18, shuffleSeed: 2)

        precondition(small.cards.count == 12, "Small board should have 12 cards")
        precondition(medium.cards.count == 24, "Medium board should have 24 cards")
        precondition(large.cards.count == 36, "Large board should have 36 cards")
    }

    private static func testMemoryPairsMatchFlow() {
        var game = MemoryPairsGame(pairCount: 4, shuffleSeed: 5)
        guard let (first, second) = firstMatchingPair(in: game.cards) else {
            preconditionFailure("Expected matching pair")
        }

        precondition(game.tapCard(first.id) == .firstReveal, "Expected first reveal")
        precondition(game.tapCard(second.id) == .match, "Expected successful match")
        precondition(game.matchCount == 1, "Expected one matched pair")
        precondition(game.moveCount == 1, "Expected one move after pair compare")
    }

    private static func testMemoryPairsMismatchFlow() {
        var game = MemoryPairsGame(pairCount: 4, shuffleSeed: 5)
        guard let first = game.cards.first,
              let second = game.cards.first(where: { $0.id != first.id && $0.symbol != first.symbol }) else {
            preconditionFailure("Expected two non-matching cards")
        }

        precondition(game.tapCard(first.id) == .firstReveal, "Expected first reveal")
        precondition(game.tapCard(second.id) == .mismatch, "Expected mismatch")
        precondition(game.mismatchCount == 1, "Expected mismatch count increment")

        guard let third = game.cards.first(where: { !$0.isFaceUp && !$0.isMatched }) else {
            preconditionFailure("Expected hidden card after mismatch resolve")
        }
        _ = game.tapCard(third.id)
        let stillFaceUp = game.cards.filter { $0.isFaceUp && !$0.isMatched }
        precondition(stillFaceUp.count <= 1, "Pending mismatch should resolve before next reveal")
    }

    private static func testMemoryPairsResetRotatesSymbols() {
        var game = MemoryPairsGame(pairCount: 6, symbols: MemoryPairsGame.defaultSymbols, selectionSeed: 1, shuffleSeed: 1)
        let firstSet = Set(game.cards.map(\.symbol))

        game.reset(pairCount: 6, symbols: MemoryPairsGame.defaultSymbols, selectionSeed: 2, shuffleSeed: 3)
        let secondSet = Set(game.cards.map(\.symbol))

        precondition(firstSet != secondSet, "Expected icon set to refresh between games")
    }

    private static func firstMatchingPair(in cards: [MemoryCard]) -> (MemoryCard, MemoryCard)? {
        for card in cards {
            if let match = cards.first(where: { $0.id != card.id && $0.symbol == card.symbol }) {
                return (card, match)
            }
        }
        return nil
    }

    private static func testNumberSprintInitialState() {
        let game = NumberSprintGame(gridWidth: 3, gridHeight: 3, maxMoves: 6, requiredHits: 2, seed: 11, presetValues: [2, 3, 4, 5, 1, 6, 7, 8, 9])
        precondition(game.tiles.count == 9, "Expected configured board size")
        precondition(game.score == 0, "Expected zero score initially")
        precondition(game.hits == 0, "Expected zero hits initially")
        precondition(game.movesRemaining == 6, "Expected configured move budget")
        precondition(game.currentLevel == 1, "Expected initial level")
        precondition(game.hasPlayableTargetTrail, "Expected generated target to have a playable trail")
        precondition(game.targetTrailTileIDs.count >= 3, "Expected generated trail length to be at least 3")
        precondition(game.minimalTrailLength >= 3, "Expected minimal trail to be at least 3")
        precondition(game.roundState == .inProgress, "Expected active round")
        precondition(game.currentSum == 0, "Expected empty path sum")
    }

    private static func testNumberTrailAdjacencyRules() {
        var game = NumberSprintGame(gridWidth: 3, gridHeight: 3, maxMoves: 6, requiredHits: 2, seed: 17, presetValues: [2, 3, 4, 5, 1, 6, 7, 8, 9], targetSum: 20)
        let topLeft = game.tiles[0].id
        let bottomRight = game.tiles[8].id

        precondition(game.tapTile(topLeft) == .started(sum: 2), "Expected path to start from first tile")
        precondition(game.tapTile(bottomRight) == .invalidMove, "Expected non-adjacent tile to be rejected")
        precondition(game.currentSum == 2, "Invalid move should keep current path")
    }

    private static func testNumberTrailHintFlow() {
        var game = NumberSprintGame(gridWidth: 2, gridHeight: 2, maxMoves: 5, requiredHits: 2, seed: 71, presetValues: [2, 3, 9, 9], targetSum: 14)
        guard let firstHint = game.revealHint() else {
            preconditionFailure("Expected first hint tile")
        }
        precondition(firstHint == game.targetTrailTileIDs.first, "First hint should reveal first trail tile")

        _ = game.tapTile(firstHint)
        guard let secondHint = game.revealHint() else {
            preconditionFailure("Expected second hint tile")
        }
        precondition(secondHint == game.targetTrailTileIDs[1], "Second hint should reveal next trail tile")
    }

    private static func testNumberTrailLevelAndTargetIncrease() {
        var game = NumberSprintGame(gridWidth: 2, gridHeight: 2, maxMoves: 5, requiredHits: 2, seed: 77, presetValues: [2, 3, 9, 9], targetSum: 14)
        let first = game.tiles[0].id
        let second = game.tiles[1].id
        let third = game.tiles[3].id

        precondition(game.tapTile(first) == .started(sum: 2), "Expected first tap")
        _ = game.tapTile(second)
        let result = game.tapTile(third)
        precondition({
            if case .levelCleared(_, let nextLevel) = result {
                return nextLevel == 2
            }
            return false
        }(), "Expected level clear and next-level prompt")
        precondition(game.currentLevel == 1, "Expected level increase only after confirmation")
        precondition(game.isAwaitingNextLevel, "Expected waiting-for-next-level state")

        let oldTarget = game.targetSum
        precondition(game.advanceToNextLevel(), "Expected next-level transition")
        precondition(game.currentLevel == 2, "Expected level increase after transition")
        precondition(game.targetSum > oldTarget, "Expected target increase on next level")
        precondition(game.hasPlayableTargetTrail, "Expected next target to remain playable")
    }

    private static func testNumberTrailEfficiencyScoring() {
        var efficientGame = NumberSprintGame(gridWidth: 2, gridHeight: 3, maxMoves: 5, requiredHits: 2, seed: 88, presetValues: [2, 3, 4, 9, 5, 1], targetSum: 14)
        precondition(efficientGame.minimalTrailLength == 3, "Expected minimal path to be 3 tiles")
        _ = efficientGame.tapTile(efficientGame.tiles[0].id)
        _ = efficientGame.tapTile(efficientGame.tiles[1].id)
        let efficientResult = efficientGame.tapTile(efficientGame.tiles[3].id)
        let efficientPoints: Int = {
            if case .levelCleared(let points, _) = efficientResult { return points }
            return -1
        }()

        var longPathGame = NumberSprintGame(gridWidth: 2, gridHeight: 3, maxMoves: 5, requiredHits: 2, seed: 89, presetValues: [2, 3, 4, 9, 5, 1], targetSum: 14)
        _ = longPathGame.tapTile(longPathGame.tiles[4].id)
        _ = longPathGame.tapTile(longPathGame.tiles[2].id)
        _ = longPathGame.tapTile(longPathGame.tiles[0].id)
        let longResult = longPathGame.tapTile(longPathGame.tiles[1].id)
        let longPoints: Int = {
            if case .levelCleared(let points, _) = longResult { return points }
            return -1
        }()

        precondition(efficientPoints > longPoints, "Expected shorter solution to award more points")
    }

    private static func testNumberTrailHitAndWinFlow() {
        var winGame = NumberSprintGame(gridWidth: 2, gridHeight: 2, maxMoves: 5, requiredHits: 1, seed: 23, presetValues: [2, 3, 8, 9], targetSum: 14)
        let first = winGame.tiles[0].id
        let second = winGame.tiles[1].id
        let third = winGame.tiles[3].id

        precondition(winGame.tapTile(first) == .started(sum: 2), "Expected path start")
        _ = winGame.tapTile(second)
        let winResult = winGame.tapTile(third)
        precondition(winResult == .wonRound, "Expected win when target score reached")
        precondition(winGame.roundState == .won, "Expected round won state")
        precondition(winGame.score > 0, "Expected score gain on hit")
        precondition(winGame.hits == 1, "Expected hit to count")
        precondition(winGame.currentSum == winGame.targetSum, "Winning trail should remain visible")
        precondition(winGame.selectedTileIDs.count == 3, "Winning trail should remain selected")
    }

    private static func testNumberTrailBustAndLossFlow() {
        var loseGame = NumberSprintGame(gridWidth: 2, gridHeight: 2, maxMoves: 1, requiredHits: 2, seed: 31, presetValues: [9, 9, 2, 3], targetSum: 14)
        let first = loseGame.tiles[0].id
        let second = loseGame.tiles[1].id

        precondition(loseGame.tapTile(first) == .started(sum: 9), "Expected path start for bust case")
        let result = loseGame.tapTile(second)
        precondition(result == .lostRound, "Expected bust to consume final move and lose")
        precondition(loseGame.roundState == .lost, "Expected loss state")
        precondition(loseGame.movesRemaining == 0, "Expected no moves remaining")
        precondition(loseGame.currentSum == 0, "Bust should clear current sum")
    }
}
