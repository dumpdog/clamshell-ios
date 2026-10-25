import GameKit

/// Leaderboards. Needs the Game Center capability and a leaderboard with
/// this ID in App Store Connect. Until then, calls fail quietly.
@MainActor
final class GameCenterService {
    static let shared = GameCenterService()
    static let leaderboardID = "clamshell.highscore"

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { _, error in
            // A sign-in view controller can be passed here; present it from a
            // settings screen later instead of interrupting the first launch.
            if let error { print("Game Center unavailable: \(error.localizedDescription)") }
        }
    }

    func submit(score: Int) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [Self.leaderboardID]) { _ in }
    }
}
