#!/usr/bin/env bash
set -euo pipefail

TMP_BIN="/tmp/dictive_tapgame_tests"
swiftc Dictive/DictiveGame.swift Tests/TapGameSmokeTests.swift -o "$TMP_BIN"
"$TMP_BIN"
