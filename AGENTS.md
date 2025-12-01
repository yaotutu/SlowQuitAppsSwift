# Repository Guidelines

## Project Structure & Module Organization
The root hosts `SlowQuitAppsSwift.xcodeproj` for Xcode targets and `SlowQuitAppsSwift/` for Swift sources. SwiftUI entry points (`SlowQuitAppsSwiftApp.swift` and `ContentView.swift`) live beside platform glue such as `EventMonitor.swift`, which encapsulates the Cmd+Q event tap logic. Assets and localization-ready resources belong in `Assets.xcassets`, while signing and capability settings sit in `Info.plist` and `SlowQuitAppsSwift.entitlements`. Add future modules under `SlowQuitAppsSwift/` so Xcode picks them up without manual project edits.

## Build, Test, and Development Commands
- `open SlowQuitAppsSwift.xcodeproj` — launch the project in Xcode for interactive editing and Simulator/device runs.
- `xcodebuild -scheme SlowQuitAppsSwift -configuration Debug build` — command-line build, useful for CI smoke checks.
- `xcodebuild test -scheme SlowQuitAppsSwift -destination 'platform=macOS'` — executes XCTest targets once they exist; keep destinations explicit to avoid automation drift.

## Coding Style & Naming Conventions
Write Swift 5.9+ with four-space indentation and braces on the same line as declarations. Types and protocols use `PascalCase`, functions and variables stay `lowerCamelCase`, and static constants are `UpperCamelCase`. Group view logic inside `View` structs and isolate platform services (accessibility permission checks, event taps, entitlements) into helper types like `EventMonitor`. Favor SwiftUI modifiers over imperative layout where possible, and keep logging consistent via `NSLog` when interacting with AppKit.

## Testing Guidelines
Use XCTest with file names mirroring the production type under test (e.g., `EventMonitorTests`). Tests should live in `SlowQuitAppsSwiftTests/` and follow the `test<Behavior>()` naming pattern. Cover edge cases such as missing accessibility permissions and repeated Cmd+Q events. Run `xcodebuild test -scheme SlowQuitAppsSwift -destination 'platform=macOS'` locally before opening a PR; gating CI should enforce the same command and expect non-flaky results.

## Commit & Pull Request Guidelines
History currently favors short Title Case summaries (“Initial Commit”), so continue writing imperative, <=72 character titles like `Add delayed CmdQ handler`. Reference related issues in the body, list notable UI changes, and mention permission impacts. PRs should include: overview of user-visible behavior, test evidence (command output or screenshots of app states), and any required steps for re-enabling Accessibility permissions (`System Settings > Privacy & Security > Accessibility`). Flag new entitlements or sandbox adjustments in the description to help reviewers focus on security-sensitive changes.

## Security & Permission Tips
The app depends on macOS Accessibility privileges for global key monitoring. Always verify `Info.plist` keys and `.entitlements` changes in both Debug and Release configurations, and document manual setup steps when test plans require revoking or re-granting permissions.

- 始终用中文回答我的问题
- 每一行代码都要有详细的注释
