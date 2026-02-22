# Dictive

Dictive is a SwiftUI iOS app portal for mini-games, with **Mini-game #1: Magic Bubble Coloring**, **Mini-game #2: Animal Memory Match**, and **Mini-game #3: Number Trail**.

## Project layout
- `Dictive/ContentView.swift` – portal shell + mini-game navigation.
- `Dictive/DictiveGame.swift` – game model/state logic.
- `Dictive/MemoryPairsGame.swift` – memory-match model/state logic.
- `Dictive/MemoryPairsGameView.swift` – memory-match SwiftUI game screen.
- `Dictive/NumberSprintGame.swift` – target-sum puzzle model/state logic.
- `Dictive/NumberSprintGameView.swift` – target-sum puzzle SwiftUI game screen.
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

## Local signing config (recommended)
Use a local, untracked config so each developer keeps their own team/bundle ID:

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Then edit:
- `DICTIVE_DEVELOPMENT_TEAM`
- `DICTIVE_BUNDLE_IDENTIFIER`

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

## Generating better drawing templates from images
Use the image pixelation helper to convert real source art into palette-mapped `DrawingTemplate` data.

```bash
python3 -m venv .venv
.venv/bin/pip install pillow
.venv/bin/python scripts/pixelate_template.py path/to/image.png --id dolphin --name Dolphin --width 15 --height 15 --mode tonal --buckets 6
```

You can send output directly to a file:

```bash
.venv/bin/python scripts/pixelate_template.py path/to/image.png --id dolphin --name Dolphin --mode fixed --palette-size 16 --output /tmp/dolphin.swift
```

## Gallery image source (free to use)
Current gallery templates were generated from [OpenMoji](https://openmoji.org/) icons (CC BY-SA 4.0).  
Source files are stored under `Assets/source-images/`.
