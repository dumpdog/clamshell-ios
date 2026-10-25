import SwiftUI

/// Pump the fold like an accordion bellows to blow up the balloon.
/// The frantic flapping is the funniest thing to film from across the room.
final class BalloonGame: MicroGame {
    let verb = "PUMP!"
    let hint = "Fold and unfold, fast!"
    let duration: Double

    private let pumpsNeeded: Int
    private var pumps = 0
    private var primed = false

    init(difficulty: Int) {
        pumpsNeeded = 4 + difficulty
        duration = 2.0 + 0.55 * Double(4 + difficulty)
    }

    func update(_ frame: HingeFrame) -> MicroGameOutcome? {
        if frame.openness < 0.3 { primed = true }
        if primed, frame.openness > 0.7 {
            primed = false
            pumps += 1
            Haptics.tick()
            if pumps >= pumpsNeeded { return .won }
        }
        return nil
    }

    func timedOut() -> MicroGameOutcome { .lost(reason: "Not enough air") }

    func draw(in ctx: inout GraphicsContext, stage: StageLayout, frame: HingeFrame) {
        let w = stage.size.width, h = stage.size.height
        ctx.fill(Path(CGRect(origin: .zero, size: stage.size)), with: .color(Color(red: 0.98, green: 0.85, blue: 0.4)))

        let fill = Double(pumps) / Double(pumpsNeeded)
        let radius = min(w, stage.foldY) * (0.12 + 0.3 * fill) * (1 + 0.04 * frame.openness)
        let center = CGPoint(x: w / 2, y: stage.foldY - radius - 12)
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 1.1,
                                        width: radius * 2, height: radius * 2.2)),
                 with: .color(.red))
        ctx.label("\(pumps)/\(pumpsNeeded)", at: center, size: max(18, radius * 0.4))

        // Pump plunger in the bottom half tracks the fold.
        let barrel = CGRect(x: w / 2 - 30, y: stage.foldY + 20, width: 60, height: h - stage.foldY - 40)
        ctx.fill(Path(roundedRect: barrel, cornerRadius: 10), with: .color(.gray))
        let handleY = barrel.minY + barrel.height * (1 - frame.openness) * 0.8
        ctx.fill(Path(roundedRect: CGRect(x: w / 2 - 70, y: handleY, width: 140, height: 18), cornerRadius: 9),
                 with: .color(.black))
    }
}
