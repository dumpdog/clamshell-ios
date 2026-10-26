import SwiftUI

/// The Pro unlock sheet: what you get, the price, Restore, and the privacy policy.
struct UnlockView: View {
    static let privacyURL = URL(string: "https://dumpdog.github.io/clamshell-ios/duo-air-hockey/privacy.html")!

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("DUO AIR HOCKEY PRO")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            if store.isPro {
                Label("Unlocked. Thanks for supporting a tiny indie app!", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    perk("person.2.fill", "Unlimited face-to-face matches")
                    perk("cpu", "Medium and Hard CPU")
                    perk("heart.fill", "One payment, no ads, no subscription")
                }
                .font(.headline)
                Button {
                    Task { await store.purchase() }
                } label: {
                    Group {
                        if store.purchasing { ProgressView() } else { Text("Unlock for \(store.priceText)") }
                    }
                    .font(.title2.bold()).frame(maxWidth: 280).padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .disabled(store.purchasing)
            }
            HStack(spacing: 24) {
                if !store.isPro {
                    Button("Restore Purchase") { Task { await store.restore() } }
                }
                Link("Privacy Policy", destination: Self.privacyURL)
            }
            .font(.footnote)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(32)
        .presentationDetents([.medium, .large])
        .onChange(of: store.isPro) { _, isPro in
            if isPro { Task { try? await Task.sleep(for: .seconds(1.2)); dismiss() } }
        }
        .alert("Couldn't complete that", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func perk(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(.yellow)
        }
    }
}
