import SwiftUI
import UIKit

// Small pieces Duo Air Hockey shares in spirit with Clamshell. They're copied
// rather than shared so each app builds on its own.

enum FoldRegions {
    /// Frames of the fold ("division" reserved regions) in the proxy's local
    /// space. They're included while flat (zero thickness, inactive), so the
    /// fold's orientation is always known. Returns [] on devices without a fold.
    @MainActor
    static func frames(in proxy: GeometryProxy) -> [CGRect] {
        #if DUO_SDK
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division, options: .includeInactive).map(\.frame)
        }
        #endif
        return []
    }
}

@MainActor
enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .rigid)
    private static let notify = UINotificationFeedbackGenerator()

    static func tick() { impact.impactOccurred() }
    static func win() { notify.notificationOccurred(.success) }
    static func lose() { notify.notificationOccurred(.error) }
}

extension GraphicsContext {
    func label(_ s: String, at p: CGPoint, size: CGFloat, color: Color = .white) {
        draw(Text(s).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(color),
             at: p, anchor: .center)
    }
}
