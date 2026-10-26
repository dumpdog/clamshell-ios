import SwiftUI
import UIKit
import QuartzCore

/// Duo Air Hockey. Lay the Duo flat and fully open: the fold is the center
/// line, and each half of the inner display is one player's side.
struct AirHockeyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var game = AirHockeyGame()

    var body: some View {
        GeometryReader { proxy in
            let table = TableMapping(viewSize: proxy.size, folds: FoldRegions.frames(in: proxy))
            ZStack {
                TimelineView(.animation) { timeline in
                    Canvas { ctx, _ in
                        // All per-frame state is unobserved, so reading the
                        // timeline's date is what makes the canvas redraw.
                        _ = timeline.date
                        game.layout(size: table.size, centerY: table.centerY)
                        game.step(at: CACurrentMediaTime())
                        table.apply(to: &ctx)
                        HockeyRenderer(game: game).draw(in: &ctx)
                    }
                }
                TouchSurface { phase, id, point in
                    let p = table.toTable(point)
                    switch phase {
                    case .began: game.touchBegan(id, at: p)
                    case .moved: game.touchMoved(id, to: p)
                    case .ended: game.touchEnded(id)
                    }
                }
                overlay
            }
        }
        .ignoresSafeArea()
        .background(Color(red: 0.03, green: 0.07, blue: 0.13))
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
    }

    @ViewBuilder
    private var overlay: some View {
        switch game.screen {
        case .choosing:
            chooser
        case .playing:
            VStack {
                HStack {
                    Button { game.backToChoosing() } label: {
                        Image(systemName: "xmark").font(.headline).padding(10)
                    }
                    .buttonStyle(.glass)
                    Spacer()
                }
                Spacer()
            }
            .padding()
        case .finished(let winner):
            finished(winner)
        }
    }

    private var chooser: some View {
        VStack(spacing: 20) {
            Text("DUO AIR HOCKEY")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Lay your Duo flat and fully open. The fold is the center line.")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Picker("CPU difficulty", selection: $game.difficulty) {
                ForEach(HockeyDifficulty.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            Button { game.start(.onePlayer) } label: {
                Label("1 Player vs CPU", systemImage: "person.fill")
                    .font(.title2.bold()).frame(maxWidth: 280).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            Button { game.start(.twoPlayer) } label: {
                Label("2 Players, face to face", systemImage: "person.2.fill")
                    .font(.title2.bold()).frame(maxWidth: 280).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            Text("First to \(AirHockeyGame.winningScore) wins.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Back to Clamshell") { dismiss() }
                .buttonStyle(.glass)
                .padding(.top, 8)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 32))
        .padding()
        .foregroundStyle(.white)
    }

    private func finished(_ winner: HockeySide) -> some View {
        VStack(spacing: 16) {
            Text(winnerText(winner))
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(HockeyRenderer.color(for: winner))
            Text("\(game.bottomScore) – \(game.topScore)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
            Button { game.start(game.mode) } label: {
                Text("Rematch").font(.title2.bold()).frame(maxWidth: 240).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            Button("Change mode") { game.backToChoosing() }
                .buttonStyle(.glass)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 32))
        .foregroundStyle(.white)
    }

    private func winnerText(_ winner: HockeySide) -> String {
        switch (game.mode, winner) {
        case (.onePlayer, .bottom): "You win!"
        case (.onePlayer, .top): "CPU wins"
        case (.twoPlayer, .bottom): "Red wins!"
        case (.twoPlayer, .top): "Blue wins!"
        }
    }
}

// MARK: Screen ↔ table mapping

/// Puts the rink's long axis across the fold, so the fold is the center line
/// and each player gets one half. Uses the same rotation as `GameStageView`.
struct TableMapping {
    var viewSize: CGSize
    var rotated: Bool
    var size: CGSize
    var centerY: CGFloat

    init(viewSize: CGSize, folds: [CGRect]) {
        self.viewSize = viewSize
        let fold = folds.first
        // A tall, thin fold means the fold runs vertically on screen. With no
        // fold (other iPhones, Simulator), run the rink along the long side.
        rotated = fold.map { $0.height > $0.width } ?? (viewSize.width > viewSize.height)
        if rotated {
            size = CGSize(width: viewSize.height, height: viewSize.width)
            // Table (x, y) lands on screen (viewWidth - y, x).
            centerY = fold.map { viewSize.width - $0.midX } ?? size.height / 2
        } else {
            size = viewSize
            centerY = fold?.midY ?? size.height / 2
        }
    }

    func apply(to ctx: inout GraphicsContext) {
        guard rotated else { return }
        ctx.translateBy(x: viewSize.width, y: 0)
        ctx.rotate(by: .degrees(90))
    }

    func toTable(_ p: CGPoint) -> CGPoint {
        rotated ? CGPoint(x: p.y, y: viewSize.width - p.x) : p
    }
}

// MARK: Drawing

@MainActor
struct HockeyRenderer {
    let game: AirHockeyGame

    static func color(for side: HockeySide) -> Color {
        side == .bottom ? Color(red: 1, green: 0.27, blue: 0.3) : Color(red: 0.2, green: 0.6, blue: 1)
    }

    func draw(in ctx: inout GraphicsContext) {
        let size = game.size
        guard size != .zero else { return }
        let w = size.width, h = size.height, cy = game.centerY
        let line = Color.white.opacity(0.25)

        // Rink
        let rink = CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3)
        ctx.fill(Path(roundedRect: rink, cornerRadius: w * 0.08), with: .color(Color(red: 0.06, green: 0.12, blue: 0.22)))
        ctx.stroke(Path(roundedRect: rink, cornerRadius: w * 0.08), with: .color(line), lineWidth: 6)

        // Center line sits right on the fold.
        var center = Path()
        center.move(to: CGPoint(x: 0, y: cy))
        center.addLine(to: CGPoint(x: w, y: cy))
        ctx.stroke(center, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 3, dash: [12, 10]))
        let circle = w * 0.18
        ctx.stroke(Path(ellipseIn: CGRect(x: w / 2 - circle, y: cy - circle, width: circle * 2, height: circle * 2)),
                   with: .color(line), lineWidth: 3)

        // Goals and creases
        let gw = game.goalWidth
        for side in [HockeySide.top, .bottom] {
            let y: CGFloat = side == .top ? 0 : h
            let mouth = CGRect(x: w / 2 - gw / 2, y: side == .top ? 0 : h - 10, width: gw, height: 10)
            ctx.fill(Path(roundedRect: mouth, cornerRadius: 5), with: .color(Self.color(for: side)))
            var crease = Path()
            crease.addArc(center: CGPoint(x: w / 2, y: y), radius: gw * 0.6,
                          startAngle: .degrees(0), endAngle: .degrees(180), clockwise: side == .bottom)
            ctx.stroke(crease, with: .color(Self.color(for: side).opacity(0.4)), lineWidth: 3)
        }

        // Scores, each facing its own player.
        let scoreSize = w * 0.12
        text("\(game.bottomScore)", at: CGPoint(x: w * 0.13, y: cy + scoreSize * 0.9), size: scoreSize,
             color: Self.color(for: .bottom).opacity(0.6), flipped: false, in: ctx)
        text("\(game.topScore)", at: CGPoint(x: w * 0.13, y: cy - scoreSize * 0.9), size: scoreSize,
             color: Self.color(for: .top).opacity(0.6), flipped: true, in: ctx)
        if game.mode == .onePlayer {
            text("CPU · \(game.difficulty.rawValue.uppercased())", at: CGPoint(x: w / 2, y: cy * 0.45), size: w * 0.06,
                 color: .white.opacity(0.15), flipped: false, in: ctx)
        }

        // Pieces
        drawMallet(game.top.pos, side: .top, in: ctx)
        drawMallet(game.bottom.pos, side: .bottom, in: ctx)
        let pr = game.puckRadius
        ctx.fill(Path(ellipseIn: CGRect(x: game.puck.x - pr, y: game.puck.y - pr, width: pr * 2, height: pr * 2)),
                 with: .color(Color(white: 0.92)))
        ctx.stroke(Path(ellipseIn: CGRect(x: game.puck.x - pr * 0.6, y: game.puck.y - pr * 0.6, width: pr * 1.2, height: pr * 1.2)),
                   with: .color(.black.opacity(0.25)), lineWidth: 2)

        // Goal banner, shown to both players.
        if let scorer = game.lastScorer {
            let color = Self.color(for: scorer)
            text("GOAL!", at: CGPoint(x: w / 2, y: cy + (h - cy) / 2), size: w * 0.14,
                 color: color, flipped: false, in: ctx)
            if game.mode == .twoPlayer {
                text("GOAL!", at: CGPoint(x: w / 2, y: cy / 2), size: w * 0.14,
                     color: color, flipped: true, in: ctx)
            }
        }
    }

    private func drawMallet(_ p: CGPoint, side: HockeySide, in ctx: GraphicsContext) {
        let r = game.malletRadius
        let color = Self.color(for: side)
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(color))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.5, y: p.y - r * 0.5, width: r, height: r)),
                 with: .color(.black.opacity(0.25)))
        ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                   with: .color(.white.opacity(0.5)), lineWidth: 2)
    }

    private func text(_ s: String, at p: CGPoint, size: CGFloat, color: Color, flipped: Bool, in ctx: GraphicsContext) {
        var c = ctx
        c.translateBy(x: p.x, y: p.y)
        if flipped { c.rotate(by: .degrees(180)) }
        c.label(s, at: .zero, size: size, color: color)
    }
}

// MARK: Multitouch

/// SwiftUI gestures track one finger; air hockey needs one per player, so a
/// plain UIView reports every touch.
struct TouchSurface: UIViewRepresentable {
    enum Phase { case began, moved, ended }

    var onTouch: @MainActor (Phase, ObjectIdentifier, CGPoint) -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.onTouch = onTouch
    }

    final class TouchView: UIView {
        var onTouch: (@MainActor (Phase, ObjectIdentifier, CGPoint) -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(touches, .began)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(touches, .moved)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(touches, .ended)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(touches, .ended)
        }

        private func report(_ touches: Set<UITouch>, _ phase: Phase) {
            for touch in touches {
                onTouch?(phase, ObjectIdentifier(touch), touch.location(in: self))
            }
        }
    }
}
