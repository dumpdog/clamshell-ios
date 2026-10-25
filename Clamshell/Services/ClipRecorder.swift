import ReplayKit

/// Keeps a rolling buffer of the screen during a run, so a great (or
/// terrible) moment can be exported after it happens. This is the core of
/// the viral loop. ReplayKit asks for permission the first time.
@MainActor
final class ClipRecorder {
    static let shared = ClipRecorder()

    private let recorder = RPScreenRecorder.shared()
    private(set) var isBuffering = false

    func startBuffering() {
        guard recorder.isAvailable, !isBuffering else { return }
        recorder.startClipBuffering { [weak self] error in
            Task { @MainActor in self?.isBuffering = (error == nil) }
        }
    }

    func stopBuffering() {
        guard isBuffering else { return }
        isBuffering = false
        recorder.stopClipBuffering { _ in }
    }

    func exportClip(seconds: TimeInterval = 15) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("clamshell-\(UUID().uuidString).mp4")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            recorder.exportClip(to: url, duration: seconds) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        return url
    }
}
