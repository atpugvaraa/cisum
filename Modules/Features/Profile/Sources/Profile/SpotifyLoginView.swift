import SwiftUI
import Services

#if canImport(SpotifySDK)
import SpotifySDK

public struct SpotifyLoginView: View {
    @Bindable var coordinator: SpotifySessionCoordinator
    @Environment(\.dismiss) private var dismiss

    public init(coordinator: SpotifySessionCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
            if coordinator.session != nil {
                SpotifyTokenExtractorView(
                    mode: coordinator.pendingMode,
                    onTokensExtracted: { tokens in
                        coordinator.completeSession(tokens: tokens)
                        dismiss()
                    }
                )
                .ignoresSafeArea(edges: .bottom)
                .id(coordinator.pendingMode)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color(red: 30/255, green: 215/255, blue: 96/255))
                    Text("Preparing Spotify session…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    coordinator.cancelSessionSetup()
                    dismiss()
                }
            }
        }
        .onAppear {
            if coordinator.session == nil || coordinator.pendingMode == .anonymous {
                coordinator.beginSession(mode: .authenticated)
            }
        }
    }
}
#endif
