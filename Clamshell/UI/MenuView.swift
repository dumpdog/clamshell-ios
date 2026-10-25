import SwiftUI

struct MenuView: View {
    @Environment(GameSession.self) private var session
    @Environment(HingeInput.self) private var hinge

    var body: some View {
        @Bindable var hinge = hinge
        VStack(spacing: 24) {
            Spacer()
            Text("CLAMSHELL")
                .font(.system(size: 52, weight: .black, design: .rounded))
            Text("Tiny games for your open Duo. Hold it sideways, thumbs on the bottom half.")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            OpennessGauge(openness: hinge.openness)
                .frame(width: 140, height: 140)

            Button {
                session.start()
            } label: {
                Text("Play").font(.title.bold()).frame(maxWidth: 240).padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)

            if session.bestScore > 0 {
                Text("Best: \(session.bestScore)").font(.headline)
            }

            Spacer()

            VStack(spacing: 8) {
                Picker("Input", selection: $hinge.source) {
                    ForEach(HingeInput.Source.allCases) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                Text(inputCaption).font(.footnote).foregroundStyle(.secondary)
                if hinge.source == .manual {
                    ManualHingeSlider()
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var inputCaption: String {
        switch hinge.source {
        case .hinge:
            if let angle = hinge.angleDegrees {
                return "Hinge at \(Int(angle.rounded()))°. Games use \(Int(HingeInput.gripLowAngle))° to \(Int(HingeInput.gripHighAngle))°, so you never close it."
            }
            return "No hinge found on this device."
        case .tilt: return "No fold? Tilt the phone up and down instead."
        case .manual: return "Slider mode, for the Simulator and debugging."
        }
    }
}

/// Two "panels" hinged at the bottom that mirror the hinge across the grip band.
struct OpennessGauge: View {
    var openness: Double

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.tint.opacity(0.35))
                .frame(width: 70, height: 110)
            RoundedRectangle(cornerRadius: 12)
                .fill(.tint)
                .frame(width: 70, height: 110)
                .rotation3DEffect(.degrees(180 - HingeInput.gripLowAngle - openness * (HingeInput.gripHighAngle - HingeInput.gripLowAngle)),
                                  axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.4)
        }
        .animation(.interactiveSpring, value: openness)
    }
}
