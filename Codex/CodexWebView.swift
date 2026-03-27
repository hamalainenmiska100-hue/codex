import SwiftUI
import WebKit
import UIKit

struct CodexWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.processPool = WebViewEnvironment.sharedProcessPool
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile

        let userContentController = WKUserContentController()
        userContentController.addUserScript(WKUserScript(
            source: Self.bootstrapJavaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        userContentController.add(context.coordinator, name: Coordinator.pageReadyHandlerName)
        userContentController.add(context.coordinator, name: Coordinator.hapticHandlerName)
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .interactive
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.pageZoom = 0.9
        webView.alpha = 0

        context.coordinator.attach(to: webView)

        let request = URLRequest(
            url: url,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 60
        )
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.pageReadyHandlerName)
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.hapticHandlerName)
    }

    private static let bootstrapJavaScript = #"""
    (function() {
      if (window.__codexAppInjected) { return; }
      window.__codexAppInjected = true;

      const style = document.createElement('style');
      style.id = 'codex-app-bootstrap-style';
      style.textContent = `
        html { background: #000 !important; }
        body { opacity: 0; transition: opacity 0.18s ease-in-out; }
      `;
      document.documentElement.appendChild(style);

      const interactiveSelector = [
        'button',
        'a',
        'summary',
        'input:not([type="hidden"])',
        'select',
        'textarea',
        '[role="button"]',
        '[role="link"]',
        '[tabindex]:not([tabindex="-1"])',
        '[data-testid*="button"]',
        '[class*="button"]',
        '[class*="Button"]'
      ].join(',');

      let lastHapticAt = 0;

      document.addEventListener('click', function(event) {
        const target = event.target;
        if (!(target instanceof Element)) { return; }

        const interactive = target.closest(interactiveSelector);
        if (!interactive) { return; }

        const now = Date.now();
        if (now - lastHapticAt < 60) { return; }
        lastHapticAt = now;

        try {
          window.webkit.messageHandlers.haptic.postMessage('tap');
        } catch (_) {}
      }, true);

      window.addEventListener('load', function() {
        window.requestAnimationFrame(function() {
          window.requestAnimationFrame(function() {
            if (document.body) {
              document.body.style.opacity = '1';
            }
            try {
              window.webkit.messageHandlers.pageReady.postMessage('ready');
            } catch (_) {}
          });
        });
      }, { once: true });
    })();
    """#

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        static let pageReadyHandlerName = "pageReady"
        static let hapticHandlerName = "haptic"

        private weak var webView: WKWebView?
        private var hasRevealed = false
        private let feedback = UIImpactFeedbackGenerator(style: .light)

        override init() {
            super.init()
            feedback.prepare()
        }

        func attach(to webView: WKWebView) {
            self.webView = webView
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case Self.pageReadyHandlerName:
                revealIfNeeded()
            case Self.hapticHandlerName:
                feedback.impactOccurred(intensity: 0.75)
                feedback.prepare()
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.revealIfNeeded()
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        private func revealIfNeeded() {
            guard let webView, !hasRevealed else { return }
            hasRevealed = true

            webView.evaluateJavaScript("if (document.body) { document.body.style.opacity = '1'; }")

            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                webView.alpha = 1
            }
        }
    }
}

private enum WebViewEnvironment {
    static let sharedProcessPool = WKProcessPool()
}
