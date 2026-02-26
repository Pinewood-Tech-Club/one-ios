import SwiftUI
import WebKit

// 1. Modern State Management (Observation Framework)
@Observable
class ContentViewModel {
    var showBrowser = false
    var url = URL(string: "https://www.apple.com")!
}

struct ContentView: View {
    @State private var viewModel = ContentViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient to show off glass effects
                LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "swift")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: viewModel.showBrowser) // Native symbol animation
                    
                    Text("SwiftUI 2026")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text("Ready for the Liquid Glass era.")
                        .foregroundStyle(.white.opacity(0.8))
                    
                    // 2. The new Glass Button Style
                    Button {
                        viewModel.showBrowser.toggle()
                    } label: {
                        Label("Open Native Web", systemImage: "safari")
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.glass) // <--- The new standard style
                    .controlSize(.large)
                }
            }
            .navigationTitle("Home")
            // 3. Native Sheet with WebView
            .sheet(isPresented: $viewModel.showBrowser) {
                BrowserView(url: viewModel.url)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.thinMaterial) // Matches glass aesthetic
            }
        }
    }
}

// 4. The long-awaited Native WebView
struct BrowserView: View {
    let url: URL
    
    var body: some View {
        VStack {
            // New native toolbar spacer for separation
            HStack {
                Text("In-App Browser")
                    .font(.headline)
                Spacer()
            }
            
            // No more UIViewRepresentable needed!
            WebView(url: url)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .glassEffect() // Applies the new system glass treatment
    }
}

#Preview {
    ContentView()
}
