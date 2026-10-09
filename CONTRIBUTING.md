# Contributing to QuickTab

Thanks for helping improve QuickTab. Small, focused pull requests are easiest to review.

## Development setup

QuickTab is a Swift Package Manager project for macOS 14+. Install Xcode Command Line Tools and open the repository in VS Code with the official Swift extension. Xcode is useful for its SDK and XCTest runtime, but no Xcode project is required.

```bash
swift build
swift run QuickTabChecks
swift test
CONFIGURATION=release ./build.sh
./package-dmg.sh
```

On a Command Line Tools-only installation, `swift test` may fail because XCTest is unavailable. Run `swift run QuickTabChecks`, or select an Xcode toolchain before running XCTest.

## Workflow

Use `feature/<short-name>` for features and `fix/<short-name>` for bug fixes. Keep `main` buildable. Explain the user problem, behavior change, tests run, and macOS permissions needed in the pull request.

Before opening a PR:

- run the core checks and `swift build`;
- run `swift test` when an XCTest toolchain is available;
- update docs and `CHANGELOG.md` when behavior changes;
- run `git diff --check`;
- confirm no private API, secret, local path, or generated artifact was added.

## Code guidelines

Keep event-tap callbacks short and free of AX queries, image capture, or blocking work. Keep UI state on the main actor. Prefer public Apple APIs and explicit error handling. Do not add polling when an event or notification can provide the same signal.

## Issues and reviews

Search existing issues first. Bug reports should include QuickTab version, macOS build, architecture, installation source, permission status, reproduction steps, expected/actual behavior, and logs or screenshots. Permission and signing failures belong in the dedicated TCC issue template.
