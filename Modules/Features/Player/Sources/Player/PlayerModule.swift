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
        #if os(iOS)
        DynamicPlayerIsland(isPlayerExpanded: isExpanded, namespace: namespace)
        #elseif os(macOS)
        DynamicPlayerIsland()
        #endif
    }

    public func expandablePlayer(show: Binding<Bool>, isExpanded: Binding<Bool>, collapsedFrame: CGRect) -> some View {
#if os(iOS)
        ExpandablePlayer(show: show, isPlayerExpanded: isExpanded, collapsedFrame: collapsedFrame)
#else
        EmptyView()
#endif
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
