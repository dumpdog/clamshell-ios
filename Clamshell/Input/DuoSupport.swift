import SwiftUI

// Everything that touches iPhone Duo–only API lives in this file, behind the
// DUO_SDK compilation condition. API names come from Apple's iPhone Duo tech
// talks (111463, 111464). If one doesn't compile against the real SDK, this
// file is the only thing to fix. Turn on DUO_SDK in
// Build Settings > Active Compilation Conditions once you're on Xcode 27.1.

extension View {
    /// Forwards hinge angle changes into `HingeInput`.
    @ViewBuilder
    func trackHinge(into input: HingeInput) -> some View {
        #if DUO_SDK
        if #available(iOS 27.1, *) {
            self.onHingeChange { _, context in
                input.hingeDidChange(angleDegrees: context.hinge?.angle.degrees)
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
}

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
