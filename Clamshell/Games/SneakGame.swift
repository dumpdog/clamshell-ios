import SwiftUI

/// A dragon sleeps in the book. Squeeze the book in a little, then open it
/// back up slowly enough that it doesn't wake. A tension game that uses hinge
/// velocity, all inside the grip band.
final class SneakGame: MicroGame {
    let verb = "SHHH…"
    let hint = "Squeeze it in a little, then open slooowly"
    let duration: Double = 7.5

    private let maxSpeed: Double
    private var squeezedOnce = false
    private var noise: Double = 0

    init(difficulty: Int) {
        // Openness per second. The grip band spans about 70°, so 1.6 is
        // roughly 110°/s.
        maxSpeed = max(0.8, 1.6 - 0.08 * Double(difficulty))
    }

    func update(_ frame: HingeFrame) -> MicroGameOutcome? {
        guard squeezedOnce else {
            if frame.openness < 0.2 { squeezedOnce = true }
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

        let text = squeezedOnce ? "Open it slowly…" : "Squeeze it in a little"
        ctx.label(text, at: CGPoint(x: w / 2, y: h * 0.2), size: 26, color: .brown)
        ctx.meter(noise, in: CGRect(x: w * 0.2, y: h * 0.86, width: w * 0.6, height: 14),
                  color: noise > 0.7 ? .red : .orange)
        ctx.label("NOISE", at: CGPoint(x: w / 2, y: h * 0.82), size: 13, color: .brown)
    }
}
