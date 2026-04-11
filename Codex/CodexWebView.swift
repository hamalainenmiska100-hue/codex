import SwiftUI
import WebKit
import UIKit

final class WebViewState: ObservableObject {
    @Published var isLoading = true
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var currentURL: URL?
    @Published var errorMessage: String?

    fileprivate var onGoBack: (() -> Void)?
    fileprivate var onGoForward: (() -> Void)?
    fileprivate var onReload: (() -> Void)?

    func goBack() {
        onGoBack?()
    }

    func goForward() {
        onGoForward?()
    }

    func reload() {
        onReload?()
    }

    var hasError: Bool {
        errorMessage != nil
    }
}

struct CodexWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var state: WebViewState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "haptic")

        let injectedJS = """
        (function() {
            function isEditable(el) {
                if (!el) return false;
                return !!el.closest('input, textarea, [contenteditable="true"], [contenteditable=""], [contenteditable], .ProseMirror');
            }

            function focusEditableTarget(target) {
                if (!isEditable(target)) return;
                if (document.activeElement === target) return;
                try {
                    target.focus({ preventScroll: true });
                } catch (e) {
                    try { target.focus(); } catch (_) {}
                }
            }

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
                                -webkit-tap-highlight-color: rgba(0,0,0,0) !important;
                            }

                            input, textarea, [contenteditable="true"], [contenteditable=""], [contenteditable], .ProseMirror {
                                -webkit-user-select: text !important;
                                user-select: text !important;
                                -webkit-touch-callout: default !important;
                                touch-action: manipulation !important;
                            }

                            textarea, [contenteditable], .ProseMirror {
                                -webkit-overflow-scrolling: touch !important;
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

            document.addEventListener('contextmenu', function(e) {
                if (!isEditable(e.target)) {
                    e.preventDefault();
                }
            }, true);

            document.addEventListener('touchend', function(e) {
                focusEditableTarget(e.target);
            }, { passive: true, capture: true });

            document.addEventListener('pointerup', function(e) {
                focusEditableTarget(e.target);
            }, true);

            document.addEventListener('focusin', function() {
                document.documentElement.classList.add('codex-has-focus');
            }, true);

            document.addEventListener('focusout', function() {
                window.setTimeout(function() {
                    var active = document.activeElement;
                    if (!isEditable(active)) {
                        document.documentElement.classList.remove('codex-has-focus');
                    }
                }, 0);
            }, true);
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
        webView.scrollView.verticalScrollIndicatorInsets = .zero
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
        private let state: WebViewState

        init(state: WebViewState) {
            self.state = state
            super.init()
            haptic.prepare()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(webView: WKWebView) {
            self.webView = webView
            state.onGoBack = { [weak webView] in webView?.goBack() }
            state.onGoForward = { [weak webView] in webView?.goForward() }
            state.onReload = { [weak webView] in webView?.reload() }

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillChangeFrame(_:)),
                name: UIResponder.keyboardWillChangeFrameNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHide(_:)),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )

            syncNavigationState(for: webView)
        }

        @objc private func keyboardWillChangeFrame(_ notification: Notification) {
            guard
                let webView,
                let userInfo = notification.userInfo,
                let keyboardEndFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else {
                return
            }

            let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            let curveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
            let curve = UIView.AnimationOptions(rawValue: curveRaw << 16)

            let keyboardFrameInView = webView.convert(keyboardEndFrame, from: nil)
            let overlap = max(0, webView.bounds.maxY - keyboardFrameInView.minY)
            let bottomInset = max(0, overlap - webView.safeAreaInsets.bottom)

            UIView.animate(withDuration: duration, delay: 0, options: [curve, .beginFromCurrentState]) {
                webView.scrollView.contentInset.bottom = bottomInset
                webView.scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
            }
        }

        @objc private func keyboardWillHide(_ notification: Notification) {
            guard let webView else { return }
            let userInfo = notification.userInfo
            let duration = userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            let curveRaw = userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
            let curve = UIView.AnimationOptions(rawValue: curveRaw << 16)

            UIView.animate(withDuration: duration, delay: 0, options: [curve, .beginFromCurrentState]) {
                webView.scrollView.contentInset.bottom = 0
                webView.scrollView.verticalScrollIndicatorInsets.bottom = 0
            }
        }

        private func syncNavigationState(for webView: WKWebView) {
            DispatchQueue.main.async {
                self.state.canGoBack = webView.canGoBack
                self.state.canGoForward = webView.canGoForward
                self.state.currentURL = webView.url
            }
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

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.state.isLoading = true
                self.state.errorMessage = nil
            }
            syncNavigationState(for: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            syncNavigationState(for: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                webView.pageZoom = 1.0
                webView.setNeedsLayout()
                webView.layoutIfNeeded()

                UIView.animate(withDuration: 0.2) {
                    webView.alpha = 1.0
                }

                self.state.isLoading = false
                self.state.errorMessage = nil
                self.syncNavigationState(for: webView)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.state.isLoading = false
                self.state.errorMessage = error.localizedDescription
            }
            syncNavigationState(for: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.state.isLoading = false
                self.state.errorMessage = error.localizedDescription
            }
            syncNavigationState(for: webView)
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
