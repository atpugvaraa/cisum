import AVFoundation

extension AVPlayerItem {
    /// An `AsyncStream` that emits the item's `status` on each KVO change,
    /// then finishes once `.readyToPlay` or `.failed` is reached.
    ///
    /// This lets callers observe status without relying on a bare KVO block
    /// that can fire on arbitrary threads. The stream is finite — it terminates
    /// automatically after the terminal status, so `for await` loops exit cleanly.
    var statusStream: AsyncStream<AVPlayerItem.Status> {
        AsyncStream { continuation in
            let observer = observe(\.status, options: [.initial, .new]) { item, _ in
                continuation.yield(item.status)
                if item.status == .readyToPlay || item.status == .failed {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in observer.invalidate() }
        }
    }
}
