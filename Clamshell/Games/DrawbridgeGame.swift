import SwiftUI

/// Hold the fold at exactly the right angle so the boat can pass.
/// Rewards fine control, and shows off that the hinge is analog.
final class DrawbridgeGame: MicroGame {
    let verb = "HOLD IT!"
    let hint = "Match the bridge to the ghost and hold steady"
    let duration: Double = 5

    private let target: Double
    private let tolerance: Double
    private let holdNeeded: Double
    private var held: Double = 0

    init(difficulty: Int) {
        target = Double.random(in: 0.35...0.75)
        tolerance = max(0.05, 0.12 - 0.01 * Double(difficulty))
        holdNeeded = 1.2 + 0.1 * Double(difficulty)
    }

    func update(_ frame: HingeFrame) -> MicroGameOutcome? {
        if abs(frame.openness - target) < tolerance {
            held += frame.dt
            if held >= holdNeeded { return .won }
        } else {
            held = max(0, held - frame.dt * 0.5)
        }
        return nil
    }

    func timedOut() -> MicroGameOutcome { .lost(reason: "The boat crashed") }

    func draw(in ctx: inout GraphicsContext, stage: StageLayout, frame: HingeFrame) {
        let w = stage.size.width, h = stage.size.height
        ctx.fill(Path(stage.top), with: .color(Color(red: 0.55, green: 0.78, blue: 0.98)))
        ctx.fill(Path(stage.bottom), with: .color(Color(red: 0.1, green: 0.35, blue: 0.7)))

        let pivot = CGPoint(x: w * 0.3, y: stage.foldY)
        let length = w * 0.4

        func deck(_ openness: Double) -> Path {
            let angle = Angle.degrees(-openness * 85)
            var p = Path()
            p.move(to: pivot)
            p.addLine(to: CGPoint(x: pivot.x + cos(angle.radians) * length,
                                  y: pivot.y + sin(angle.radians) * length))
            return p
        }

        ctx.stroke(deck(target), with: .color(.white.opacity(0.35)),
                   style: StrokeStyle(lineWidth: 18, lineCap: .round, dash: [10, 12]))
        let onTarget = abs(frame.openness - target) < tolerance
        ctx.stroke(deck(frame.openness), with: .color(onTarget ? .green : .orange),
                   style: StrokeStyle(lineWidth: 18, lineCap: .round))
        ctx.emoji("🏰", at: CGPoint(x: pivot.x - 40, y: stage.foldY - 30), size: 56)

        // Boat sails in as time runs out.
        let progress = min(frame.elapsed / duration, 1)
        ctx.emoji("⛵️", at: CGPoint(x: w * (1.05 - progress * 0.5), y: stage.foldY + h * 0.08), size: 54)

        ctx.meter(held / holdNeeded,
                  in: CGRect(x: w * 0.2, y: h * 0.88, width: w * 0.6, height: 14), color: .green)
    }
}
