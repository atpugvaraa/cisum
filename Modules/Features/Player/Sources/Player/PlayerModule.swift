import SwiftUI

@MainActor
public final class PlayerModule {
    private let viewModel: PlayerViewModel

    public init(viewModel: PlayerViewModel) {
        self.viewModel = viewModel
    }

    public func miniPlayer(isExpanded: Binding<Bool>, namespace: Namespace.ID) -> some View {
        DynamicPlayerIsland(isPlayerExpanded: isExpanded, namespace: namespace)
            .environment(viewModel)
    }

    public func expandablePlayer(show: Binding<Bool>, isExpanded: Binding<Bool>, collapsedFrame: CGRect) -> some View {
        ExpandablePlayer(show: show, isPlayerExpanded: isExpanded, collapsedFrame: collapsedFrame)
            .environment(viewModel)
    }

    public var accentColor: Color {
        viewModel.currentAccentColor
    }

    public var currentVideoId: String? {
        viewModel.currentVideoId
    }

    public func handleScenePhaseChange(_ phase: ScenePhase) {
        viewModel.handleScenePhaseChange(phase)
    }
}
