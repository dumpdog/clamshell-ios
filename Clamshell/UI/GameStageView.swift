import SwiftUI
import QuartzCore

/// Hosts the running micro-game. Finds the fold, rotates the canvas so the
/// fold is always horizontal for the game, ticks the game loop, and turns
/// thumb touches into stage taps.
struct GameStageView: View {
    @Environment(GameSession.self) private var session
    @Environment(HingeInput.self) private var input

    var body: some View {
        GeometryReader { proxy in
            let folds = FoldRegions.frames(in: proxy)
            let placement = StagePlacement(size: proxy.size, fold: folds.first)
            ZStack {
                TimelineView(.animation) { _ in
                    Canvas { ctx, size in
                        let frame = session.tick(at: CACurrentMediaTime())
                        guard let game = session.current else { return }
                        let placement = StagePlacement(size: size, fold: folds.first)
                        if placement.isRotated {
                            ctx.translateBy(x: size.width, y: 0)
                            ctx.rotate(by: .degrees(90))
                        }
                        game.draw(in: &ctx, stage: placement.layout, frame: frame)
                    }
                }
                ThumbTouchLayer(
                    onDown: { point in input.thumbDown(stageX: placement.stageX(of: point)) },
                    onUp: { input.thumbUp() }
                )
            }
        }
        .ignoresSafeArea()
    }
}

/// Maps the screen onto the canonical stage, where the fold runs horizontally.
struct StagePlacement {
    var layout: StageLayout
    /// True when the real fold is vertical (book pose) and the stage is turned 90°.
    var isRotated: Bool
    private var screenSize: CGSize

    init(size: CGSize, fold: CGRect?) {
        screenSize = size
        // A tall, thin fold region means the fold is vertical, so rotate.
        if let fold, fold.height > fold.width {
            isRotated = true
            // After the rotation, stage (x, y) lands on screen
            // (width - y, x), so the fold sits at width - midX.
            layout = StageLayout(size: CGSize(width: size.height, height: size.width),
                                 foldY: size.width - fold.midX)
        } else {
            isRotated = false
            layout = StageLayout(size: size, foldY: fold?.midY ?? size.height / 2)
        }
    }

    /// 0…1 across the stage for a point in screen space.
    func stageX(of point: CGPoint) -> Double {
        let x = isRotated ? point.y : point.x
        return Double(x / max(layout.size.width, 1))
    }
}
