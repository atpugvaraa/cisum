import SwiftUI
import Services

@MainActor
public struct PlayerDependencies {
    public let viewModel: any PlayerViewModelInterface
    
    public init(viewModel: any PlayerViewModelInterface) {
        self.viewModel = viewModel
    }
}

@MainActor
public final class PlayerModule {
    private let viewModel: any PlayerViewModelInterface

    public init(dependencies: PlayerDependencies) {
        self.viewModel = dependencies.viewModel
    }

    public func miniPlayer(isExpanded: Binding<Bool>, namespace: Namespace.ID) -> some View {
        DynamicPlayerIsland(isPlayerExpanded: isExpanded, namespace: namespace)
    }

    public func expandablePlayer(show: Binding<Bool>, isExpanded: Binding<Bool>, collapsedFrame: CGRect) -> some View {
        ExpandablePlayer(show: show, isPlayerExpanded: isExpanded, collapsedFrame: collapsedFrame)
    }

    public var accentColor: Color {
        viewModel.currentAccentColor
    }

    public var currentVideoId: String? {
        viewModel.currentVideoId
    }

    public func handleScenePhaseChange(_ phase: ScenePhase) {
        // ViewModel handles scene phase if needed, or we can expose it via interface
    }
}
