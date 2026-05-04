import SwiftUI

struct GlassSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)

    }
}

extension View {
    func cisumGlassCard(cornerRadius: CGFloat = 14) -> some View {
        background(GlassSurface(cornerRadius: cornerRadius))
    }
}
