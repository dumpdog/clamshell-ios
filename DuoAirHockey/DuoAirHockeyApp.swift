import SwiftUI
import UIKit

@main
struct DuoAirHockeyApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            AirHockeyView()
                .preferredColorScheme(.dark)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}

/// Holds the screen still during a match, so tilting the table (or a
/// player leaning on it) can't spin the rink mid-rally.
@MainActor
enum OrientationLock {
    static var mask: UIInterfaceOrientationMask = .all

    static func lockToCurrent() {
        guard let scene = activeScene else { return }
        let current: UIInterfaceOrientationMask = switch scene.effectiveGeometry.interfaceOrientation {
        case .portraitUpsideDown: .portraitUpsideDown
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        default: .portrait
        }
        apply(current, to: scene)
    }

    static func unlock() {
        guard let scene = activeScene else { return }
        apply(.all, to: scene)
    }

    private static var activeScene: UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

    private static func apply(_ newMask: UIInterfaceOrientationMask, to scene: UIWindowScene) {
        guard newMask != mask else { return }
        mask = newMask
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: newMask))
    }
}
