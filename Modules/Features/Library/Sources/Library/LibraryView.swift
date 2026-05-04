import DesignSystem
import Kingfisher
import Models
import Services
import SwiftData
import SwiftUI
import YouTubeSDK

#if canImport(SpotifySDK)
    import SpotifySDK
#endif

public struct LibraryView: View {
    public init() {}

    @Environment(ServicesContainer.self) private var container
    @Environment(\.router) private var envRouter
    @Environment(\.modelContext) private var modelContext
    
    private var spotifyCoordinator: SpotifySessionCoordinator { container.user.spotifySessionCoordinator }
    @Query(sort: \Playlist.updatedAt, order: .reverse) private var playlists: [Playlist]

    enum ImportProvider: String, CaseIterable, Identifiable {
        case youtube = "YouTube"
        case spotify = "Spotify"
        var id: String { rawValue }
    }

    private enum ShelfSortMode {
        case alphabetical
        case recent
    }

    @State private var isPresentingImportPicker: Bool = false
    @State private var isPresentingYouTubeImport: Bool = false
    @State private var isPresentingSpotifyImport: Bool = false
    @State private var spotifySnapshot = SpotifyLibrarySnapshot.empty
    @State private var isLoadingSpotifySnapshot = false
    @State private var isSyncingLikedSongs = false
    @State private var shelfSortMode: ShelfSortMode = .alphabetical
    @State private var isCompactShelfMode = false
    @State private var isPinsExpanded = true
    @State private var isPlaylistsExpanded = true
    @State private var isRecentlyAddedExpanded = true
    @State private var libraryActionErrorMessage: String?

    public var body: some View {
        ZStack {
            libraryBackground

            VStack(spacing: 0) {
                libraryHeader
                    .safeAreaPadding(.top, 50)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        pinsSection
                        sectionDivider
                        playlistsShelfSection
                        sectionDivider
                        recentlyAddedSection
                    }
                    .contentMargins(.horizontal, 16)
                }
                .contentMargins(.bottom, 140)
            }
        }
        // YouTube import sheet
        .sheet(isPresented: $isPresentingYouTubeImport) {
            YouTubePlaylistImportSheet { importedPlaylistID in
                envRouter.navigate(to: "playlistDetail:\(importedPlaylistID)")
            }
        }
        // Spotify import sheet
        #if canImport(SpotifySDK)
            .sheet(isPresented: $isPresentingSpotifyImport) {
                SpotifyPlaylistImportSheet { importedPlaylistID in
                    envRouter.navigate(to: "playlistDetail:\(importedPlaylistID)")
                }
                .environment(spotifyCoordinator)
            }
        #endif
        // Provider picker confirmation dialog
        .confirmationDialog(
            "Add Playlist", isPresented: $isPresentingImportPicker, titleVisibility: .visible
        ) {
            Button("YouTube Playlist") {
                isPresentingYouTubeImport = true
            }
            #if canImport(SpotifySDK)
                Button("Spotify Playlist") {
                    isPresentingSpotifyImport = true
                }
            #endif
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose where to import a playlist from.")
        }
        .alert("Library Action Failed", isPresented: libraryActionErrorBinding) {
            Button("OK", role: .cancel) {
                libraryActionErrorMessage = nil
            }
        } message: {
            Text(libraryActionErrorMessage ?? "Unknown error")
        }
        .task(id: spotifyCoordinator.sessionRevision) {
            await refreshSpotifySnapshot()
        }

    }

    private var libraryHeader: some View {
        HStack(spacing: 14) {
            Button {
                envRouter.pop()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 18, height: 18)
                    .padding(11)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.78))
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                            }
                    )
            }
            .buttonStyle(.plain)

            Text("Library")
                .font(.system(size: 20, weight: .semibold, design: .default))
                .foregroundStyle(.white)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                headerControlButton(icon: "arrow.up.arrow.down") {
                    toggleShelfSortMode()
                }

                headerControlButton(icon: "line.3.horizontal.decrease") {
                    isCompactShelfMode.toggle()
                }

                headerControlButton(icon: "plus") {
                    isPresentingImportPicker = true
                }

                headerControlButton(icon: "magnifyingglass") {
                    envRouter.navigate(to: "tab:search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.78))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    }
            )
        }
    }

    private var pinsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            librarySectionHeader(
                title: "Pins",
                showsChevronAfterTitle: false,
                isExpanded: $isPinsExpanded
            )

            if isPinsExpanded {
                if let pinnedPlaylist = pinnedPlaylist {
                    importedPlaylistButton(pinnedPlaylist, size: 160)
                } else {
                    EmptyStateCard(
                        title: "No pins yet",
                        subtitle: "Import a playlist to surface it here.",
                        systemImage: "pin"
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    private var playlistsShelfSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            librarySectionHeader(
                title: "Playlists",
                showsChevronAfterTitle: true,
                isExpanded: $isPlaylistsExpanded
            )

            if isPlaylistsExpanded {
                if shelfPlaylists.isEmpty {
                    EmptyStateCard(
                        title: "No playlists yet",
                        subtitle: "Import from Spotify or YouTube to build this shelf.",
                        systemImage: "music.note.list"
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: shelfCardSpacing) {
                            if spotifyCoordinator.isAuthenticated {
                                Button {
                                    Task {
                                        await openLikedSongs()
                                    }
                                } label: {
                                    FavoriteSongsTile(
                                        title: spotifySnapshot.likedSongsSummary?.name
                                            ?? spotifySnapshot.likedSongsTitle,
                                        count: spotifySnapshot.likedSongsCount,
                                        size: shelfCardSize,
                                        isLoading: isSyncingLikedSongs
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            ForEach(shelfPlaylists) { playlist in
                                importedPlaylistButton(
                                    playlist,
                                    size: shelfCardSize,
                                    detailText: songsLabel(for: playlist.itemCount)
                                )
                            }
                        }
                        .padding(.top, 2)
                        .padding(.bottom, 2)
                    }
                }
            }
        }
    }

    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            librarySectionHeader(
                title: "Recently Added",
                showsChevronAfterTitle: true,
                isExpanded: $isRecentlyAddedExpanded
            )

            if isRecentlyAddedExpanded {
                if recentlyAddedPlaylists.isEmpty {
                    EmptyStateCard(
                        title: "Nothing imported yet",
                        subtitle: "Your newest playlists will appear here once you add them.",
                        systemImage: "clock.arrow.circlepath"
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: shelfCardSpacing) {
                            ForEach(recentlyAddedPlaylists) { playlist in
                                importedPlaylistButton(
                                    playlist,
                                    size: shelfCardSize,
                                    detailText: playlist.subtitle?.uppercased()
                                        ?? songsLabel(for: playlist.itemCount)
                                )
                            }
                        }
                        .padding(.top, 2)
                        .padding(.bottom, 2)
                    }
                }
            }
        }
    }

    private var shelfPlaylists: [Playlist] {
        switch shelfSortMode {
        case .alphabetical:
            return playlists.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .recent:
            return playlists.sorted {
                ($0.importedAt ?? $0.createdAt) > ($1.importedAt ?? $1.createdAt)
            }
        }
    }

    private var recentlyAddedPlaylists: [Playlist] {
        playlists.sorted {
            ($0.importedAt ?? $0.createdAt) > ($1.importedAt ?? $1.createdAt)
        }
    }

    private var pinnedPlaylist: Playlist? {
        playlists.sorted {
            let lhsDate = $0.lastPlayedAt ?? $0.importedAt ?? $0.createdAt
            let rhsDate = $1.lastPlayedAt ?? $1.importedAt ?? $1.createdAt
            return lhsDate > rhsDate
        }.first
    }

    private var shelfCardSize: CGFloat {
        isCompactShelfMode ? 148 : 160
    }

    private var shelfCardSpacing: CGFloat {
        isCompactShelfMode ? 12 : 16
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
            .padding(.vertical, 2)
            .padding(.horizontal)
    }

    private func librarySectionHeader(
        title: String,
        showsChevronAfterTitle: Bool,
        isExpanded: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundStyle(.white)

                if showsChevronAfterTitle {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            Spacer(minLength: 12)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.95, green: 0.25, blue: 0.38))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.78))
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                            }
                    )
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -180))
            }
            .buttonStyle(.plain)
        }
    }

    private func importedPlaylistButton(
        _ playlist: Playlist,
        size: CGFloat,
        detailText: String? = nil
    ) -> some View {
        Button {
            envRouter.navigate(to: "playlistDetail:\(playlist.playlistID)")
        } label: {
            LibraryCoverTile(
                title: playlist.title,
                detailText: detailText ?? playlist.subtitle?.uppercased()
                    ?? playlist.descriptionText?.uppercased(),
                artworkURL: playlist.artworkURLString.flatMap(URL.init(string:)),
                fallbackSymbol: fallbackSymbol(for: playlist.sourceProvider ?? .unknown),
                fallbackGradient: fallbackGradient(for: playlist),
                size: size
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteImportedPlaylist(playlist)
            } label: {
                Label("Delete Playlist", systemImage: "trash")
            }
        }
    }

    private func headerControlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
    }

    private func toggleShelfSortMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            shelfSortMode = shelfSortMode == .alphabetical ? .recent : .alphabetical
        }
    }

    private func songsLabel(for count: Int) -> String {
        count == 1 ? "1 Song" : "\(count) Songs"
    }

    private func deleteImportedPlaylist(_ playlist: Playlist) {
        PlaylistLibraryStore(context: modelContext).deletePlaylist(playlistID: playlist.playlistID)
    }

    private func openLikedSongs() async {
        #if canImport(SpotifySDK)
            guard let service = spotifyImportService else {
                libraryActionErrorMessage = SpotifyImportError.sdkUnavailable.errorDescription
                return
            }

            isSyncingLikedSongs = true
            defer { isSyncingLikedSongs = false }

            do {
                let playlist = try await service.importLikedSongs()
                envRouter.navigate(to: "playlistDetail:\(playlist.playlistID)")
            } catch {
                libraryActionErrorMessage = error.localizedDescription
            }
        #endif
    }

    private var playlistStore: PlaylistLibraryStore {
        PlaylistLibraryStore(context: modelContext)
    }

    private var spotifyImportService: SpotifyPlaylistImportService? {
        #if canImport(SpotifySDK)
            guard let sdk = spotifyCoordinator.sdk else { return nil }
            return SpotifyPlaylistImportService(
                sdk: sdk,
                playlistStore: playlistStore,
                centralStore: CentralMediaStore(context: modelContext)
            )
        #else
            return nil
        #endif
    }

    private var libraryActionErrorBinding: Binding<Bool> {
        Binding(
            get: { libraryActionErrorMessage != nil },
            set: { if !$0 { libraryActionErrorMessage = nil } }
        )
    }

    private func fallbackSymbol(for sourceProvider: PlaylistSource) -> String {
        switch sourceProvider {
        case .spotify:
            return "music.note.list"
        case .youtube, .youtubeMusic:
            return "play.rectangle.fill"
        case .appleMusic:
            return "music.note"
        case .tidal, .qobuz:
            return "music.quarternote.3"
        case .unknown:
            return "tray.full"
        }
    }

    private func fallbackGradient(for playlist: Playlist) -> LinearGradient {
        let title = playlist.title.lowercased()

        if title.contains("chill") {
            return LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.81, blue: 0.56),
                    Color(red: 0.42, green: 0.49, blue: 0.74),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if title.contains("favorite") {
            return LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.92, blue: 0.84),
                    Color(red: 0.90, green: 0.94, blue: 0.98),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if title.contains("meteo") || title.contains("linkin") {
            return LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.17, blue: 0.14),
                    Color(red: 0.08, green: 0.07, blue: 0.07),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        let palettes: [LinearGradient] = [
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.84, blue: 0.67),
                    Color(red: 0.44, green: 0.52, blue: 0.75),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.88, blue: 0.93),
                    Color(red: 0.44, green: 0.50, blue: 0.68),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.24, blue: 0.26),
                    Color(red: 0.62, green: 0.61, blue: 0.58),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            LinearGradient(
                colors: [
                    Color(red: 0.89, green: 0.78, blue: 0.62),
                    Color(red: 0.34, green: 0.42, blue: 0.60),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
        ]

        let seed = title.unicodeScalars.reduce(into: 0) { result, scalar in
            result = (result &* 31) &+ Int(scalar.value)
        }

        return palettes[abs(seed) % palettes.count]
    }

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Imported Playlists",
                subtitle: playlists.isEmpty
                    ? "Playlists you import from Spotify or YouTube show up here."
                    : "\(playlists.count) playlists saved in cisum."
            ) {
                Button {
                    isPresentingImportPicker = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .background(Color.white.opacity(0.08), in: Capsule())
            }

            if playlists.isEmpty {
                EmptyStateCard(
                    title: "No imported playlists yet",
                    subtitle:
                        "Open the import sheet to load personal Spotify playlists or paste a playlist link.",
                    systemImage: "tray"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 172), spacing: 14)], spacing: 14) {
                    ForEach(playlists) { playlist in
                        Button {
                            envRouter.navigate(to: "playlistDetail:\(playlist.playlistID)")
                        } label: {
                            PlaylistCard(playlist: playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var heroSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.09, blue: 0.11),
                            Color(red: 0.04, green: 0.04, blue: 0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 180, height: 180)
                        .blur(radius: 22)
                        .offset(x: 50, y: -40)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.blue.opacity(0.08))
                        .frame(width: 130, height: 130)
                        .blur(radius: 18)
                        .offset(x: 30, y: 30)
                }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Library")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(
                            "Spotify library data, personal imports, and saved playlists in one place."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 10) {
                        if let profile = spotifyCoordinator.accountProfile,
                            let avatarURL = profile.avatarImages.first?.url
                        {
                            KFImage(avatarURL)
                                .placeholder {
                                    Circle()
                                        .fill(Color.white.opacity(0.12))
                                        .overlay {
                                            Image(systemName: "person.fill")
                                                .foregroundStyle(.white.opacity(0.65))
                                        }
                                }
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                }
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.10))
                                .frame(width: 56, height: 56)
                                .overlay {
                                    Image(systemName: "music.note.list")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                        }

                        Text(spotifyCoordinator.sessionStatusLabel)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12), in: Capsule())
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                HStack(spacing: 10) {
                    heroChip(
                        title: spotifyCoordinator.accountDescriptor,
                        systemImage: "person.crop.circle")
                    heroChip(title: "\(playlists.count) imports", systemImage: "tray.full")
                    heroChip(
                        title: spotifySnapshot.playlistCountLabel, systemImage: "music.note.list")
                    heroChip(title: spotifySnapshot.likedSongsCountLabel, systemImage: "heart.fill")
                }
                .lineLimit(1)
                .truncationMode(.tail)

                HStack(spacing: 12) {
                    Button {
                        isPresentingImportPicker = true
                    } label: {
                        Label("Add playlist", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(Color.white, in: Capsule())

                    Button {
                        isPresentingSpotifyImport = true
                    } label: {
                        Label("Import from Spotify", systemImage: "music.note")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.10), in: Capsule())
                }
            }
            .padding(24)
        }
    }

    private var summaryStrip: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            LibraryMetricCard(
                title: "Imported",
                value: "\(playlists.count)",
                subtitle: "Local playlists"
            )

            LibraryMetricCard(
                title: "Spotify playlists",
                value: spotifySnapshot.playlistCountLabel,
                subtitle: spotifyCoordinator.isAuthenticated
                    ? "Loaded from your account" : "Connect to fetch"
            )

            LibraryMetricCard(
                title: "Liked songs",
                value: spotifySnapshot.likedSongsCountLabel,
                subtitle: spotifyCoordinator.isAuthenticated
                    ? "From your Spotify library" : "Unavailable until sign-in"
            )

            LibraryMetricCard(
                title: "Library status",
                value: spotifyCoordinator.sessionStatusLabel,
                subtitle: spotifyCoordinator.accountDescriptor
            )
        }
    }

    private var spotifyShelfSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Spotify Library",
                subtitle: spotifyCoordinator.isAuthenticated
                    ? "Loaded from your personal account."
                    : "Sign in through Settings to load personal playlists and liked songs."
            ) {
                Button {
                    isPresentingSpotifyImport = true
                } label: {
                    Label("Import", systemImage: "arrow.down.circle")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .background(Color.white.opacity(0.08), in: Capsule())
            }

            if isLoadingSpotifySnapshot {
                LoadingShelfCard()
            } else if spotifySnapshot.featuredPlaylists.isEmpty {
                EmptyStateCard(
                    title: spotifyCoordinator.isAuthenticated
                        ? "No Spotify playlists found" : "Connect Spotify to unlock this shelf",
                    subtitle: spotifyCoordinator.isAuthenticated
                        ? "cisum will show your personal Spotify library here once it loads."
                        : "Open Settings and sign in with Spotify to load your personal playlists.",
                    systemImage: "music.note.list"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(spotifySnapshot.featuredPlaylists) { playlist in
                            SpotifyShelfCard(playlist: playlist)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var libraryBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.03, green: 0.03, blue: 0.035),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(0.03), .clear],
                center: .topLeading,
                startRadius: 24,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private func heroChip(title: String, systemImage: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.10), in: Capsule())
        .foregroundStyle(.white.opacity(0.88))
    }

    private func sectionHeader<Accessory: View>(
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            accessory()
        }
    }

    private func refreshSpotifySnapshot() async {
        #if canImport(SpotifySDK)
            guard spotifyCoordinator.isAuthenticated,
                let sdk = spotifyCoordinator.sdk
            else {
                spotifySnapshot = .empty
                return
            }

            isLoadingSpotifySnapshot = true
            defer { isLoadingSpotifySnapshot = false }

            do {
                Utilities.Logger.log("LibraryView: Fetching Spotify snapshot...")
                async let playlists = sdk.account.playlists(limit: 40)
                async let likedSongsPage = sdk.account.likedSongs(limit: 1)
                let (playlistsResult, likedSongs) = try await (playlists, likedSongsPage)

                let count = likedSongs.totalCount ?? likedSongs.items.count
                Utilities.Logger.log(
                    "LibraryView: Spotify snapshot fetched. Playlists: \(playlistsResult.count), Liked Songs: \(count)"
                )

                spotifySnapshot = SpotifyLibrarySnapshot(
                    accountDisplayName: spotifyCoordinator.accountProfile?.displayName ?? "Spotify",
                    username: spotifyCoordinator.accountProfile?.username,
                    playlistCount: playlistsResult.count,
                    likedSongsCount: count,
                    likedSongsTitle: "Liked Songs",
                    likedSongsSummary: nil,
                    totalCount: playlistsResult.count,
                    featuredPlaylists: Array(playlistsResult.prefix(6))
                )
            } catch {
                Utilities.Logger.log(
                    "LibraryView: Failed to fetch Spotify snapshot: \(error.localizedDescription)")
                spotifySnapshot = .empty
            }
        #else
            spotifySnapshot = .empty
        #endif
    }
}

private struct LibraryMetricCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        )

    }
}

private struct PlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            artworkView

            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(playlist.subtitle ?? playlist.descriptionText ?? sourceLabel)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    sourceBadge

                    Text("\(playlist.itemCount) tracks")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        )

    }

    @ViewBuilder
    private var artworkView: some View {
        if let artworkURLString = playlist.artworkURLString,
            let artworkURL = URL(string: artworkURLString)
        {
            KFImage(artworkURL)
                .placeholder {
                    fallbackArtwork
                }
                .resizable()
                .scaledToFill()
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            fallbackArtwork
                .frame(height: 130)
        }
    }

    private var fallbackArtwork: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(fallbackGradient)
            .overlay {
                Image(systemName: sourceSymbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
    }

    private var sourceBadge: some View {
        Text(sourceLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.18), in: Capsule())
            .foregroundStyle(badgeColor)
    }

    private var sourceLabel: String {
        switch playlist.sourceProvider ?? .unknown {
        case .youtube:
            return "YouTube"
        case .youtubeMusic:
            return "YouTube Music"
        case .appleMusic:
            return "Apple Music"
        case .spotify:
            return "Spotify"
        case .tidal:
            return "Tidal"
        case .qobuz:
            return "Qobuz"
        case .unknown:
            return "Imported"
        }
    }

    private var sourceSymbol: String {
        switch playlist.sourceProvider ?? .unknown {
        case .youtube, .youtubeMusic:
            return "play.rectangle.fill"
        case .appleMusic:
            return "music.note"
        case .spotify:
            return "music.note.list"
        case .tidal, .qobuz:
            return "music.quarternote.3"
        case .unknown:
            return "tray.full"
        }
    }

    private var badgeColor: Color {
        switch playlist.sourceProvider ?? .unknown {
        case .spotify:
            return Color(red: 0.11, green: 0.73, blue: 0.33)
        case .youtube:
            return Color(red: 0.97, green: 0.27, blue: 0.27)
        case .youtubeMusic:
            return Color(red: 0.93, green: 0.58, blue: 0.20)
        case .appleMusic:
            return Color(red: 0.94, green: 0.35, blue: 0.56)
        case .tidal, .qobuz:
            return .blue
        case .unknown:
            return .secondary
        }
    }

    private var fallbackGradient: LinearGradient {
        switch playlist.sourceProvider ?? .unknown {
        case .spotify:
            return LinearGradient(
                colors: [Color.green.opacity(0.9), Color.green.opacity(0.35)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .youtube:
            return LinearGradient(
                colors: [Color.red.opacity(0.85), Color.orange.opacity(0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .youtubeMusic:
            return LinearGradient(
                colors: [Color.orange.opacity(0.85), Color.pink.opacity(0.42)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .appleMusic:
            return LinearGradient(
                colors: [Color.pink.opacity(0.8), Color.red.opacity(0.45)], startPoint: .topLeading,
                endPoint: .bottomTrailing)
        case .tidal, .qobuz:
            return LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .unknown:
            return LinearGradient(
                colors: [Color.gray.opacity(0.8), Color.gray.opacity(0.35)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct SpotifyShelfCard: View {
    let playlist: SpotifyLibraryPlaylistSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(playlist.ownerDisplayName ?? playlist.ownerUsername ?? "Spotify")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)

                Text(trackCountLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(12)
        .frame(width: 180, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        )

    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkURL = playlist.artworkURL {
            KFImage(artworkURL)
                .placeholder {
                    fallbackArtwork
                }
                .resizable()
                .scaledToFill()
                .frame(height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            fallbackArtwork
                .frame(height: 132)
        }
    }

    private var fallbackArtwork: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.green.opacity(0.9), Color.black.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "music.note.list")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
    }

    private var trackCountLabel: String {
        if let trackCount = playlist.trackCount {
            return "\(trackCount) tracks"
        }

        return "Spotify playlist"
    }
}

private struct EmptyStateCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 42, height: 42)
                .background(
                    Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        )

    }
}

private struct LoadingShelfCard: View {

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Loading your Spotify library…")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        )

    }
}

private struct LibraryTileData {
    let title: String
    let secondaryText: String?
    let artworkURL: URL?
    let fallbackSymbol: String
    let fallbackGradient: LinearGradient
}

private struct LibraryCoverTile: View {
    let title: String
    let detailText: String?
    let artworkURL: URL?
    let fallbackSymbol: String
    let fallbackGradient: LinearGradient
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            artwork
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let detailText {
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(2)
                }
            }
            .frame(width: size, alignment: .leading)
        }
        .frame(width: size, alignment: .leading)

    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkURL {
            KFImage(artworkURL)
                .placeholder {
                    fallbackArtwork
                }
                .resizable()
                .scaledToFill()
        } else {
            fallbackArtwork
        }
    }

    private var fallbackArtwork: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(fallbackGradient)
            .overlay {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
            }
    }
}

private struct FavoriteSongsTile: View {
    let title: String
    let count: Int
    let size: CGFloat
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .frame(width: size, height: size)
                .overlay {
                    if isLoading {
                        ProgressView()
                            .tint(Color(red: 1.0, green: 0.08, blue: 0.28))
                    } else {
                        Image(systemName: "star.fill")
                            .font(.system(size: size * 0.46, weight: .black))
                            .foregroundStyle(Color(red: 1.0, green: 0.08, blue: 0.28))
                    }
                }

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(count == 1 ? "1 Song" : "\(count) Songs")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
        }
        .frame(width: size, alignment: .leading)

    }
}

#if canImport(SpotifySDK)
    private struct SpotifyLibrarySnapshot {
        var accountDisplayName: String
        var username: String?
        var playlistCount: Int
        var likedSongsCount: Int
        var likedSongsTitle: String
        var likedSongsSummary: SpotifyLibraryPlaylistSummary?
        var totalCount: Int?
        var featuredPlaylists: [SpotifyLibraryPlaylistSummary]

        static let empty = SpotifyLibrarySnapshot(
            accountDisplayName: "Spotify",
            username: nil,
            playlistCount: 0,
            likedSongsCount: 0,
            likedSongsTitle: "Liked Songs",
            likedSongsSummary: nil,
            totalCount: nil,
            featuredPlaylists: []
        )

        var playlistCountLabel: String {
            "\(playlistCount)"
        }

        var likedSongsCountLabel: String {
            "\(likedSongsCount)"
        }
    }
#endif

#Preview {
    LibraryView()
}
