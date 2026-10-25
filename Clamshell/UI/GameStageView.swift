import SwiftUI
import QuartzCore

/// Hosts the running micro-game. Finds the fold, rotates the canvas so the
/// fold is always horizontal for the game, and ticks the game loop.
struct GameStageView: View {
    @Environment(GameSession.self) private var session

    var body: some View {
        GeometryReader { proxy in
            let folds = FoldRegions.frames(in: proxy)
            TimelineView(.animation) { _ in
                Canvas { ctx, size in
                    let frame = session.tick(at: CACurrentMediaTime())
                    guard let game = session.current else { return }

                    // A tall, thin fold region means the fold is vertical
                    // (book pose), so rotate into the canonical stage.
                    let fold = folds.first
                    let vertical = fold.map { $0.height > $0.width } ?? false
                    var stageSize = size
                    var foldY = fold?.midY ?? size.height / 2
                    if vertical, let fold {
                        stageSize = CGSize(width: size.height, height: size.width)
                        // After this transform, stage (x, y) lands on screen
                        // (width - y, x), so the fold sits at width - midX.
                        foldY = size.width - fold.midX
                        ctx.translateBy(x: size.width, y: 0)
                        ctx.rotate(by: .degrees(90))
                    }
                    game.draw(in: &ctx, stage: StageLayout(size: stageSize, foldY: foldY), frame: frame)
                }
            }
        }
        .ignoresSafeArea()
    }
}
