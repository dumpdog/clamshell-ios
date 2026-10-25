import SwiftUI

/// A monster lives on the crease. Tap with either thumb to bite when the
/// snack is between its jaws. The jaws breathe with the hinge, but biting
/// is a tap: snapping a real phone shut was too slow and too much effort.
final class ChompGame: MicroGame {
    let verb = "CHOMP!"
    let hint = "Tap to bite when the snack is in its mouth"
    let duration: Double

    private let speed: Double
    private let zoneHalfWidth: Double
    private let snack = ["🍔", "🍩", "🍕", "🌮", "🍎", "🧁"].randomElement()!
    private var snackX = -0.1
    private var chomped = false

    init(difficulty: Int) {
        speed = 0.28 + 0.05 * Double(difficulty)
        zoneHalfWidth = max(0.06, 0.12 - 0.01 * Double(difficulty))
        duration = 1.2 / speed + 0.2
    }

    func update(_ frame: HingeFrame) -> MicroGameOutcome? {
        snackX += speed * frame.dt
        if !frame.taps.isEmpty {
            chomped = true
            Haptics.tick()
            return abs(snackX - 0.5) < zoneHalfWidth ? .won : .lost(reason: "Chomped thin air")
        }
        if snackX > 1.1 { return .lost(reason: "It got away!") }
        return nil
    }

    func timedOut() -> MicroGameOutcome { .lost(reason: "It got away!") }

    func draw(in ctx: inout GraphicsContext, stage: StageLayout, frame: HingeFrame) {
        let w = stage.size.width, h = stage.size.height
        ctx.fill(Path(CGRect(origin: .zero, size: stage.size)),
                 with: .linearGradient(Gradient(colors: [.indigo, .purple]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

        // Bite zone guide on the fold line.
        let zone = CGRect(x: w * (0.5 - zoneHalfWidth), y: stage.foldY - 3,
                          width: w * zoneHalfWidth * 2, height: 6)
        ctx.fill(Path(roundedRect: zone, cornerRadius: 3), with: .color(.yellow.opacity(0.5)))

        if !chomped {
            ctx.emoji(snack, at: CGPoint(x: w * snackX, y: stage.foldY), size: min(w, h) * 0.14)
        }

        // Jaws hang open, breathing a little with the hinge, and slam shut on a bite.
        let gap = chomped ? 0 : h * (0.2 + 0.08 * frame.openness)
        let jawWidth = w * 0.46
        let jawHeight = h * 0.22
        let x = (w - jawWidth) / 2
        let upper = CGRect(x: x, y: stage.foldY - gap / 2 - jawHeight, width: jawWidth, height: jawHeight)
        let lower = CGRect(x: x, y: stage.foldY + gap / 2, width: jawWidth, height: jawHeight)
        let green = Color(red: 0.35, green: 0.85, blue: 0.4)
        ctx.fill(Path(roundedRect: upper, cornerRadius: 28), with: .color(green))
        ctx.fill(Path(roundedRect: lower, cornerRadius: 28), with: .color(green))

        // Teeth.
        let teeth = 6
        let toothW = jawWidth / CGFloat(teeth)
        for i in 0..<teeth {
            let tx = x + CGFloat(i) * toothW
            var top = Path()
            top.move(to: CGPoint(x: tx, y: upper.maxY))
            top.addLine(to: CGPoint(x: tx + toothW, y: upper.maxY))
            top.addLine(to: CGPoint(x: tx + toothW / 2, y: upper.maxY + toothW * 0.6))
            ctx.fill(top, with: .color(.white))
            var bottom = Path()
            bottom.move(to: CGPoint(x: tx, y: lower.minY))
            bottom.addLine(to: CGPoint(x: tx + toothW, y: lower.minY))
            bottom.addLine(to: CGPoint(x: tx + toothW / 2, y: lower.minY - toothW * 0.6))
            ctx.fill(bottom, with: .color(.white))
        }
        // Eyes.
        ctx.emoji("👀", at: CGPoint(x: w / 2, y: upper.minY + jawHeight * 0.35), size: jawHeight * 0.45)
    }
}
