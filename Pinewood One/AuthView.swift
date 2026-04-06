import SwiftUI

struct AuthView: View {
    @ObservedObject var appState: AppState
    @State private var showAppleComingSoon = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.11, blue: 0.24), Color(red: 0.08, green: 0.32, blue: 0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(radius: 12)

                Text("Welcome to Pinewood One")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text("Sign in to continue")
                    .foregroundStyle(.white.opacity(0.82))

                Button {
                    Task {
                        await appState.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                        Text("Continue with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .disabled(appState.isPerformingAuth)

                Button {
                    showAppleComingSoon = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                        Text("Continue with Apple")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.white)
                .disabled(appState.isPerformingAuth)

                if appState.isPerformingAuth {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 8)
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
        }
        .alert("Apple Sign-In", isPresented: $showAppleComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Coming soon")
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
