import SwiftUI

/// Drum your thumbs, left, right, left, right, to pump up the balloon.
/// Tapping the same side twice in a row doesn't count, so it rewards rhythm
/// over mashing.
final class BalloonGame: MicroGame {
    let verb = "PUMP!"
    let hint = "Tap left, right, left, right!"
    let duration: Double

    private let pumpsNeeded: Int
    private var pumps = 0
    private var lastSide: ThumbSide?

    init(difficulty: Int) {
        pumpsNeeded = 4 + difficulty
        duration = 2.0 + 0.55 * Double(4 + difficulty)
    }

    func update(_ frame: HingeFrame) -> MicroGameOutcome? {
        for side in frame.taps where side != lastSide {
            lastSide = side
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
        let radius = min(w, stage.foldY) * (0.12 + 0.3 * fill)
        let center = CGPoint(x: w / 2, y: stage.foldY - radius - 12)
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 1.1,
                                        width: radius * 2, height: radius * 2.2)),
                 with: .color(.red))
        ctx.label("\(pumps)/\(pumpsNeeded)", at: center, size: max(18, radius * 0.4))

        // Thumb pads in the bottom corners. The one to hit next glows.
        let padSize = min(w * 0.3, (h - stage.foldY) * 0.7)
        let padY = stage.foldY + (h - stage.foldY - padSize) / 2
        let pads: [(ThumbSide, CGFloat)] = [(.left, w * 0.04), (.right, w * 0.96 - padSize)]
        for (side, x) in pads {
            let pad = CGRect(x: x, y: padY, width: padSize, height: padSize)
            let next = lastSide != side
            ctx.fill(Path(roundedRect: pad, cornerRadius: padSize * 0.25),
                     with: .color(.white.opacity(next ? 0.55 : 0.18)))
            ctx.label(side == .left ? "L" : "R", at: CGPoint(x: pad.midX, y: pad.midY),
                      size: padSize * 0.35, color: .black.opacity(next ? 0.7 : 0.3))
        }

        // Pump plunger between the pads, pushed down by whichever thumb went last.
        let barrel = CGRect(x: w / 2 - 30, y: stage.foldY + 20, width: 60, height: h - stage.foldY - 40)
        ctx.fill(Path(roundedRect: barrel, cornerRadius: 10), with: .color(.gray))
        let handleY = barrel.minY + barrel.height * (pumps % 2 == 0 ? 0 : 0.8)
        ctx.fill(Path(roundedRect: CGRect(x: w / 2 - 70, y: handleY, width: 140, height: 18), cornerRadius: 9),
                 with: .color(.black))
    }
}
