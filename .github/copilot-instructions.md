# Copilot Instructions for Dictive

- Keep gameplay behavior stable unless explicitly requested.
- Prefer pure Swift models for game logic so tests can run without UI.
- Add new mini-games as isolated view+model pairs and wire through a single app shell.
- Validate every code change with `xcodebuild` on the iOS simulator target.
