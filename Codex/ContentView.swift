import SwiftUI

struct ContentView: View {
    @StateObject private var webState = WebViewState()
    private let rootURL = URL(string: "https://chatgpt.com/codex/cloud")!

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Codex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        webState.goBack()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .disabled(!webState.canGoBack)

                    Button {
                        webState.goForward()
                    } label: {
                        Image(systemName: "chevron.forward")
                    }
                    .disabled(!webState.canGoForward)

                    Button {
                        webState.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }

                    Spacer()

                    if let currentURL = webState.currentURL {
                        ShareLink(item: currentURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }
}
