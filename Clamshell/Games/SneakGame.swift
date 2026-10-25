import SwiftUI

/// A dragon sleeps in the book. Close it, then open it all the way slowly
/// enough that it doesn't wake up. A tension game that uses hinge velocity.
final class SneakGame: MicroGame {
    let verb = "SHHH…"
    let hint = "Close the book, then open it slooowly"
    let duration: Double = 7.5

    private let maxSpeed: Double
    private var closedOnce = false
    private var noise: Double = 0

    init(difficulty: Int) {
        maxSpeed = max(0.6, 1.4 - 0.1 * Double(difficulty))
    }

    func update(_ frame: HingeFrame) -> MicroGameOutcome? {
        guard closedOnce else {
            if frame.openness < 0.15 { closedOnce = true }
            return nil
        }
        noise = max(0, frame.velocity) / maxSpeed
        if noise > 1 { return .lost(reason: "You woke the dragon! 🔥") }
        if frame.openness > 0.9 { return .won }
        return nil
    }

    func timedOut() -> MicroGameOutcome { .lost(reason: "The library closed") }

    func draw(in ctx: inout GraphicsContext, stage: StageLayout, frame: HingeFrame) {
        let w = stage.size.width, h = stage.size.height
        ctx.fill(Path(stage.top), with: .color(Color(red: 0.95, green: 0.92, blue: 0.84)))
        ctx.fill(Path(stage.bottom), with: .color(Color(red: 0.9, green: 0.86, blue: 0.76)))
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: 0, y: stage.foldY))
            p.addLine(to: CGPoint(x: w, y: stage.foldY))
        }, with: .color(.brown.opacity(0.6)), lineWidth: 4)

        let awake = noise > 0.7
        ctx.emoji(awake ? "🐲" : "🐉", at: CGPoint(x: w / 2, y: stage.foldY), size: min(w, h) * 0.22)
        if !awake {
            ctx.emoji("💤", at: CGPoint(x: w * 0.62, y: stage.foldY - h * 0.14), size: 40)
        }

        let text = closedOnce ? "Open it slowly…" : "Close the book first"
        ctx.label(text, at: CGPoint(x: w / 2, y: h * 0.2), size: 26, color: .brown)
        ctx.meter(noise, in: CGRect(x: w * 0.2, y: h * 0.86, width: w * 0.6, height: 14),
                  color: noise > 0.7 ? .red : .orange)
        ctx.label("NOISE", at: CGPoint(x: w / 2, y: h * 0.82), size: 13, color: .brown)
    }
}
