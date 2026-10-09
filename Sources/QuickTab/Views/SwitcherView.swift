import SwiftUI
import QuickTabCore

struct NativeBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow; view.blendingMode = .behindWindow; view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
struct SwitcherView: View {
    @ObservedObject var model: SwitcherModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("QuickTab").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(model.windows.count) windows").font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(.horizontal, 4)
            if model.windows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "macwindow").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text(model.loading ? "Finding windows…" : "No matching windows")
                    Text("Press Esc to close").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(model.cardWidth), spacing: 12), count: model.columns), alignment: .center, spacing: 12) {
                            ForEach(model.windows) { item in
                                WindowCardView(item: item, image: model.previews[item.id], selected: model.selected == item.id, width: model.cardWidth)
                                    .id(item.id)
                                    .onAppear { model.onVisibility?(item.id, true) }
                                    .onDisappear { model.onVisibility?(item.id, false) }
                            }
                        }.padding(3)
                    }
                    .onChange(of: model.selected) { _, id in
                        if let id { proxy.scrollTo(id, anchor: .center) }
                    }
                    .onAppear { if let id = model.selected { proxy.scrollTo(id, anchor: .center) } }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Shortcut: next     Shift + shortcut: previous")
                    Spacer()
                    Text("Release the modifier to switch")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shortcut: next · Shift + shortcut: previous")
                    Text("Release the modifier to switch · Esc to cancel")
                }
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 4)
        }
        .padding(20)
        .background { ZStack { NativeBlur(); Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.65) } }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.13), lineWidth: 1))
        .preferredColorScheme(.dark)
        .animation(reduceMotion || model.animationDuration == 0 ? nil : .easeOut(duration: model.animationDuration), value: model.selected)
    }
}
