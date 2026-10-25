import Foundation
import Observation
import QuartzCore

/// Runs a WarioWare-style loop: random micro-game, quick intro, play,
/// result, repeat faster. Four lives.
@MainActor
@Observable
final class GameSession {
    enum Phase: Equatable {
        case menu
        case intro
        case playing
        case outcome(won: Bool, message: String)
        case gameOver
    }

    static let startingLives = 4
    static let winsPerLevel = 4

    private(set) var phase: Phase = .menu
    private(set) var score = 0
    private(set) var lives = startingLives
    private(set) var level = 1
    private(set) var bestScore = UserDefaults.standard.integer(forKey: "bestScore")
    private(set) var isNewBest = false
    private(set) var currentVerb = ""
    private(set) var currentHint = ""

    let input: HingeInput

    // Per-frame state stays out of observation so the canvas redraw doesn't
    // invalidate SwiftUI views 120 times a second.
    @ObservationIgnored private(set) var current: (any MicroGame)?
    @ObservationIgnored private var lastFactoryIndex: Int?
    @ObservationIgnored private var playStart: CFTimeInterval = 0
    @ObservationIgnored private var resolving = false
    @ObservationIgnored private var generation = 0

    init(input: HingeInput) {
        self.input = input
    }

    var speed: Double { 1 + 0.12 * Double(level - 1) }

    // MARK: Flow

    func start() {
        score = 0
        lives = Self.startingLives
        level = 1
        isNewBest = false
        generation += 1
        ClipRecorder.shared.startBuffering()
        nextGame()
    }

    func quit() {
        generation += 1
        current = nil
        phase = .menu
        ClipRecorder.shared.stopBuffering()
    }

    func backToMenu() {
        quit()
    }

    private func nextGame() {
        var index = Int.random(in: 0..<MicroGameCatalog.factories.count)
        if index == lastFactoryIndex, MicroGameCatalog.factories.count > 1 {
            index = (index + 1) % MicroGameCatalog.factories.count
        }
        lastFactoryIndex = index
        let game = MicroGameCatalog.factories[index](level)
        current = game
        currentVerb = game.verb
        currentHint = game.hint
        resolving = false
        phase = .intro
        after(0.9 / speed) { [self] in
            input.resetClock()
            playStart = CACurrentMediaTime()
            phase = .playing
        }
    }

    private func finish(_ outcome: MicroGameOutcome) {
        switch outcome {
        case .won:
            score += 1
            if score % Self.winsPerLevel == 0 { level += 1 }
            Haptics.win()
            phase = .outcome(won: true, message: ["Nice!", "Clean!", "Snap!", "Yes!"].randomElement()!)
        case .lost(let reason):
            lives -= 1
            Haptics.lose()
            phase = .outcome(won: false, message: reason)
        }
        after(1.1) { [self] in
            if lives <= 0 { endRun() } else { nextGame() }
        }
    }

    private func endRun() {
        current = nil
        if score > bestScore {
            bestScore = score
            isNewBest = true
            UserDefaults.standard.set(score, forKey: "bestScore")
        }
        GameCenterService.shared.submit(score: score)
        phase = .gameOver
    }

    /// Runs `work` after a delay unless the run was quit or restarted meanwhile.
    private func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        let token = generation
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard token == self.generation else { return }
            work()
        }
    }

    // MARK: Frame loop (called from the Canvas renderer)

    func tick(at time: CFTimeInterval) -> HingeFrame {
        let elapsed = phase == .playing ? time - playStart : 0
        let frame = input.frame(at: time, elapsed: elapsed)
        guard phase == .playing, !resolving, let game = current else { return frame }

        let outcome = game.update(frame) ?? (elapsed >= game.duration ? game.timedOut() : nil)
        if let outcome {
            resolving = true
            // Leave the render pass before changing observed state.
            Task { @MainActor in self.finish(outcome) }
        }
        return frame
    }

    /// 1 → 0 over the current game's duration, for the HUD timer.
    func timeRemaining(at time: CFTimeInterval) -> Double {
        guard phase == .playing, let game = current else { return phase == .intro ? 1 : 0 }
        return max(0, 1 - (time - playStart) / game.duration)
    }
}
