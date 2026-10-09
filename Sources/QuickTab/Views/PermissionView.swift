import SwiftUI
struct PermissionView: View {
    @ObservedObject var permissions: PermissionManager
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            permissionRow("Accessibility", detail: "Find and switch to individual windows.", granted: permissions.accessibility, action: permissions.requestAccessibility)
            Divider()
            permissionRow("Screen Recording", detail: "Show window previews. Switching still works without this permission.", granted: permissions.screenRecording, action: permissions.requestScreenRecording)
            if !permissions.tapAvailable && permissions.accessibility {
                Divider()
                permissionRow("Input Monitoring", detail: "Check this permission if the global shortcut does not work.", granted: permissions.inputMonitoring, action: permissions.requestInputMonitoring)
            }
            if let error = permissions.lastError {
                Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Label(permissions.tapAvailable ? "Shortcut ready" : "Shortcut unavailable", systemImage: permissions.tapAvailable ? "keyboard.badge.ellipsis" : "keyboard")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Check Again") { permissions.refresh(); permissions.onChange?() }
            }
        }
    }
    private func permissionRow(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(granted ? Color.green : Color.secondary).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if granted { Text("Granted").font(.caption).foregroundStyle(.secondary) }
            else { Button("Grant Access", action: action) }
        }
    }
}
