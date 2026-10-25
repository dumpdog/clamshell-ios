import Foundation
import Observation
import QuartzCore

/// One sample of input, handed to a micro-game every frame: how far the
/// hinge sits inside the grip band, plus any thumb taps since the last frame.
struct HingeFrame {
    /// 0 = squeezed to the low end of the grip band, 1 = its open end.
    /// Already calibrated and clamped. The phone never has to close.
    var openness: Double
    /// Change in openness per second, smoothed. Positive while opening.
    var velocity: Double
    /// Seconds since the previous frame.
    var dt: Double
    /// Seconds since the current micro-game started.
    var elapsed: Double
    /// Thumb taps that started since the previous frame, oldest first.
    var taps: [ThumbSide] = []
    /// True while at least one thumb is on the screen.
    var isPressing = false
}

/// Which thumb tapped, split down the middle of the stage.
enum ThumbSide {
    case left, right
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

    /// The grip band: hinge angles (degrees) that map to openness 0 and 1.
    /// Played held open sideways like a handheld console, so nothing below
    /// about 95° is ever asked for. Fully closing the phone to play proved
    /// impractical on a real Duo. Tune these on hardware.
    nonisolated static let gripLowAngle: Double = 95
    nonisolated static let gripHighAngle: Double = 165

    /// Last raw hinge angle, shown on the menu for tuning the grip band.
    private(set) var angleDegrees: Double?

    @ObservationIgnored private var lastSampleTime: CFTimeInterval?
    @ObservationIgnored private var lastFrameTime: CFTimeInterval?
    @ObservationIgnored private var pendingTaps: [ThumbSide] = []
    @ObservationIgnored private var touchCount = 0
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
        self.angleDegrees = angle
        guard source == .hinge else { return }
        ingest((angle - Self.gripLowAngle) / (Self.gripHighAngle - Self.gripLowAngle))
    }

    /// A thumb landed. `stageX` is 0…1 across the canonical stage.
    func thumbDown(stageX: Double) {
        pendingTaps.append(stageX < 0.5 ? .left : .right)
        touchCount += 1
    }

    func thumbUp() {
        touchCount = max(0, touchCount - 1)
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
        let taps = pendingTaps
        pendingTaps.removeAll()
        return HingeFrame(openness: openness, velocity: v, dt: dt, elapsed: elapsed,
                          taps: taps, isPressing: touchCount > 0)
    }

    func resetClock() {
        lastFrameTime = nil
        pendingTaps.removeAll()
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
