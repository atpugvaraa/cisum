import Foundation

@MainActor
public final class DebouncedWorkScheduler {
    private let delay: Duration
    private var task: Task<Void, Never>?

    public init(delay: Duration) {
        self.delay = delay
    }

    public func schedule(_ action: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}