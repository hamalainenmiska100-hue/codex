import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CodexWebView(url: URL(string: "https://chatgpt.com/codex")!)
                .ignoresSafeArea()
        }
    }
}
