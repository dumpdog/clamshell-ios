import SwiftUI

struct MenuView: View {
    @Environment(GameSession.self) private var session
    @Environment(HingeInput.self) private var hinge
    @State private var showAirHockey = false

    var body: some View {
        @Bindable var hinge = hinge
        VStack(spacing: 24) {
            Spacer()
            Text("CLAMSHELL")
                .font(.system(size: 52, weight: .black, design: .rounded))
            Text("Tiny games you play by folding your phone.")
                .font(.headline)
                .foregroundStyle(.secondary)

            OpennessGauge(openness: hinge.openness)
                .frame(width: 140, height: 140)

            Button {
                session.start()
            } label: {
                Text("Play").font(.title.bold()).frame(maxWidth: 240).padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)

            Button {
                showAirHockey = true
            } label: {
                Label("Duo Air Hockey", systemImage: "circle.circle.fill")
                    .font(.title3.bold()).frame(maxWidth: 240).padding(.vertical, 4)
            }
            .buttonStyle(.glass)

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
        .fullScreenCover(isPresented: $showAirHockey) {
            AirHockeyView()
        }
    }

    private var inputCaption: String {
        switch hinge.source {
        case .hinge: hinge.isHingeAvailable ? "Fold detected. Your phone is the controller." : "No hinge found on this device."
        case .tilt: "No fold? Tilt the phone up and down instead."
        case .manual: "Slider mode, for the Simulator and debugging."
        }
    }
}

/// Two "panels" hinged at the bottom that mirror the current fold.
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
                .rotation3DEffect(.degrees((1 - openness) * 170),
                                  axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.4)
        }
        .animation(.interactiveSpring, value: openness)
    }
}
