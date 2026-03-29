import AVFoundation
import Foundation
#if canImport(ffmpegkit)
import ffmpegkit
#endif

actor ArtworkVideoProcessor {
    typealias ProgressHandler = @Sendable (Double) -> Void
    typealias AppGroupContainerURLProvider = @Sendable (String) -> URL?
    typealias FFmpegExecutorOverride = @Sendable (
        _ command: String,
        _ mediaID: String,
        _ estimatedDuration: Double?,
        _ progress: @escaping @Sendable (Double) -> Void
    ) async throws -> Void

    static let shared = ArtworkVideoProcessor()

    enum ArtworkVideoProcessorError: LocalizedError {
        case invalidInput(URL)
        case cachePathFailure
        case ffmpegFailure(message: String)
        case cancelled
        case noOutputProduced

        var errorDescription: String? {
            switch self {
            case .invalidInput(let url):
                return "Invalid HLS input URL: \(url.absoluteString)"
            case .cachePathFailure:
                return "Unable to access the artwork video cache directory."
            case .ffmpegFailure(let message):
                return message
            case .cancelled:
                return "Artwork video processing was cancelled."
            case .noOutputProduced:
                return "FFmpeg finished without producing an MP4 output file."
            }
        }
    }

    private enum StreamMapping {
        static let primary = "0:v:0"
    }

    private enum EncodingStrategy {
        case hardwareTranscode
        case softwareFallback
    }

    private enum CacheProfile {
        static let version = "v3-hw-source-aware"
        static let markerFilename = ".profile"
    }

    private struct SourceMetadata {
        let duration: Double?
        let videoSize: CGSize?
    }

    private enum FFmpegExecutionOutcome: Sendable {
        case success
        case cancelled
        case failure(String)
    }

    private let fileManager: FileManager
    private let appGroupIdentifier: String
    private let appGroupContainerURLProvider: AppGroupContainerURLProvider
    private let ffmpegQueue = DispatchQueue(label: "cisum.artwork-video-processor.ffmpeg")
    private let ffmpegExecutorOverride: FFmpegExecutorOverride?

    private var inFlight: [String: Task<URL, Error>] = [:]
    private var progressObservers: [String: [UUID: ProgressHandler]] = [:]
#if canImport(ffmpegkit)
    private var activeSessions: [String: FFmpegSession] = [:]
#else
    private var activeSessions: [String: AVAssetExportSession] = [:]
#endif

    init(
        fileManager: FileManager = .default,
        appGroupIdentifier: String = "group.aaravgupta.cisum",
        appGroupContainerURLProvider: @escaping AppGroupContainerURLProvider = { identifier in
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        },
        ffmpegExecutorOverride: FFmpegExecutorOverride? = nil
    ) {
        self.fileManager = fileManager
        self.appGroupIdentifier = appGroupIdentifier
        self.appGroupContainerURLProvider = appGroupContainerURLProvider
        self.ffmpegExecutorOverride = ffmpegExecutorOverride
    }

    func prepareVideo(
        for mediaID: String,
        sourceHLSURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard !mediaID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ArtworkVideoProcessorError.invalidInput(sourceHLSURL)
        }
        guard let scheme = sourceHLSURL.scheme?.lowercased(),
              ["http", "https", "file"].contains(scheme) else {
            throw ArtworkVideoProcessorError.invalidInput(sourceHLSURL)
        }

        let cacheDirectory = try artworkVideoCacheDirectory()
        try ensureCurrentCacheProfile(in: cacheDirectory)
        let outputURL = cacheDirectory.appending(path: "\(mediaID).mp4")
        if fileManager.fileExists(atPath: outputURL.path(percentEncoded: false)) {
            print("🖼️ ArtworkVideoProcessor: Cache hit for id=\(mediaID)")
            progress(1)
            return outputURL
        }

        let observerID = UUID()
        addProgressObserver(progress, for: mediaID, id: observerID)

        let task: Task<URL, Error>
        if let existingTask = inFlight[mediaID] {
            task = existingTask
        } else {
            task = Task(priority: .utility) {
                try await self.processVideo(
                    for: mediaID,
                    sourceHLSURL: sourceHLSURL,
                    outputURL: outputURL,
                    cacheDirectory: cacheDirectory
                )
            }
            inFlight[mediaID] = task
        }

        return try await awaitResult(
            for: mediaID,
            observerID: observerID,
            task: task
        )
    }

    private func processVideo(
        for mediaID: String,
        sourceHLSURL: URL,
        outputURL: URL,
        cacheDirectory: URL
    ) async throws -> URL {
        let tempURL = try temporaryOutputURL(for: mediaID)
        let sourceMetadata = await loadSourceMetadata(from: sourceHLSURL)
        let estimatedDuration = sourceMetadata.duration

        defer {
            inFlight[mediaID] = nil
            activeSessions[mediaID] = nil
            progressObservers[mediaID] = nil
        }

        do {
            if fileManager.fileExists(atPath: outputURL.path(percentEncoded: false)) {
                print("🖼️ ArtworkVideoProcessor: Reusing cached artwork video for id=\(mediaID)")
                notifyProgress(1, for: mediaID)
                return outputURL
            }

            print("🖼️ ArtworkVideoProcessor: Probing source for id=\(mediaID)")
            let durationText = sourceMetadata.duration.map { String(format: "%.2f", $0) } ?? "unknown"
            let sizeText: String
            if let videoSize = sourceMetadata.videoSize {
                sizeText = "\(videoSize.width)x\(videoSize.height)"
            } else {
                sizeText = "unknown"
            }
            print("🖼️ ArtworkVideoProcessor: Source probe for id=\(mediaID) duration=\(durationText)s size=\(sizeText)")
            try cleanupItem(at: tempURL)

            print("🖼️ ArtworkVideoProcessor: Encoding motion artwork for id=\(mediaID) with hardware-first preset")
            try await runBestEffortFFmpegCommands(
                sourceHLSURL: sourceHLSURL,
                streamMap: StreamMapping.primary,
                outputURL: tempURL,
                mediaID: mediaID,
                estimatedDuration: estimatedDuration,
                sourceSize: sourceMetadata.videoSize
            )

            guard fileManager.fileExists(atPath: tempURL.path(percentEncoded: false)) else {
                throw ArtworkVideoProcessorError.noOutputProduced
            }

            print("🖼️ ArtworkVideoProcessor: Finalizing motion artwork for id=\(mediaID)")
            try commitTemporaryOutput(from: tempURL, to: outputURL)
            try? writeCacheProfileMarker(in: cacheDirectory)
            notifyProgress(1, for: mediaID)
            print("🖼️ ArtworkVideoProcessor: Motion artwork ready for id=\(mediaID)")
            return outputURL
        } catch is CancellationError {
            try? cleanupItem(at: tempURL)
            throw ArtworkVideoProcessorError.cancelled
        } catch let error as ArtworkVideoProcessorError {
            try? cleanupItem(at: tempURL)
            throw error
        } catch {
            try? cleanupItem(at: tempURL)
            throw ArtworkVideoProcessorError.ffmpegFailure(message: error.localizedDescription)
        }
    }

    private func runBestEffortFFmpegCommands(
        sourceHLSURL: URL,
        streamMap: String,
        outputURL: URL,
        mediaID: String,
        estimatedDuration: Double?,
        sourceSize: CGSize?
    ) async throws {
#if canImport(ffmpegkit)
        let strategies: [EncodingStrategy] = [.hardwareTranscode, .softwareFallback]
        var lastError: ArtworkVideoProcessorError?

        for strategy in strategies {
            try cleanupItem(at: outputURL)

            do {
                try await runFFmpegCommand(
                    command: makeCommand(
                        sourceHLSURL: sourceHLSURL,
                        streamMap: streamMap,
                        outputURL: outputURL,
                        strategy: strategy,
                        sourceSize: sourceSize
                    ),
                    mediaID: mediaID,
                    estimatedDuration: estimatedDuration
                )
                return
            } catch let error as ArtworkVideoProcessorError {
                lastError = error

                if shouldRetryWithFallback(for: error) {
                    throw error
                }
            }
        }

        throw lastError ?? .ffmpegFailure(message: "FFmpeg exhausted all artwork video strategies.")
#else
        _ = streamMap
        _ = estimatedDuration
        _ = sourceSize
        try await runAVFoundationExport(
            sourceHLSURL: sourceHLSURL,
            outputURL: outputURL,
            mediaID: mediaID
        )
#endif
    }

    private func awaitResult(
        for mediaID: String,
        observerID: UUID,
        task: Task<URL, Error>
    ) async throws -> URL {
        try await withTaskCancellationHandler {
            defer {
                Task {
                    self.removeProgressObserver(for: mediaID, id: observerID)
                }
            }
            return try await task.value
        } onCancel: {
            Task {
                await self.cancelObserver(for: mediaID, id: observerID)
            }
        }
    }

    private func runFFmpegCommand(
        command: String,
        mediaID: String,
        estimatedDuration: Double?
    ) async throws {
#if canImport(ffmpegkit)
        try Task.checkCancellation()
        let progressScheduler = makeProgressScheduler(for: mediaID)

        if let ffmpegExecutorOverride {
            try await ffmpegExecutorOverride(command, mediaID, estimatedDuration) { progress in
                progressScheduler(progress)
            }
            return
        }

        let outcome = await withCheckedContinuation { continuation in
            let startedSession = FFmpegKit.executeAsync(
                command,
                withCompleteCallback: { session in
                    guard let session else {
                        continuation.resume(
                            returning: FFmpegExecutionOutcome.failure("FFmpeg did not return a valid session.")
                        )
                        return
                    }

                    let returnCode = session.getReturnCode()
                    if let returnCode {
                        if ReturnCode.isSuccess(returnCode) {
                            continuation.resume(returning: .success)
                            return
                        }
                        if ReturnCode.isCancel(returnCode) {
                            continuation.resume(returning: .cancelled)
                            return
                        }
                    }

                    let logOutput = session.getAllLogsAsString() ?? session.getOutput() ?? ""
                    let failStackTrace = session.getFailStackTrace() ?? ""
                    let message = [failStackTrace, logOutput]
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .joined(separator: "\n")

                    continuation.resume(
                        returning: .failure(
                            message.isEmpty ? "FFmpeg failed to produce artwork video." : message
                        )
                    )
                },
                withLogCallback: { _ in },
                withStatisticsCallback: { [estimatedDuration] statistics in
                    guard let statistics, let estimatedDuration else { return }
                    let timeSeconds = Double(statistics.getTime()) / 1000
                    guard estimatedDuration > 0, timeSeconds.isFinite else { return }
                    let progress = min(max(timeSeconds / estimatedDuration, 0), 0.99)

                    progressScheduler(progress)
                },
                onDispatchQueue: ffmpegQueue
            )

            self.storeActiveSession(startedSession, for: mediaID)
        }

        activeSessions[mediaID] = nil

        switch outcome {
        case .success:
            return
        case .cancelled:
            throw ArtworkVideoProcessorError.cancelled
        case .failure(let message):
            throw ArtworkVideoProcessorError.ffmpegFailure(message: message)
        }
#else
        _ = command
        _ = mediaID
        _ = estimatedDuration
        throw ArtworkVideoProcessorError.ffmpegFailure(message: "FFmpegKit is unavailable on this platform.")
#endif
    }

    #if !canImport(ffmpegkit)
    private func runAVFoundationExport(
        sourceHLSURL: URL,
        outputURL: URL,
        mediaID: String
    ) async throws {
        try Task.checkCancellation()

        let asset = AVURLAsset(url: sourceHLSURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw ArtworkVideoProcessorError.ffmpegFailure(message: "Unable to create AVFoundation export session for motion artwork.")
        }

        guard exportSession.supportedFileTypes.contains(.mp4) else {
            throw ArtworkVideoProcessorError.ffmpegFailure(message: "AVFoundation export does not support MP4 output for motion artwork.")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        activeSessions[mediaID] = exportSession
        notifyProgress(0.05, for: mediaID)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                exportSession.exportAsynchronously {
                    switch exportSession.status {
                    case .completed:
                        continuation.resume()
                    case .cancelled:
                        continuation.resume(throwing: ArtworkVideoProcessorError.cancelled)
                    case .failed:
                        let message = exportSession.error?.localizedDescription ?? "AVFoundation export failed for motion artwork."
                        continuation.resume(throwing: ArtworkVideoProcessorError.ffmpegFailure(message: message))
                    default:
                        let message = exportSession.error?.localizedDescription ?? "AVFoundation export ended unexpectedly."
                        continuation.resume(throwing: ArtworkVideoProcessorError.ffmpegFailure(message: message))
                    }
                }
            }
        } catch {
            activeSessions[mediaID] = nil
            throw error
        }

        notifyProgress(0.95, for: mediaID)
        activeSessions[mediaID] = nil
    }
    #endif

#if canImport(ffmpegkit)
    private func storeActiveSession(_ session: FFmpegSession?, for mediaID: String) {
        activeSessions[mediaID] = session
    }
#endif

    nonisolated private func makeProgressScheduler(for mediaID: String) -> @Sendable (Double) -> Void {
        { [weak self] progress in
            guard let self else { return }
            self.scheduleProgressUpdate(progress, for: mediaID)
        }
    }

    nonisolated private func scheduleProgressUpdate(_ progress: Double, for mediaID: String) {
        Task(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.notifyProgress(progress, for: mediaID)
        }
    }

    private func addProgressObserver(_ progress: @escaping ProgressHandler, for mediaID: String, id: UUID) {
        var observers = progressObservers[mediaID] ?? [:]
        observers[id] = progress
        progressObservers[mediaID] = observers
    }

    private func removeProgressObserver(for mediaID: String, id: UUID) {
        progressObservers[mediaID]?[id] = nil
        if progressObservers[mediaID]?.isEmpty == true {
            progressObservers[mediaID] = nil
        }
    }

    private func cancelObserver(for mediaID: String, id: UUID) {
        removeProgressObserver(for: mediaID, id: id)

        guard progressObservers[mediaID] == nil else {
            return
        }

        inFlight[mediaID]?.cancel()
#if canImport(ffmpegkit)
        if let session = activeSessions[mediaID] {
            session.cancel()
        }
#else
        activeSessions[mediaID]?.cancelExport()
#endif
    }

    private func notifyProgress(_ progress: Double, for mediaID: String) {
        guard let handlers = progressObservers[mediaID]?.values else {
            return
        }
        for handler in handlers {
            handler(progress)
        }
    }

    private func artworkVideoCacheDirectory() throws -> URL {
        guard let containerURL = appGroupContainerURLProvider(appGroupIdentifier) else {
            throw ArtworkVideoProcessorError.cachePathFailure
        }

        let cachesURL = containerURL
            .appending(path: "Library", directoryHint: .isDirectory)
            .appending(path: "Caches", directoryHint: .isDirectory)
            .appending(path: "ArtworkVideos", directoryHint: .isDirectory)

        try fileManager.createDirectory(
            at: cachesURL,
            withIntermediateDirectories: true
        )

        return cachesURL
    }

    private func temporaryOutputURL(for mediaID: String) throws -> URL {
        let directory = try artworkVideoCacheDirectory()
        return directory.appending(path: "\(mediaID)-\(UUID().uuidString).tmp.mp4")
    }

    private func cacheProfileURL(in cacheDirectory: URL) -> URL {
        cacheDirectory.appending(path: CacheProfile.markerFilename)
    }

    private func ensureCurrentCacheProfile(in cacheDirectory: URL) throws {
        let profileURL = cacheProfileURL(in: cacheDirectory)
        if let storedProfile = try? String(contentsOf: profileURL, encoding: .utf8),
           storedProfile.trimmingCharacters(in: .whitespacesAndNewlines) == CacheProfile.version {
            return
        }

        try clearArtworkVideoCache(in: cacheDirectory)
        try writeCacheProfileMarker(in: cacheDirectory)
    }

    private func writeCacheProfileMarker(in cacheDirectory: URL) throws {
        let profileURL = cacheProfileURL(in: cacheDirectory)
        try CacheProfile.version.write(to: profileURL, atomically: true, encoding: .utf8)
    }

    private func clearArtworkVideoCache(in cacheDirectory: URL) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for item in contents {
            try? fileManager.removeItem(at: item)
        }
    }

    private func commitTemporaryOutput(from tempURL: URL, to outputURL: URL) throws {
        if fileManager.fileExists(atPath: outputURL.path(percentEncoded: false)) {
            _ = try fileManager.replaceItemAt(outputURL, withItemAt: tempURL)
        } else {
            try fileManager.moveItem(at: tempURL, to: outputURL)
        }
    }

    private func cleanupItem(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    private func makeCommand(
        sourceHLSURL: URL,
        streamMap: String,
        outputURL: URL,
        strategy: EncodingStrategy,
        sourceSize: CGSize?
    ) -> String {
        let codecArguments: [String]
        switch strategy {
        case .hardwareTranscode:
            codecArguments = hardwareCodecArguments(for: sourceSize)
        case .softwareFallback:
            codecArguments = softwareCodecArguments(for: sourceSize)
        }

        let videoFilter = "scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=lanczos"

        return (
            [
                "-protocol_whitelist \(quotedFFmpegArgument("file,http,https,tcp,tls"))",
                "-i \(quotedFFmpegArgument(sourceHLSURL.absoluteString))",
                "-map \(streamMap)",
                "-vf \(quotedFFmpegArgument(videoFilter))",
                "-an"
            ]
            + codecArguments
            + [
                "-movflags +faststart",
                quotedFFmpegArgument(outputURL.path(percentEncoded: false))
            ]
        ).joined(separator: " ")
    }

    private func hardwareCodecArguments(for sourceSize: CGSize?) -> [String] {
        let maxDimension = max(sourceSize?.width ?? 0, sourceSize?.height ?? 0)
        if maxDimension >= 1920 {
            return [
                "-c:v h264_videotoolbox",
                "-b:v 18000k",
                "-maxrate 24000k",
                "-bufsize 48000k",
                "-pix_fmt yuv420p"
            ]
        }

        if maxDimension >= 1280 {
            return [
                "-c:v h264_videotoolbox",
                "-b:v 14000k",
                "-maxrate 18000k",
                "-bufsize 36000k",
                "-pix_fmt yuv420p"
            ]
        }

        return [
            "-c:v h264_videotoolbox",
            "-b:v 10000k",
            "-maxrate 12000k",
            "-bufsize 24000k",
            "-pix_fmt yuv420p"
        ]
    }

    private func softwareCodecArguments(for sourceSize: CGSize?) -> [String] {
        let maxDimension = max(sourceSize?.width ?? 0, sourceSize?.height ?? 0)
        if maxDimension >= 1920 {
            return [
                "-c:v mpeg4",
                "-q:v 1",
                "-pix_fmt yuv420p"
            ]
        }

        return [
            "-c:v mpeg4",
            "-q:v 2",
            "-pix_fmt yuv420p"
        ]
    }

    private func loadSourceMetadata(from sourceHLSURL: URL) async -> SourceMetadata {
        let asset = AVURLAsset(url: sourceHLSURL)

        do {
            async let duration = asset.load(.duration)
            async let videoTracks = asset.loadTracks(withMediaType: .video)

            let loadedDuration = try await duration
            let loadedTracks = try await videoTracks

            let seconds = loadedDuration.seconds
            let durationValue: Double?
            if seconds.isFinite, !seconds.isNaN, seconds > 0 {
                durationValue = seconds
            } else {
                durationValue = nil
            }

            return SourceMetadata(
                duration: durationValue,
                videoSize: await largestVideoSize(from: loadedTracks)
            )
        } catch {
            return SourceMetadata(duration: nil, videoSize: nil)
        }
    }

    private func largestVideoSize(from tracks: [AVAssetTrack]) async -> CGSize? {
        var sizes: [CGSize] = []

        for track in tracks {
            do {
                let loadedNaturalSize = try await track.load(.naturalSize)
                let loadedPreferredTransform = try await track.load(.preferredTransform)
                let transformedSize = loadedNaturalSize.applying(loadedPreferredTransform)
                let width = abs(transformedSize.width)
                let height = abs(transformedSize.height)

                guard width > 0, height > 0, width.isFinite, height.isFinite else {
                    continue
                }

                sizes.append(CGSize(width: width, height: height))
            } catch {
                continue
            }
        }

        return sizes.max { lhs, rhs in
            lhs.width * lhs.height < rhs.width * rhs.height
        }
    }

    private func shouldRetryWithFallback(for error: ArtworkVideoProcessorError) -> Bool {
        guard case .ffmpegFailure(let message) = error else {
            return false
        }

        let normalized = message.lowercased()
        return normalized.contains("stream map '0:v:0' matches no streams")
            || normalized.contains("stream map '0:v:0'")
            || normalized.contains("matches no streams")
    }

    private func quotedFFmpegArgument(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

}
