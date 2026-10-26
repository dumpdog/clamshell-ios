import Foundation
import Observation
import StoreKit

/// The one-time "Duo Air Hockey Pro" unlock (StoreKit 2, non-consumable).
///
/// Free: 1P vs CPU on Easy, plus `freeTwoPlayerMatchesPerDay` face-to-face
/// matches a day, so anyone can show a friend. Pro: unlimited 2P matches and
/// the Medium and Hard CPU. No ads, no account, no tracking.
@MainActor
@Observable
final class Store {
    static let proProductID = "com.justinlum.duoairhockey.pro"
    static let freeTwoPlayerMatchesPerDay = 3

    private(set) var isPro: Bool
    private(set) var product: Product?
    private(set) var purchasing = false
    private(set) var twoPlayerMatchesToday: Int
    var errorMessage: String?

    // Lives as long as the app, so it's never cancelled.
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        // Cached so Pro works on launch before StoreKit answers (or offline).
        isPro = defaults.bool(forKey: Keys.isPro)
        twoPlayerMatchesToday = Self.todayCount(in: defaults)
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await refresh() }
    }

    // MARK: Free tier

    var twoPlayerMatchesLeft: Int {
        isPro ? .max : max(0, Self.freeTwoPlayerMatchesPerDay - twoPlayerMatchesToday)
    }

    func canPlay(_ mode: HockeyMode, _ difficulty: HockeyDifficulty) -> Bool {
        if isPro { return true }
        switch mode {
        case .onePlayer: return difficulty == .easy
        case .twoPlayer: return twoPlayerMatchesLeft > 0
        }
    }

    /// Call when a 2P match starts. Rematches count too.
    func recordTwoPlayerMatch() {
        guard !isPro else { return }
        twoPlayerMatchesToday = Self.todayCount(in: defaults) + 1
        defaults.set(twoPlayerMatchesToday, forKey: Keys.matchCount)
        defaults.set(Self.today, forKey: Keys.matchDay)
    }

    // MARK: Purchasing

    var priceText: String { product?.displayPrice ?? "$1.99" }

    func purchase() async {
        guard let product, !purchasing else {
            if product == nil { errorMessage = "The App Store isn't reachable right now. Try again in a moment." }
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result): await handle(result)
            case .pending, .userCancelled: break
            @unknown default: break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refresh()
        if !isPro && errorMessage == nil {
            errorMessage = "No previous purchase was found for this Apple Account."
        }
    }

    // MARK: Entitlements

    private func refresh() async {
        if product == nil {
            product = try? await Product.products(for: [Self.proProductID]).first
        }
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.proProductID, t.revocationDate == nil {
                owned = true
            }
        }
        setPro(owned)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result, t.productID == Self.proProductID else { return }
        setPro(t.revocationDate == nil)
        await t.finish()
    }

    private func setPro(_ value: Bool) {
        isPro = value
        defaults.set(value, forKey: Keys.isPro)
    }

    // MARK: Daily count

    private enum Keys {
        static let isPro = "store.isPro"
        static let matchCount = "store.twoPlayerMatches"
        static let matchDay = "store.twoPlayerDay"
    }

    private static var today: String {
        Date.now.formatted(.iso8601.year().month().day())
    }

    private static func todayCount(in defaults: UserDefaults) -> Int {
        defaults.string(forKey: Keys.matchDay) == today ? defaults.integer(forKey: Keys.matchCount) : 0
    }
}
