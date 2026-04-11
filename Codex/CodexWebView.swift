import SwiftUI
import WebKit
import UIKit

struct CodexWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "haptic")

        let injectedJS = """
        (function() {
            function applyNativeLikeRules() {
                try {
                    var existing = document.querySelector('meta[name="viewport"]');
                    if (!existing) {
                        existing = document.createElement('meta');
                        existing.name = 'viewport';
                        document.head.appendChild(existing);
                    }
                    existing.setAttribute(
                        'content',
                        'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'
                    );
                } catch (e) {}

                try {
                    var style = document.getElementById('codex-native-style');
                    if (!style) {
                        style = document.createElement('style');
                        style.id = 'codex-native-style';
                        style.innerHTML = `
                            html, body {
                                -webkit-text-size-adjust: 100% !important;
                                text-size-adjust: 100% !important;
                                -webkit-touch-callout: none !important;
                            }

                            * {
                                -webkit-user-select: none !important;
                                user-select: none !important;
                                -webkit-touch-callout: none !important;
                                -webkit-tap-highlight-color: rgba(0,0,0,0) !important;
                            }

                            input, textarea, [contenteditable="true"], [contenteditable=""], .ProseMirror {
                                -webkit-user-select: text !important;
                                user-select: text !important;
                            }
                        `;
                        document.documentElement.appendChild(style);
                    }
                } catch (e) {}
            }

            applyNativeLikeRules();
            document.addEventListener('DOMContentLoaded', applyNativeLikeRules);
            window.addEventListener('load', applyNativeLikeRules);

            document.addEventListener('click', function(event) {
                try {
                    var el = event.target;
                    if (!el) return;

                    var clickable = el.closest('button, a, [role="button"], input[type="button"], input[type="submit"], summary');
                    if (clickable) {
                        window.webkit.messageHandlers.haptic.postMessage("tap");
                    }
                } catch (e) {}
            }, true);

            document.addEventListener('selectstart', function(e) {
                var t = e.target;
                if (t && (t.closest('input') || t.closest('textarea') || t.closest('[contenteditable="true"]') || t.closest('.ProseMirror'))) {
                    return;
                }
                e.preventDefault();
            }, true);

            document.addEventListener('contextmenu', function(e) {
                e.preventDefault();
            }, true);

            let lastTouchEnd = 0;
            document.addEventListener('touchend', function(e) {
                const now = Date.now();
                if (now - lastTouchEnd <= 300) {
                    e.preventDefault();
                }
                lastTouchEnd = now;
            }, { passive: false });

            document.addEventListener('gesturestart', function(e) {
                e.preventDefault();
            }, { passive: false });

            document.addEventListener('gesturechange', function(e) {
                e.preventDefault();
            }, { passive: false });

            document.addEventListener('gestureend', function(e) {
                e.preventDefault();
            }, { passive: false });

            document.addEventListener('touchmove', function(e) {
                if (e.scale && e.scale !== 1) {
                    e.preventDefault();
                }
            }, { passive: false });
        })();
        """

        let script = WKUserScript(
            source: injectedJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        contentController.addUserScript(script)
        config.userContentController = contentController

        let webView = NoZoomWKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.attach(webView: webView)

        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        webView.scrollView.bouncesZoom = false
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false

        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.alpha = 0.0

        if #available(iOS 16.4, *) {
            webView.isInspectable = false
        }
        
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

        let request = URLRequest(
            url: url,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 60
        )
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        private let haptic = UIImpactFeedbackGenerator(style: .light)
        private weak var webView: WKWebView?

        override init() {
            super.init()
            haptic.prepare()
        }
        
        func attach(webView: WKWebView) {
            self.webView = webView
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "haptic" else { return }
            haptic.impactOccurred()
            haptic.prepare()
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            guard let requestURL = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let urlString = requestURL.absoluteString.lowercased()
            let scheme = requestURL.scheme?.lowercased() ?? ""

            if scheme == "mailto" || scheme == "tel" || scheme == "sms" {
                UIApplication.shared.open(requestURL)
                decisionHandler(.cancel)
                return
            }

            if urlString.contains("about:blank") && navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                webView.pageZoom = 1.0
                webView.setNeedsLayout()
                webView.layoutIfNeeded()

                UIView.animate(withDuration: 0.2) {
                    webView.alpha = 1.0
                }
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            (self.webView ?? webView).reload()
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}

final class NoZoomWKWebView: WKWebView, UIGestureRecognizerDelegate {
    override func didMoveToWindow() {
        super.didMoveToWindow()

        scrollView.pinchGestureRecognizer?.isEnabled = false
        scrollView.pinchGestureRecognizer?.delegate = self

        for recognizer in scrollView.gestureRecognizers ?? [] {
            if let tap = recognizer as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2 {
                tap.isEnabled = false
            }
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}
