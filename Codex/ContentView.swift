import SwiftUI

struct ContentView: View {
    @StateObject private var webState = WebViewState()
    private let rootURL = URL(string: "https://chatgpt.com/codex/cloud")!

    var body: some View {
        ZStack {
            CodexWebView(url: rootURL, state: webState)
                .background(Color.black)

            if webState.hasError {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)

                    Text("Couldn’t Load Codex")
                        .font(.headline)

                    Text(webState.errorMessage ?? "An unknown error occurred.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Retry") {
                        webState.reload()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()
            }

            if webState.isLoading {
                VStack {
                    ProgressView("Loading…")
                        .padding(12)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                }
                .padding(.top, 16)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                Button {
                    webState.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)

                Spacer()

                if let currentURL = webState.currentURL {
                    ShareLink(item: currentURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }
}
