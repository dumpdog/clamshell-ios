import SwiftUI
import QuartzCore

enum HockeyMode {
    case onePlayer, twoPlayer
}

enum HockeySide {
    case top, bottom
}

/// Duo Air Hockey: played flat on a table with the Duo fully open. The fold
/// is the center line, so each half of the inner display is one player's side.
///
/// Physics runs in a canonical "table" space where the rink's long axis is
/// vertical: the bottom player (you, or Red) defends y = height, the top
/// player (CPU, or Blue) defends y = 0. `AirHockeyView` rotates the table
/// onto the screen the same way `GameStageView` does for micro-games.
@MainActor
@Observable
final class AirHockeyGame {
    enum Screen: Equatable {
        case choosing
        case playing
        case finished(winner: HockeySide)
    }

    struct Mallet {
        var pos: CGPoint = .zero
        var start: CGPoint = .zero
        var target: CGPoint?
        var vel: CGVector = .zero
    }

    static let winningScore = 7

    private(set) var screen: Screen = .choosing
    private(set) var mode: HockeyMode = .onePlayer

    // Per-frame state stays out of observation so the canvas redraw doesn't
    // invalidate SwiftUI views every frame.
    @ObservationIgnored private(set) var size: CGSize = .zero
    @ObservationIgnored private(set) var centerY: CGFloat = 0
    @ObservationIgnored private(set) var puck: CGPoint = .zero
    @ObservationIgnored private(set) var puckVel: CGVector = .zero
    @ObservationIgnored private(set) var top = Mallet()
    @ObservationIgnored private(set) var bottom = Mallet()
    @ObservationIgnored private(set) var topScore = 0
    @ObservationIgnored private(set) var bottomScore = 0
    /// Who scored last, while the "GOAL" banner is up.
    @ObservationIgnored private(set) var lastScorer: HockeySide?
    @ObservationIgnored private var lastTime: CFTimeInterval?
    @ObservationIgnored private var pauseUntil: CFTimeInterval = 0
    @ObservationIgnored private var lastHitTime: CFTimeInterval = 0
    @ObservationIgnored private var resolving = false
    @ObservationIgnored private var owners: [HockeySide: ObjectIdentifier] = [:]

    // MARK: Sizes, all relative to the rink's width

    var puckRadius: CGFloat { size.width * 0.045 }
    var malletRadius: CGFloat { size.width * 0.075 }
    var goalWidth: CGFloat { size.width * 0.38 }
    private var maxPuckSpeed: CGFloat { size.height * 3 }

    // MARK: Flow

    func start(_ mode: HockeyMode) {
        self.mode = mode
        topScore = 0
        bottomScore = 0
        lastScorer = nil
        resolving = false
        owners = [:]
        resetPositions(serveTo: Bool.random() ? .top : .bottom)
        pauseUntil = CACurrentMediaTime() + 0.6
        screen = .playing
    }

    func backToChoosing() {
        screen = .choosing
    }

    /// Called every frame with the current table size and center line. Keeps
    /// pieces in place (proportionally) if the size changes, e.g. on rotation.
    func layout(size newSize: CGSize, centerY newCenter: CGFloat) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        if size == .zero {
            size = newSize
            centerY = newCenter
            resetPositions(serveTo: .bottom)
            return
        }
        guard newSize != size || newCenter != centerY else { return }
        let sx = newSize.width / size.width, sy = newSize.height / size.height
        func scale(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * sx, y: p.y * sy) }
        puck = scale(puck)
        top.pos = scale(top.pos)
        bottom.pos = scale(bottom.pos)
        top.target = top.target.map(scale)
        bottom.target = bottom.target.map(scale)
        size = newSize
        centerY = newCenter
    }

    private func resetPositions(serveTo side: HockeySide) {
        guard size != .zero else { return }
        let topHome = CGPoint(x: size.width / 2, y: centerY * 0.2)
        let bottomHome = CGPoint(x: size.width / 2, y: centerY + (size.height - centerY) * 0.8)
        top = Mallet(pos: topHome, start: topHome)
        bottom = Mallet(pos: bottomHome, start: bottomHome)
        // The player who conceded serves from the middle of their half.
        let serveY = side == .top ? centerY * 0.5 : centerY + (size.height - centerY) * 0.5
        puck = CGPoint(x: size.width / 2, y: serveY)
        puckVel = .zero
    }

    // MARK: Touch input (table space)

    func touchBegan(_ id: ObjectIdentifier, at p: CGPoint) {
        guard screen == .playing else { return }
        let side: HockeySide = p.y < centerY ? .top : .bottom
        if side == .top && mode == .onePlayer { return }
        // The newest finger in a half takes the mallet, so a stuck touch
        // can never lock a player out.
        owners[side] = id
        setTarget(side, p)
    }

    func touchMoved(_ id: ObjectIdentifier, to p: CGPoint) {
        for (side, owner) in owners where owner == id {
            setTarget(side, p)
        }
    }

    func touchEnded(_ id: ObjectIdentifier) {
        for (side, owner) in owners where owner == id {
            owners[side] = nil
        }
    }

    private func setTarget(_ side: HockeySide, _ p: CGPoint) {
        switch side {
        case .top: top.target = p
        case .bottom: bottom.target = p
        }
    }

    // MARK: Simulation

    func step(at now: CFTimeInterval) {
        guard size != .zero else { return }
        let dt = min(max(now - (lastTime ?? now), 0), 1.0 / 30.0)
        lastTime = now
        guard dt > 0, screen == .playing, !resolving else { return }

        if now < pauseUntil {
            // Mallets still follow fingers during the pause after a goal.
            moveMallets(dt)
            return
        }
        if lastScorer != nil {
            lastScorer = nil
        }

        if mode == .onePlayer { runAI(dt) }
        moveMallets(dt)

        // Substeps keep a fast mallet from passing straight through the puck.
        let substeps = 6
        let h = dt / Double(substeps)
        for i in 1...substeps {
            let t = CGFloat(i) / CGFloat(substeps)
            puck.x += puckVel.dx * h
            puck.y += puckVel.dy * h
            collide(with: lerp(bottom.start, bottom.pos, t), velocity: bottom.vel, now: now)
            collide(with: lerp(top.start, top.pos, t), velocity: top.vel, now: now)
            bounceOffWalls(now: now)
            if let scorer = checkGoal() {
                scored(by: scorer, now: now)
                return
            }
        }

        // Very light friction: an air table barely slows the puck.
        let friction = CGFloat(exp(-0.35 * dt))
        puckVel.dx *= friction
        puckVel.dy *= friction
    }

    private func moveMallets(_ dt: Double) {
        bottom = moved(bottom, side: .bottom, dt: dt)
        top = moved(top, side: .top, dt: dt)
    }

    private func moved(_ m: Mallet, side: HockeySide, dt: Double) -> Mallet {
        var m = m
        m.start = m.pos
        if let target = m.target {
            m.pos = clampToHalf(target, side: side)
        }
        m.vel = CGVector(dx: (m.pos.x - m.start.x) / dt, dy: (m.pos.y - m.start.y) / dt)
        return m
    }

    /// Mallets stay inside the rink and on their own side of the fold.
    private func clampToHalf(_ p: CGPoint, side: HockeySide) -> CGPoint {
        let r = malletRadius
        let x = min(max(p.x, r), size.width - r)
        let y: CGFloat
        switch side {
        case .top: y = min(max(p.y, r), centerY - r)
        case .bottom: y = min(max(p.y, centerY + r), size.height - r)
        }
        return CGPoint(x: x, y: y)
    }

    private func collide(with mallet: CGPoint, velocity mv: CGVector, now: CFTimeInterval) {
        let dx = puck.x - mallet.x, dy = puck.y - mallet.y
        let dist = hypot(dx, dy)
        let minDist = puckRadius + malletRadius
        guard dist < minDist else { return }
        let n = dist > 0.001 ? CGVector(dx: dx / dist, dy: dy / dist) : CGVector(dx: 0, dy: mallet.y < centerY ? 1 : -1)
        puck = CGPoint(x: mallet.x + n.dx * minDist, y: mallet.y + n.dy * minDist)

        let relX = puckVel.dx - mv.dx, relY = puckVel.dy - mv.dy
        let along = relX * n.dx + relY * n.dy
        guard along < 0 else { return }
        let restitution: CGFloat = 0.9
        puckVel.dx -= (1 + restitution) * along * n.dx
        puckVel.dy -= (1 + restitution) * along * n.dy
        clampPuckSpeed()
        if now - lastHitTime > 0.08 {
            lastHitTime = now
            Haptics.tick()
        }
    }

    private func bounceOffWalls(now: CFTimeInterval) {
        let r = puckRadius
        let wallRestitution: CGFloat = 0.85
        if puck.x < r {
            puck.x = r
            puckVel.dx = abs(puckVel.dx) * wallRestitution
        } else if puck.x > size.width - r {
            puck.x = size.width - r
            puckVel.dx = -abs(puckVel.dx) * wallRestitution
        }
        // End walls have a goal mouth in the middle; the puck passes through it.
        let inMouth = abs(puck.x - size.width / 2) < goalWidth / 2
        if !inMouth {
            if puck.y < r {
                puck.y = r
                puckVel.dy = abs(puckVel.dy) * wallRestitution
            } else if puck.y > size.height - r {
                puck.y = size.height - r
                puckVel.dy = -abs(puckVel.dy) * wallRestitution
            }
        }
    }

    private func checkGoal() -> HockeySide? {
        if puck.y < 0 { return .bottom }
        if puck.y > size.height { return .top }
        return nil
    }

    private func scored(by scorer: HockeySide, now: CFTimeInterval) {
        switch scorer {
        case .top: topScore += 1
        case .bottom: bottomScore += 1
        }
        lastScorer = scorer
        let conceded: HockeySide = scorer == .top ? .bottom : .top
        resetPositions(serveTo: conceded)
        pauseUntil = now + 1.2

        let winner: HockeySide? = topScore >= Self.winningScore ? .top
            : bottomScore >= Self.winningScore ? .bottom : nil
        if mode == .onePlayer && scorer == .top { Haptics.lose() } else { Haptics.win() }
        guard let winner else { return }
        resolving = true
        // Leave the render pass before changing observed state.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard self.resolving else { return }
            self.resolving = false
            self.screen = .finished(winner: winner)
        }
    }

    private func clampPuckSpeed() {
        let speed = hypot(puckVel.dx, puckVel.dy)
        guard speed > maxPuckSpeed else { return }
        puckVel.dx *= maxPuckSpeed / speed
        puckVel.dy *= maxPuckSpeed / speed
    }

    // MARK: CPU opponent (top side)

    private func runAI(_ dt: Double) {
        let r = malletRadius + puckRadius
        let defendY = malletRadius + (centerY - malletRadius) * 0.18
        var goal: CGPoint

        let puckInHalf = puck.y < centerY - puckRadius
        let comingAtUs = puckVel.dy < -size.height * 0.25
        if puckInHalf && !comingAtUs {
            if puck.y < top.pos.y - malletRadius * 0.5 {
                // Puck slipped behind the mallet: go around it, not through it.
                let sideStep = puck.x < size.width / 2 ? r * 1.3 : -r * 1.3
                goal = CGPoint(x: puck.x + sideStep, y: puck.y - r)
            } else {
                // Strike from behind the puck toward the bottom goal.
                let aim = CGPoint(x: size.width / 2, y: size.height)
                let dx = aim.x - puck.x, dy = aim.y - puck.y
                let len = max(hypot(dx, dy), 0.001)
                goal = CGPoint(x: puck.x - dx / len * r * 0.4, y: puck.y - dy / len * r * 0.4)
            }
        } else {
            // Guard the goal, shading toward the puck.
            goal = CGPoint(x: size.width / 2 + (puck.x - size.width / 2) * 0.6, y: defendY)
        }

        let maxStep = size.height * 0.9 * dt
        let dx = goal.x - top.pos.x, dy = goal.y - top.pos.y
        let dist = hypot(dx, dy)
        if dist > maxStep {
            goal = CGPoint(x: top.pos.x + dx / dist * maxStep, y: top.pos.y + dy / dist * maxStep)
        }
        top.target = goal
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}
