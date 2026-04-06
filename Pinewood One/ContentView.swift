import SwiftUI
import SafariServices

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            switch appState.phase {
            case .loading:
                ProgressView("Loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                AuthView(appState: appState)
            case let .onboarding(url):
                onboardingView(url: url)
            case .signedIn:
                MainTabShellView(appState: appState)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await appState.handleForegroundRefresh()
            }
        }
        .sheet(item: $appState.externalBrowserDestination) { destination in
            InAppSafariView(url: destination.url)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func onboardingView(url: URL) -> some View {
        ZStack {
            OnboardingWebContainer(
                url: url,
                bridgeContext: .current,
                onStartSchoologyOAuth: {
                    appState.handleBridgeSchoologyOAuth()
                },
                onOpenExternalURL: { externalURL in
                    appState.openExternalURL(externalURL)
                },
                onOnboardingComplete: {
                    appState.handleBridgeOnboardingComplete()
                }
            )
            .ignoresSafeArea()
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { appState.transientError != nil },
            set: { if !$0 { appState.transientError = nil } }
        )) {
            Button("OK", role: .cancel) {
                appState.transientError = nil
            }
        } message: {
            Text(appState.transientError ?? "Something went wrong.")
        }
    }
}

private struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        controller.preferredControlTintColor = .label
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

#Preview {
    ContentView()
}
