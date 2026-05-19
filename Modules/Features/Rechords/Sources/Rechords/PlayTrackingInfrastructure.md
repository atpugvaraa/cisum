# Rechords — Play Tracking Infrastructure Plan

## Overview

This document outlines the infrastructure needed to track user listening activity offline using SwiftData, powering the `RechordsDataProvider` with real stats instead of mock data.

---

## 1. SwiftData Models

### `PlaySession`

Tracks a single play event — the atom of listening data.

```swift
@Model
final class PlaySession {
    var id: UUID
    var trackID: String
    var trackName: String
    var artistName: String
    var albumName: String?
    var albumArtURL: URL?
    var durationSeconds: Int       // actual played duration
    var timestamp: Date
    var source: String             // "spotify", "youtube", "local", "saavn", etc.

    init(
        trackID: String, trackName: String, artistName: String,
        albumName: String? = nil, albumArtURL: URL? = nil,
        durationSeconds: Int, timestamp: Date = .now, source: String
    ) { ... }
}
```

### `ArtistAggregate`

Denormalized aggregate updated after each play — avoids re-aggregating millions of `PlaySession` rows.

```swift
@Model
final class ArtistAggregate {
    var id: String         // artist name (lowercased) as ID
    var artistName: String
    var totalPlays: Int
    var totalMinutes: Int
    var firstListened: Date
    var lastListened: Date

    init(artistName: String) { ... }
}
```

### `TrackAggregate`

```swift
@Model
final class TrackAggregate {
    var id: String         // trackID
    var trackName: String
    var artistName: String
    var albumName: String?
    var albumArtURL: URL?
    var totalPlays: Int
    var totalMinutes: Int
    var lastListened: Date

    init(trackID: String, trackName: String, artistName: String) { ... }
}
```

### `GenreAggregate`

```swift
@Model
final class GenreAggregate {
    var id: String
    var genreName: String
    var totalPlays: Int

    init(genreName: String) { ... }
}
```

---

## 2. Recording Service

### `PlaybackRecorder`

A small, focused service injected into the player pipeline.

```swift
@MainActor
final class PlaybackRecorder {
    private let modelContext: ModelContext
    private var currentSession: PlaySession?
    private var playStartTime: Date?

    func trackDidStart(track: TrackInfo) { ... }
    func trackDidEnd(playheadSeconds: Int) { ... }
    func trackWasSkipped() { ... }        // mark as skipped, ignore duration

    private func incrementAggregates(session: PlaySession) { ... }
    private func updateArtist(artist: String, minutes: Int) { ... }
    private func updateTrack(trackID: String, minutes: Int) { ... }
    private func updateGenre(genre: String) { ... }
}
```

**Integration points:**
- Hook into `PlayerViewModel` when a new track begins playback.
- Hook on track end / skip / next.
- Use `playheadSeconds` from the player's progress tracker to record actual listened duration (not full track length).

### Data Flow

```
Track starts → PlaybackRecorder creates PlaySession(timestamp: now)
Track ends   → PlaybackRecorder finalises session with duration
             → Saves PlaySession to SwiftData
             → Increments/de-dupes aggregates (ArtistAggregate, TrackAggregate, GenreAggregate)
```

---

## 3. Data Provider for Rechords

### `LiveRechordsDataProvider`

Implements `RechordsDataProvider` by querying SwiftData aggregates.

```swift
@MainActor
final class LiveRechordsDataProvider: RechordsDataProvider {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchChapters() async -> [RechordsCarouselView.RechordChapter] {
        let topArtist = fetchTopArtist()
        let topTrack  = fetchTopTrack()
        let totalMinutes = fetchTotalListeningMinutes()
        let topGenre  = fetchTopGenre()

        return [
            makeChapter(.artists,   value: "\(topArtist.minutes)",   label: "minutes",     title: topArtist.name,       art: topArtist.albumArt),
            makeChapter(.songs,     value: "\(topTrack.plays)",      label: "plays",       title: topTrack.name,        art: topTrack.albumArt),
            makeChapter(.minutes,   value: formatMinutes(totalMinutes), label: "minutes",  title: "Total Listening",    art: clockGradient),
            makeChapter(.genres,    value: topGenre.name,            label: "#1 genre",    title: "Top Genre",          art: genreGradient),
        ]
    }
}
```

**Queries needed:**
- `#Predicate` over `ArtistAggregate` sorted by `totalPlays` descending → top artist(s)
- `#Predicate` over `TrackAggregate` sorted by `totalPlays` descending → top track(s)
- `@Query` for summation: `totalMinutes` across all `TrackAggregate` (or `PlaySession`)
- `#Predicate` over `GenreAggregate` sorted by `totalPlays` descending → top genre(s)

---

## 4. Wiring Into App

### In `AppBootstrap.swift` (or equivalent init path)

```swift
let playbackRecorder = PlaybackRecorder(modelContext: modelContext)
playbackDomain.playbackRecorder = playbackRecorder

// For RechordsView:
let rechordsProvider = LiveRechordsDataProvider(modelContext: modelContext)
```

### Replace Mock Provider

In `RechordsView.swift`, swap the mock provider for the live one:

```swift
@State private var dataProvider: any RechordsDataProvider = LiveRechordsDataProvider(
    modelContext: modelContext
)
```

Or pass it via environment / initialiser:

```swift
RechordsView(dataProvider: LiveRechordsDataProvider(modelContext: modelContext))
```

---

## 5. Migration & Edge Cases

| Concern | Solution |
|---------|----------|
| **Cold start — no data** | Provider returns empty chapters array; show a "Start listening to see your Rechords" state |
| **Aggregate staleness** | Update aggregates on each play end, not batch — no ETL needed |
| **Album art URLs go stale** | Cache album art URLs per track; use last-seen URL |
| **Multiple play sources** | Store `source` on `PlaySession`; aggregate all sources together |
| **App deletion** | Data lives in SwiftData store — lost on deletion unless backed up via CloudKit |
| **Privacy** | All data is on-device; no server sync unless opted-in |

---

## 6. Future Enhancements

- **Cloud sync:** Add `CloudKit` entitlement to SwiftData container for free cross-device sync.
- **Time-bucketed stats:** Add `week: Int, month: Int, year: Int` to `PlaySession` for temporal filtering ("Your Top Songs This Month").
- **Rechords export:** Generate a shareable image/card from the carousel view.
- **Listening streaks:** Track consecutive days with plays.
- **Genre mapping:** Map track artist → genre via a local lookup table or cached API response.
