import SwiftUI
import QuartzCore

struct HUDView: View {
    @Environment(GameSession.self) private var session
    @Environment(HingeInput.self) private var hinge

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { session.quit() } label: {
                    Image(systemName: "xmark").font(.headline).padding(10)
                }
                .buttonStyle(.glass)
                Spacer()
                Text(String(repeating: "❤️", count: max(session.lives, 0)))
                Spacer()
                Text("\(session.score)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
            }
            TimelineView(.animation) { _ in
                ProgressView(value: session.timeRemaining(at: CACurrentMediaTime()))
                    .tint(.white)
            }
            Spacer()
            centerBanner
            Spacer()
            if hinge.source == .manual {
                ManualHingeSlider()
            }
        }
        .padding()
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var centerBanner: some View {
        switch session.phase {
        case .intro:
            VStack(spacing: 8) {
                Text(session.currentVerb)
                    .font(.system(size: 64, weight: .black, design: .rounded))
                Text(session.currentHint).font(.headline)
            }
            .shadow(radius: 8)
            .transition(.scale.combined(with: .opacity))
        case .outcome(let won, let message):
            Text(message)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(won ? .green : .red)
                .shadow(radius: 8)
                .transition(.scale)
        default:
            EmptyView()
        }
    }
}

/// On-screen fold for the Simulator and for debugging.
struct ManualHingeSlider: View {
    @Environment(HingeInput.self) private var hinge

    var body: some View {
        HStack {
            Image(systemName: "rectangle.portrait.on.rectangle.portrait")
            Slider(value: Binding(get: { hinge.openness }, set: { hinge.setManual($0) }), in: 0...1)
            Image(systemName: "rectangle.split.2x1")
        }
        .padding(12)
        .glassEffect()
    }
}
