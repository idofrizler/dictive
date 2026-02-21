# Copilot Instructions for Dictive

## Mission
Build Dictive as a scalable iOS mini-game portal with model-first game logic and predictable validation.

## Core rules
- Keep gameplay behavior stable unless explicitly requested.
- Prefer pure Swift models (Foundation-only when possible) for game logic.
- Keep UI shell (portal/navigation) separate from each game implementation.
- For each change, run build and test commands from README.

## Delivery workflow
1. Implement the smallest safe change.
2. Validate with `scripts/test.sh` and `xcodebuild`.
3. Update docs when workflow or architecture changes.

## New mini-game checklist
- Add a dedicated `View` + model file pair under `Dictive/`.
- Add a portal entry card/navigation from `ContentView`.
- Add or extend logic tests in `Tests/`.
