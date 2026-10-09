import SwiftUI
struct WindowCardView: View {
    let item: WindowItem
    let image: NSImage?
    let selected: Bool
    let width: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon = item.icon { Image(nsImage: icon).resizable().frame(width: 20, height: 20) }
                Text(item.appName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                if item.minimized { Image(systemName: "minus.rectangle").foregroundStyle(.secondary).help("Minimized") }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(Color.black.opacity(0.22))
                if let image {
                    Image(nsImage: image).resizable().interpolation(.high).scaledToFit().padding(3)
                } else if let icon = item.icon {
                    Image(nsImage: icon).resizable().scaledToFit().frame(width: 54, height: 54).opacity(0.8)
                } else { Image(systemName: "macwindow").font(.system(size: 42)).foregroundStyle(.secondary) }
            }.frame(height: (width - 24) * 0.6).clipped()
            Text(item.title.isEmpty ? "Untitled window" : item.title)
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.86)).lineLimit(1).truncationMode(.middle)
        }
        .padding(12).frame(width: width)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(selected ? 0.12 : 0.045)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color(red: 0.43, green: 0.70, blue: 1) : .white.opacity(0.08), lineWidth: selected ? 2.5 : 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.appName), \(item.title.isEmpty ? "Untitled window" : item.title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
