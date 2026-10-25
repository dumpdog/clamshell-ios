import SwiftUI
import UIKit

/// Transparent multi-touch surface for thumb taps. SwiftUI gestures track one
/// finger at a time, which drops the second thumb when you alternate fast, so
/// this reports every touch itself.
struct ThumbTouchLayer: UIViewRepresentable {
    var onDown: @MainActor (CGPoint) -> Void
    var onUp: @MainActor () -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.onDown = onDown
        view.onUp = onUp
    }

    final class TouchView: UIView {
        var onDown: (@MainActor (CGPoint) -> Void)?
        var onUp: (@MainActor () -> Void)?
        private var active = Set<UITouch>()

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches where active.insert(touch).inserted {
                onDown?(touch.location(in: self))
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            release(touches)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            release(touches)
        }

        private func release(_ touches: Set<UITouch>) {
            for touch in touches where active.remove(touch) != nil {
                onUp?()
            }
        }
    }
}
