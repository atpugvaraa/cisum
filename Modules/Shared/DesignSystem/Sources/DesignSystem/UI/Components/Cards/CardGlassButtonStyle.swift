import SwiftUI

extension View {
    @ViewBuilder
    func cardGlassButtonStyle() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(CardGlassFallbackButtonStyle())
        }
        #else
        self.buttonStyle(CardGlassFallbackButtonStyle())
        #endif
    }
}

struct CardGlassFallbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(.white.opacity(configuration.isPressed ? 0.14 : 0.22), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}