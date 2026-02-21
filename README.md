# Dictive

Dictive is a SwiftUI iOS app that hosts mini-games, starting with **Mini-game #1: Magic Bubble Coloring**.

## Project layout
- `Dictive/ContentView.swift` – current mini-game UI.
- `Dictive/DictiveGame.swift` – game state/model logic.
- `Dictive/DictiveApp.swift` – app entrypoint.

## Build
```bash
xcodebuild -project Dictive.xcodeproj -scheme Dictive -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

## Scaling to more games
Use `ContentView` as the shell and add additional game views/models under `Dictive/` (or per-game subfolders), keeping each game's model pure Swift for easy testing.
