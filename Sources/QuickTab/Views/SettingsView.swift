import SwiftUI
import ServiceManagement
struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var permissions: PermissionManager
    let onboarding: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.on.rectangle").font(.system(size: 32, weight: .medium)).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(onboarding ? "Welcome to QuickTab" : "QuickTab").font(.system(size: 24, weight: .semibold))
                        Text("Hold your shortcut · cycle windows · release to switch").foregroundStyle(.secondary)
                    }
                }
                GroupBox {
                    PermissionView(permissions: permissions).padding(12)
                } label: { Text("Permissions") }
                GroupBox {
                    VStack(alignment: .leading, spacing: 18) {
                        Toggle("Enable QuickTab", isOn: $settings.enabled)
                        Toggle("Show window previews", isOn: $settings.thumbnails)
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Window switching shortcut")
                                Text(settings.shortcutDescription).font(.callout).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("Modifier", selection: $settings.shortcutModifier) {
                                Text("⌥ Option").tag(UInt8(1))
                                Text("⌃ Control").tag(UInt8(2))
                                Text("⌘ Command").tag(UInt8(4))
                            }.labelsHidden().frame(width: 130)
                            Picker("Key", selection: $settings.shortcutKeyCode) {
                                Text("Tab").tag(UInt16(48))
                                Text("Space").tag(UInt16(49))
                                Text("Return").tag(UInt16(36))
                                Text("\\").tag(UInt16(42))
                                Text("/").tag(UInt16(47))
                            }.labelsHidden().frame(width: 100)
                        }
                        if let warning = settings.shortcutConflictWarning {
                            Label(warning, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button("Restore Option + Tab") { settings.resetShortcut() }.buttonStyle(.link)
                        HStack {
                            Text("Card size")
                            Slider(value: $settings.cardWidth, in: 180...360, step: 20)
                            Text("\(Int(settings.cardWidth)) pt").monospacedDigit().frame(width: 55)
                        }
                        Stepper("Up to \(settings.maximumWindows) windows", value: $settings.maximumWindows, in: 1...100)
                        HStack {
                            Text("Animation")
                            Slider(value: $settings.animationDuration, in: 0...0.25, step: 0.05)
                            Text(settings.animationDuration == 0 ? "Off" : "\(Int(settings.animationDuration * 1000)) ms").monospacedDigit().frame(width: 55)
                        }
                        Divider()
                        Toggle("Launch at Login", isOn: Binding(get: { settings.launchAtLogin }, set: settings.setLaunchAtLogin))
                        if settings.loginStatus == .requiresApproval {
                            Button("Approve in Login Items") { SMAppService.openSystemSettingsLoginItems() }
                        }
                        if let message = settings.message { Text(message).font(.caption).foregroundStyle(.orange) }
                    }.padding(12)
                } label: { Text("Preferences") }
                Text("Hold the selected shortcut to switch · Shift to reverse · Esc to cancel\nQuickTab runs in the menu bar and does not appear in the Dock.")
                    .font(.callout).foregroundStyle(.secondary)
            }.padding(28)
        }
        .frame(minWidth: 540, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .onAppear { permissions.watchSettings(true); settings.refreshLoginStatus() }
        .onDisappear { permissions.watchSettings(false) }
    }
}
