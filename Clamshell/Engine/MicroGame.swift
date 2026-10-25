import SwiftUI

enum MicroGameOutcome {
    case won
    case lost(reason: String)
}

/// A 3–8 second game, WarioWare style, played by folding the phone.
///
/// Games draw in a canonical stage where the fold always runs horizontally
/// through `stage.foldY` (the "DS / laptop" pose). `GameStageView` rotates
/// the canvas when the real fold is vertical, so games never handle it.
@MainActor
protocol MicroGame: AnyObject {
    /// Shown big for under a second before play starts, like "CHOMP!".
    var verb: String { get }
    /// One short line telling the player what to do with the fold.
    var hint: String { get }
    /// Seconds before `timedOut()` decides the result.
    var duration: Double { get }

    /// Advance one frame. Return nil to keep playing.
    func update(_ frame: HingeFrame) -> MicroGameOutcome?
    func timedOut() -> MicroGameOutcome
    func draw(in ctx: inout GraphicsContext, stage: StageLayout, frame: HingeFrame)
}

extension MicroGame {
    func timedOut() -> MicroGameOutcome { .lost(reason: "Too slow!") }
}

/// Geometry handed to games every frame.
struct StageLayout {
    var size: CGSize
    var foldY: CGFloat

    var top: CGRect { CGRect(x: 0, y: 0, width: size.width, height: foldY) }
    var bottom: CGRect { CGRect(x: 0, y: foldY, width: size.width, height: size.height - foldY) }

    func point(_ nx: Double, _ ny: Double) -> CGPoint {
        CGPoint(x: size.width * nx, y: size.height * ny)
    }
}

/// Every game in the rotation. Add yours here.
enum MicroGameCatalog {
    static let factories: [(Int) -> any MicroGame] = [
        { ChompGame(difficulty: $0) },
        { DrawbridgeGame(difficulty: $0) },
        { BalloonGame(difficulty: $0) },
        { SneakGame(difficulty: $0) },
    ]
}

// MARK: Drawing helpers shared by games

extension GraphicsContext {
    func emoji(_ s: String, at p: CGPoint, size: CGFloat) {
        draw(Text(s).font(.system(size: size)), at: p, anchor: .center)
    }

    func label(_ s: String, at p: CGPoint, size: CGFloat, color: Color = .white) {
        draw(Text(s).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(color),
             at: p, anchor: .center)
    }

    func meter(_ value: Double, in rect: CGRect, color: Color) {
        fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(.white.opacity(0.15)))
        var filled = rect
        filled.size.width *= min(max(value, 0), 1)
        fill(Path(roundedRect: filled, cornerRadius: rect.height / 2), with: .color(color))
    }
}
