# Architecture

QuickTab has a small pure-logic core and a macOS integration layer.

```text
CGEventTap -> KeyboardMonitor -> SwitcherController -> NSPanel/SwiftUI
                                    |
               WindowManager <- AX/NSWorkspace notifications
                                    |
               WindowActivator -> AX unhide/unminimize/activate/raise
                                    |
               WindowPreviewService -> ScreenCaptureKit -> bounded cache
```

`QuickTabCore` contains keyboard state, MRU, selection, `WindowID`, preview matching, cost-bounded caching, and overlay geometry. It must not import AppKit or call macOS permissions.

`WindowManager` owns AX references on a serial queue. Window identity uses PID, application launch generation, and an internal serial; titles are presentation data and never identity. `WindowActivator` revalidates the generation and AX reference before activating a target.

The event tap callback only updates keyboard state and sends commands to the main actor. The configured modifier/key pair is read from `SettingsManager` and applied on the keyboard run loop. Escape cancels. Releasing the final configured modifier commits. If the tap is disabled, permissions disappear, or modifier state becomes ambiguous, the session is cancelled.

The overlay is non-activating. ScreenCaptureKit is optional: preview failures never block switching. Preview matching rejects ambiguous matches, and capture work is capped at two concurrent requests with a 64 MiB cache.

TCC permissions are never bypassed. Fullscreen, Spaces, protected windows, Secure Input, and non-standard AX applications remain subject to public macOS API limits.
