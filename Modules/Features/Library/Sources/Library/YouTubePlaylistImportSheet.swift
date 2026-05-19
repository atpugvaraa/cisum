import Utilities
import Kingfisher
import Models
import Services
import SwiftData
import SwiftUI
import YouTubeSDK

public struct YouTubePlaylistImportSheet: View {
    public enum ImportMode: String, CaseIterable, Identifiable {
        case search = "Search"
        case link = "Link"

        public var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(ProviderServices.self) private var providerServices
    private var youtube: YouTube { providerServices.youtube }
    @Environment(\.modelContext) private var modelContext

    public let onImported: (String) -> Void

    public init(onImported: @escaping (String) -> Void) {
        self.onImported = onImported
    }

    @State private var importMode: ImportMode = .search
    @State private var searchQuery: String = ""
    @State private var searchResults: [YouTubePlaylist] = []
    @State private var playlistLink: String = ""

    @State private var isSearching: Bool = false
    @State private var importingPlaylistID: String?

    @State private var errorMessage: String?

    private var importService: YouTubePlaylistImportService {
        let store = PlaylistLibraryStore(context: modelContext)
        return YouTubePlaylistImportService(youtube: youtube, playlistStore: store)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Import Mode", selection: $importMode) {
                        ForEach(ImportMode.allCases) { mode in
                            Text(mode.rawValue)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch importMode {
                case .search:
                    searchSection
                case .link:
                    linkSection
                }
            }
            .navigationTitle("Add Playlist")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert("Import Failed", isPresented: showsErrorAlert) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }

    }

    private var searchSection: some View {
        Section("Search YouTube Playlists") {
            HStack(spacing: 10) {
                TextField("Playlist name", text: $searchQuery)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await performSearch()
                        }
                    }

                Button {
                    Task {
                        await performSearch()
                    }
                } label: {
                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Search")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    isSearching || isImporting
                        || searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if searchResults.isEmpty {
                Text("Search for playlists, then import one tap.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(searchResults) { playlist in
                    SearchPlaylistImportRow(
                        playlist: playlist,
                        isImporting: importingPlaylistID == playlist.id,
                        onImport: {
                            Task {
                                await importSearchResultPlaylist(playlist)
                            }
                        }
                    )
                }
            }
        }
    }

    private var linkSection: some View {
        Section("Import Using Playlist Link") {
            TextField(
                "https://youtube.com/playlist?list=...",
                text: $playlistLink,
                axis: .vertical
            )
#if os(iOS)
            .textInputAutocapitalization(.never)
#endif
            .autocorrectionDisabled()

            Button {
                Task {
                    await importFromLink()
                }
            } label: {
                if importingPlaylistID == linkImportToken {
                    ProgressView()
                } else {
                    Text("Import Playlist")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                isSearching || isImporting
                    || playlistLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text(
                "Paste any YouTube or YouTube Music playlist link. You can also paste a playlist ID."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var showsErrorAlert: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue {
                    errorMessage = nil
                }
            }
        )
    }

    private var isImporting: Bool {
        importingPlaylistID != nil
    }

    private var linkImportToken: String {
        "__link_import__"
    }
}

extension YouTubePlaylistImportSheet {
    fileprivate func performSearch() async {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            return
        }

        guard !isSearching else { return }
        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await importService.searchPlaylists(query: trimmedQuery)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    fileprivate func importSearchResultPlaylist(_ playlist: YouTubePlaylist) async {
        guard importingPlaylistID == nil else { return }
        importingPlaylistID = playlist.id
        defer { importingPlaylistID = nil }

        do {
            let imported = try await importService.importPlaylist(from: playlist)
            onImported(imported.playlistID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    fileprivate func importFromLink() async {
        guard importingPlaylistID == nil else { return }
        let trimmedLink = playlistLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLink.isEmpty else { return }

        importingPlaylistID = linkImportToken
        defer { importingPlaylistID = nil }

        do {
            let imported = try await importService.importPlaylist(fromLink: trimmedLink)
            onImported(imported.playlistID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SearchPlaylistImportRow: View {
    let playlist: YouTubePlaylist
    let isImporting: Bool
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            KFImage(playlist.thumbnailURL)
                .downsampling(size: CGSize(width: 100, height: 100))
                .placeholder {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(normalizedMusicDisplayTitle(playlist.title, artist: playlist.author))
                    .font(.headline)
                    .lineLimit(2)

                let subtitle = [playlist.author, playlist.videoCount]
                    .compactMap { value -> String? in
                        guard let value, !value.isEmpty else { return nil }
                        return value
                    }
                    .joined(separator: " • ")

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button(action: onImport) {
                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Add")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isImporting)
        }
        .padding(.vertical, 2)
    }
}
