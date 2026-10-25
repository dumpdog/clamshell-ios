import SwiftUI

struct RootView: View {
    @Environment(GameSession.self) private var session

    var body: some View {
        ZStack {
            switch session.phase {
            case .menu:
                MenuView()
                    .transition(.opacity)
            case .gameOver:
                GameOverView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .intro, .playing, .outcome:
                GameStageView()
                    .overlay { HUDView() }
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: session.phase)
    }
}
