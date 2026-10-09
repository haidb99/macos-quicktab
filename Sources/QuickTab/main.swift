import AppKit

MainActor.assumeIsolated {
    if CommandLine.arguments.contains("--diagnostics") {
        Diagnostics.printPermissions()
    } else if let index = CommandLine.arguments.firstIndex(of: "--render-ui"), CommandLine.arguments.count > index + 1 {
        Diagnostics.renderUI(to: CommandLine.arguments[index + 1])
    } else {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
