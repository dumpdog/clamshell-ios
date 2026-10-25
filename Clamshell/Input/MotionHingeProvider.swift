import CoreMotion

/// "Tilt mode": fakes a hinge on any iPhone. Lying flat counts as closed and
/// standing upright toward you counts as open. This lets non-Duo friends play
/// the same games, which matters for virality: every share reaches people
/// without a Duo.
@MainActor
final class MotionHingeProvider {
    private let manager = CMMotionManager()

    func start(_ handler: @escaping @MainActor (Double) -> Void) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let openness = min(max(motion.attitude.pitch / (.pi / 2), 0), 1)
            MainActor.assumeIsolated { handler(openness) }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
