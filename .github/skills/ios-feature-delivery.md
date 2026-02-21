# Skill: iOS Feature Delivery

Use this for portal/navigation/UI changes.

## Inputs
- Feature request
- Existing SwiftUI file paths

## Steps
1. Confirm the target surface (`ContentView`, game view, or app entrypoint).
2. Implement minimal SwiftUI changes with preserved behavior.
3. Verify navigation and state wiring stay intact.
4. Run:
   - `scripts/test.sh`
   - `xcodebuild -project Dictive.xcodeproj -scheme Dictive -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
5. Summarize changed files and validation results.
