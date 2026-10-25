import Foundation
import Observation
import QuartzCore

/// One sample of "how open is the phone", handed to a micro-game every frame.
struct HingeFrame {
    /// 0 = closed, 1 = flat. Already calibrated and clamped.
    var openness: Double
    /// Change in openness per second, smoothed. Positive while opening.
    var velocity: Double
    /// Seconds since the previous frame.
    var dt: Double
    /// Seconds since the current micro-game started.
    var elapsed: Double
}

/// The single source of truth for fold input. Games never talk to the hinge
/// API directly, so the same game plays with the real hinge, phone tilt
/// (any iPhone), or an on-screen slider (Simulator / debugging).
@MainActor
@Observable
final class HingeInput {
    enum Source: String, CaseIterable, Identifiable {
        case hinge = "Fold"
        case tilt = "Tilt"
        case manual = "Slider"
        var id: String { rawValue }
    }

    var source: Source = .tilt {
        didSet { if oldValue != source { sourceChanged() } }
    }

    private(set) var isHingeAvailable = false
    private(set) var openness: Double = 1
    private(set) var velocity: Double = 0

    /// Hinge angles (degrees) that map to openness 0 and 1. The hinge
    /// convention isn't documented beyond `Angle`, so these widen
    /// automatically as new extremes are seen. Check them on real hardware.
    private(set) var closedAngle: Double = 5
    private(set) var flatAngle: Double = 175

    @ObservationIgnored private var lastSampleTime: CFTimeInterval?
    @ObservationIgnored private var lastFrameTime: CFTimeInterval?
    private let motion = MotionHingeProvider()

    init() {
        sourceChanged()
    }

    // MARK: Feeding samples

    /// Called by the `trackHinge` modifier whenever the system reports a hinge change.
    func hingeDidChange(angleDegrees: Double?) {
        guard let angle = angleDegrees else {
            isHingeAvailable = false
            return
        }
        if !isHingeAvailable {
            isHingeAvailable = true
            source = .hinge // A real fold beats every fallback.
        }
        closedAngle = min(closedAngle, angle)
        flatAngle = max(flatAngle, angle)
        guard source == .hinge else { return }
        ingest((angle - closedAngle) / max(flatAngle - closedAngle, 1))
    }

    func setManual(_ value: Double) {
        guard source == .manual else { return }
        ingest(value)
    }

    func ingest(_ raw: Double, at time: CFTimeInterval = CACurrentMediaTime()) {
        let value = min(max(raw, 0), 1)
        if let last = lastSampleTime, time > last {
            let dt = time - last
            let instant = (value - openness) / dt
            // About 80 ms of smoothing: enough to kill tilt jitter but still
            // catch a fast "chomp".
            velocity += (instant - velocity) * min(1, dt * 12)
        }
        openness = value
        lastSampleTime = time
    }

    // MARK: Reading frames

    /// Snapshot for the game loop. Hinge events only arrive on change, so a
    /// phone held still reports zero velocity once samples go quiet.
    func frame(at time: CFTimeInterval, elapsed: Double) -> HingeFrame {
        let dt = lastFrameTime.map { min(max(time - $0, 0), 1.0 / 20.0) } ?? 0
        lastFrameTime = time
        var v = velocity
        if let last = lastSampleTime, time - last > 0.12 { v = 0 }
        return HingeFrame(openness: openness, velocity: v, dt: dt, elapsed: elapsed)
    }

    func resetClock() {
        lastFrameTime = nil
    }

    private func sourceChanged() {
        velocity = 0
        lastSampleTime = nil
        if source == .tilt {
            motion.start { [weak self] value in self?.ingest(value) }
        } else {
            motion.stop()
        }
    }
}
