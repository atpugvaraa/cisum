import SwiftUI
import DesignSystem
import Services


public struct SearchOverlayBar: View {
    @Environment(AppServices.self) private var appServices
    @Environment(SearchServices.self) private var searchServices
    
    private var searchOverlay: SearchOverlayController { appServices.searchOverlayController }
    private var searchViewModel: any SearchViewModelInterface { searchServices.searchViewModel }
    private var envRouter: Router { appServices.router }

    public init() {}

    @FocusState private var isSearchFieldFocused: Bool

    public var body: some View {
        VStack(spacing: 8) {
            searchField

            if searchOverlay.context.availableScopes.count > 1 {
                scopeSelector
            }

            if shouldShowSuggestions {
                suggestionsPanel
            }
        }
        .onChange(of: searchOverlay.focusRequestID) { _, _ in
            isSearchFieldFocused = true
        }

    }

    private var shouldShowSuggestions: Bool {
        searchOverlay.selectedScope.isGlobal
            && isSearchFieldFocused
            && !searchOverlay.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !searchViewModel.suggestions.isEmpty
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(searchOverlay.selectedScope.prompt, text: queryBinding)
                .textFieldStyle(.plain)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    submitSearch()
                }

            if !searchOverlay.query.isEmpty {
                Button {
                    queryBinding.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(width: 260)
        .background {
            #if os(macOS)
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 50, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 50))
            } else {
                RoundedRectangle(cornerRadius: 50, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            #else
            RoundedRectangle(cornerRadius: 50, style: .continuous)
                .fill(.ultraThinMaterial)
            #endif
        }
        .overlay {
            RoundedRectangle(cornerRadius: 50, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 20, y: 6)
    }

    private var scopeSelector: some View {
        HStack(spacing: 8) {
            ForEach(searchOverlay.context.availableScopes) { scope in
                let isSelected = searchOverlay.selectedScope == scope

                Button {
                    searchOverlay.selectScope(scope)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: scope.symbolName)
                        Text(scope.title)
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        Capsule(style: .continuous)
                            .fill(isSelected ? .white.opacity(0.22) : .white.opacity(0.08))
                    }
                }
                .buttonStyle(.plain)
            }

            if searchOverlay.canSwitchToGlobalFromShortcut {
                Button {
                    switchToGlobalAndSearch()
                } label: {
                    Text("Global (Cmd+Enter)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.08))
                        }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(8)
        .frame(width: 560, alignment: .leading)
        .background {
            #if os(macOS)
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            #else
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
            #endif
        }
    }

    private var suggestionsPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(searchViewModel.suggestions.prefix(6)), id: \.self) { suggestion in
                Button {
                    searchOverlay.updateActiveQuery(suggestion)
                    if searchViewModel.searchText != suggestion {
                        searchViewModel.searchText = suggestion
                    }
                    submitSearch()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(suggestion)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 560)
        .background {
            #if os(macOS)
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            #else
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
            #endif
        }
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { searchOverlay.query },
            set: { newValue in
                searchOverlay.updateActiveQuery(newValue)
                guard searchOverlay.selectedScope.isGlobal else { return }
                if searchViewModel.searchText != newValue {
                    searchViewModel.searchText = newValue
                }
            }
        )
    }

    private func switchToGlobalAndSearch() {
        searchOverlay.switchToGlobalScope(carryCurrentQuery: true)
        submitSearch()
    }

    private func submitSearch() {
        let trimmedQuery = searchOverlay.query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchOverlay.updateActiveQuery(trimmedQuery)

        switch searchOverlay.selectedScope {
        case .global:
            envRouter.navigate(to: "tab:search")

            if searchViewModel.searchText != trimmedQuery {
                searchViewModel.searchText = trimmedQuery
            } else {
                searchViewModel.performDebouncedSearch()
            }

        case .playlist:
            break
        }
    }
}
