import AVFoundation
import AVKit
import SwiftUI

struct ContentView: View {
    @StateObject private var webState = WebViewState()
    @State private var showSplash = true

    private let rootURL = URL(string: "https://chatgpt.com/codex/cloud")!

    var body: some View {
        ZStack {
            wrapperContent
                .offset(x: showSplash ? UIScreen.main.bounds.width : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.9), value: showSplash)

            if showSplash {
                SplashVideoView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var wrapperContent: some View {
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

private struct SplashVideoView: View {
    let onFinish: () -> Void

    var body: some View {
        SplashVideoPlayerRepresentable(onFinish: onFinish)
            .ignoresSafeArea()
            .background(Color.black)
    }
}

private struct SplashVideoPlayerRepresentable: UIViewControllerRepresentable {
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .black

        guard let videoURL = Bundle.main.url(forResource: "openai", withExtension: "mp4") else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onFinish()
            }
            return controller
        }

        let player = AVPlayer(url: videoURL)
        controller.player = player
        context.coordinator.attach(player: player)
        player.play()

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    final class Coordinator {
        private var observer: NSObjectProtocol?
        private var didFinish = false
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func attach(player: AVPlayer) {
            observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                finishIfNeeded()
            }
        }

        private func finishIfNeeded() {
            guard !didFinish else { return }
            didFinish = true
            onFinish()
        }
    }
}
