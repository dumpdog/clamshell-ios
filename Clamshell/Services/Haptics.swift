import UIKit

@MainActor
enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .rigid)
    private static let notify = UINotificationFeedbackGenerator()

    static func tick() { impact.impactOccurred() }
    static func win() { notify.notificationOccurred(.success) }
    static func lose() { notify.notificationOccurred(.error) }
}
