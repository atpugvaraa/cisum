import AVFoundation
import Foundation
import ffmpegkit

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
        static let primary = "0:v:8"
        static let fallback = "0:v:0"
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
    private var activeSessions: [String: FFmpegSession] = [:]

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

        let outputURL = try cachedFileURL(for: mediaID)
        if fileManager.fileExists(atPath: outputURL.path(percentEncoded: false)) {
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
                try await self.processVideo(for: mediaID, sourceHLSURL: sourceHLSURL, outputURL: outputURL)
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
        outputURL: URL
    ) async throws -> URL {
        let tempURL = try temporaryOutputURL(for: mediaID)
        let estimatedDuration = await loadEstimatedDuration(for: sourceHLSURL)

        defer {
            inFlight[mediaID] = nil
            activeSessions[mediaID] = nil
            progressObservers[mediaID] = nil
        }

        do {
            if fileManager.fileExists(atPath: outputURL.path(percentEncoded: false)) {
                notifyProgress(1, for: mediaID)
                return outputURL
            }

            try cleanupItem(at: tempURL)

            do {
                try await runFFmpegCommand(
                    command: makeCommand(
                        sourceHLSURL: sourceHLSURL,
                        streamMap: StreamMapping.primary,
                        outputURL: tempURL
                    ),
                    mediaID: mediaID,
                    estimatedDuration: estimatedDuration
                )
            } catch let error as ArtworkVideoProcessorError {
                if shouldRetryWithFallback(for: error) {
                    try cleanupItem(at: tempURL)
                    try await runFFmpegCommand(
                        command: makeCommand(
                            sourceHLSURL: sourceHLSURL,
                            streamMap: StreamMapping.fallback,
                            outputURL: tempURL
                        ),
                        mediaID: mediaID,
                        estimatedDuration: estimatedDuration
                    )
                } else {
                    throw error
                }
            }

            guard fileManager.fileExists(atPath: tempURL.path(percentEncoded: false)) else {
                throw ArtworkVideoProcessorError.noOutputProduced
            }

            try commitTemporaryOutput(from: tempURL, to: outputURL)
            notifyProgress(1, for: mediaID)
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

    private func awaitResult(
        for mediaID: String,
        observerID: UUID,
        task: Task<URL, Error>
    ) async throws -> URL {
        try await withTaskCancellationHandler {
            defer {
                Task {
                    await self.removeProgressObserver(for: mediaID, id: observerID)
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
    }

    private func storeActiveSession(_ session: FFmpegSession?, for mediaID: String) {
        activeSessions[mediaID] = session
    }

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
        if let session = activeSessions[mediaID] {
            session.cancel()
        }
    }

    private func notifyProgress(_ progress: Double, for mediaID: String) {
        guard let handlers = progressObservers[mediaID]?.values else {
            return
        }
        for handler in handlers {
            handler(progress)
        }
    }

    private func cachedFileURL(for mediaID: String) throws -> URL {
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

        return cachesURL.appending(path: "\(mediaID).mp4")
    }

    private func temporaryOutputURL(for mediaID: String) throws -> URL {
        let directory = try cachedFileURL(for: mediaID).deletingLastPathComponent()
        return directory.appending(path: "\(mediaID)-\(UUID().uuidString).tmp.mp4")
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

    private func makeCommand(sourceHLSURL: URL, streamMap: String, outputURL: URL) -> String {
        [
            "-protocol_whitelist \(quotedFFmpegArgument("file,http,https,tcp,tls"))",
            "-i \(quotedFFmpegArgument(sourceHLSURL.absoluteString))",
            "-map \(streamMap)",
            "-vf \(quotedFFmpegArgument("scale=1080:-2"))",
            "-c:v mpeg4",
            "-pix_fmt yuv420p",
            "-movflags +faststart",
            quotedFFmpegArgument(outputURL.path(percentEncoded: false))
        ].joined(separator: " ")
    }

    private func shouldRetryWithFallback(for error: ArtworkVideoProcessorError) -> Bool {
        guard case .ffmpegFailure(let message) = error else {
            return false
        }

        let normalized = message.lowercased()
        return normalized.contains("stream map '0:v:8' matches no streams")
            || normalized.contains("stream map '0:v:8'")
            || normalized.contains("matches no streams")
    }

    private func quotedFFmpegArgument(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func loadEstimatedDuration(for sourceHLSURL: URL) async -> Double? {
        let asset = AVURLAsset(url: sourceHLSURL)

        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds
            guard seconds.isFinite, !seconds.isNaN, seconds > 0 else { return nil }
            return seconds
        } catch {
            return nil
        }
    }
}
