import AVFoundation
import AVKit
import SwiftUI

struct ContentView: View {
    @StateObject private var webState = WebViewState()
    @State private var showSplash = true
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

            if showSplash {
                TinySplashVideoView {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .background(Color.black.ignoresSafeArea(.container, edges: .bottom))
    }
}

private struct TinySplashVideoView: View {
    let onFinish: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                TinySplashVideoPlayerRepresentable(onFinish: onFinish)
                    .frame(width: proxy.size.width * 0.74)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct TinySplashVideoPlayerRepresentable: UIViewControllerRepresentable {
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
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
        private var timeoutTask: DispatchWorkItem?
        private var didFinish = false
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            timeoutTask?.cancel()
        }

        func attach(player: AVPlayer) {
            let timeoutTask = DispatchWorkItem { [weak self] in
                self?.finishIfNeeded()
            }
            self.timeoutTask = timeoutTask
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutTask)

            observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.finishIfNeeded()
            }
        }

        private func finishIfNeeded() {
            guard !didFinish else { return }
            didFinish = true
            timeoutTask?.cancel()
            onFinish()
        }
    }
}
