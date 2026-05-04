import SwiftUI

extension View {
    @ViewBuilder
    public func optionalSearchable(
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding? = nil,
        isPresented: Binding<Bool>? = nil,
        suggestions: [String] = [],
        onSuggestionTap: ((String) -> Void)? = nil
    ) -> some View {
        #if os(macOS)
        self.searchable(text: text, placement: .toolbar) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onSuggestionTap?(suggestion)
                } label: {
                    Text(suggestion)
                }
            }
        }
        #else
        self.searchable(
            text: text,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search music"
        ) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onSuggestionTap?(suggestion)
                } label: {
                    Label(suggestion, systemImage: "magnifyingglass")
                }
            }
        }
        #endif
    }
}
