import SwiftUI

@main
struct ClamshellApp: App {
    @State private var hinge: HingeInput
    @State private var session: GameSession

    init() {
        let hinge = HingeInput()
        _hinge = State(initialValue: hinge)
        _session = State(initialValue: GameSession(input: hinge))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(hinge)
                .environment(session)
                // Feeds real hinge angles into HingeInput on iPhone Duo (no-op elsewhere).
                .trackHinge(into: hinge)
                .preferredColorScheme(.dark)
                .task { GameCenterService.shared.authenticate() }
        }
    }
}
