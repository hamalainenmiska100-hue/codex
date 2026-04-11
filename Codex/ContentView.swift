import SwiftUI

struct ContentView: View {
    var body: some View {
        CodexWebView(url: URL(string: "https://chatgpt.com/codex/cloud")!)
            .ignoresSafeArea()
            .background(Color.black)
    }
}
