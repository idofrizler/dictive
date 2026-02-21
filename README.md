# Dictive

Dictive is a SwiftUI iOS app portal for mini-games, starting with **Mini-game #1: Magic Bubble Coloring**.

## Project layout
- `Dictive/ContentView.swift` – portal shell + mini-game navigation.
- `Dictive/DictiveGame.swift` – game model/state logic.
- `Dictive/DictiveApp.swift` – app entrypoint.
- `Tests/TapGameSmokeTests.swift` – fast executable logic tests.
- `.github/skills/` + `.github/subagents/` – agent workflow playbooks.

## Validation
### 1) Logic smoke tests
```bash
scripts/test.sh
```

### 2) iOS app build
```bash
xcodebuild -project Dictive.xcodeproj -scheme Dictive -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

## Fast local dev loop
```bash
scripts/dev.sh
```
- One-shot build/install/launch (default) to avoid runaway watchers.
- Opt-in watch mode: `scripts/dev.sh --watch`
- Pick simulator: `scripts/dev.sh --simulator "iPad (A16)"`
- Install watcher dependency: `brew install fswatch`

## Extending with new mini-games
1. Add a new game view + model in `Dictive/`.
2. Add a card/route in `ContentView`.
3. Add logic assertions in `Tests/`.
4. Run both validation commands before sharing.
