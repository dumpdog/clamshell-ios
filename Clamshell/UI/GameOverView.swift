import SwiftUI

struct GameOverView: View {
    @Environment(GameSession.self) private var session

    private enum ClipState {
        case idle, exporting, ready(URL), failed(String)
    }

    @State private var clip: ClipState = .idle

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(session.isNewBest ? "NEW BEST!" : "GAME OVER")
                .font(.system(size: 44, weight: .black, design: .rounded))
            Text("\(session.score)")
                .font(.system(size: 96, weight: .black, design: .rounded))
            Text("Best \(session.bestScore)").font(.headline).foregroundStyle(.secondary)
            Spacer()

            clipButton

            Button {
                clip = .idle
                session.start()
            } label: {
                Text("Play again").font(.title2.bold()).frame(maxWidth: 260).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)

            Button("Menu") { session.backToMenu() }
                .buttonStyle(.glass)
        }
        .padding()
    }

    /// The growth loop: one tap turns the last 15 seconds into a shareable clip.
    @ViewBuilder
    private var clipButton: some View {
        switch clip {
        case .idle:
            Button {
                clip = .exporting
                Task {
                    do { clip = .ready(try await ClipRecorder.shared.exportClip()) }
                    catch { clip = .failed(error.localizedDescription) }
                }
            } label: {
                Label("Clip the last 15s", systemImage: "film.stack")
                    .frame(maxWidth: 260).padding(.vertical, 6)
            }
            .buttonStyle(.glass)
        case .exporting:
            ProgressView("Saving clip…")
        case .ready(let url):
            ShareLink(item: url, message: Text("I folded my phone for this. #Clamshell")) {
                Label("Share clip", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: 260).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
        case .failed(let message):
            Text("Couldn't save clip: \(message)").font(.footnote).foregroundStyle(.red)
        }
    }
}
