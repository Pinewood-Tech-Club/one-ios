import SwiftUI
import UIKit
import WebKit

struct BridgeContextPayload {
    let platform: String
    let appVersion: String
    let buildNumber: String
    let bridgeVersion: String

    static var current: BridgeContextPayload {
        BridgeContextPayload(
            platform: "ios",
            appVersion: AppConfig.appVersion,
            buildNumber: AppConfig.buildNumber,
            bridgeVersion: "v1"
        )
    }

    var jsonString: String {
        let payload: [String: String] = [
            "platform": platform,
            "appVersion": appVersion,
            "buildNumber": buildNumber,
            "bridgeVersion": bridgeVersion,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }
}

struct OnboardingWebContainer: UIViewRepresentable {
    let url: URL
    let bridgeContext: BridgeContextPayload
    let onStartSchoologyOAuth: () -> Void
    let onOpenExternalURL: (URL) -> Void
    let onOnboardingComplete: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "startSchoologyOAuth")
        userContentController.add(context.coordinator, name: "openExternalURL")
        userContentController.add(context.coordinator, name: "onboardingComplete")

        let scriptSource = """
        (function() {
          const context = \(bridgeContext.jsonString);
          window.mobileBridge = window.mobileBridge || {};
          window.mobileBridge.v1 = {
            startSchoologyOAuth: function() {
              window.webkit.messageHandlers.startSchoologyOAuth.postMessage({});
            },
            openExternalURL: function(url) {
              window.webkit.messageHandlers.openExternalURL.postMessage({ url: String(url || '') });
            },
            onboardingComplete: function() {
              window.webkit.messageHandlers.onboardingComplete.postMessage({});
            },
            getContext: function() {
              return context;
            }
          };

          document.addEventListener('click', function(event) {
            const target = event.target;
            if (!target || !target.closest) {
              return;
            }
            const anchor = target.closest('a[href]');
            if (!anchor) {
              return;
            }
            const rawHref = String(anchor.getAttribute('href') || '');
            const loweredHref = rawHref.toLowerCase();
            if (!rawHref || rawHref.startsWith('#') || loweredHref.startsWith('javascript:') || loweredHref.startsWith('mailto:') || loweredHref.startsWith('tel:')) {
              return;
            }
            event.preventDefault();
            event.stopPropagation();
            window.webkit.messageHandlers.openExternalURL.postMessage({ url: String(anchor.href || rawHref) });
          }, true);
        })();
        """

        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(script)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        context.coordinator.lastRequestedBootstrapURL = url
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Compare against the last requested bootstrap URL, not webView.url.
        // After initial load, the backend redirects to frontend onboarding URL.
        // Comparing to webView.url causes repeated bootstrap reload attempts.
        guard context.coordinator.lastRequestedBootstrapURL != url else { return }
        context.coordinator.lastRequestedBootstrapURL = url
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private let parent: OnboardingWebContainer
        private var lastTrustedMainFrameURL: URL?
        fileprivate var lastRequestedBootstrapURL: URL?

        init(parent: OnboardingWebContainer) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame else {
                return
            }
            guard isTrustedMessageOrigin(message) else {
                return
            }

            switch message.name {
            case "startSchoologyOAuth":
                parent.onStartSchoologyOAuth()
            case "openExternalURL":
                guard let body = message.body as? [String: Any],
                      let rawURL = body["url"] as? String,
                      let url = URL(string: rawURL)
                else {
                    return
                }
                parent.onOpenExternalURL(url)
            case "onboardingComplete":
                parent.onOnboardingComplete()
            default:
                break
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let targetURL = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if navigationAction.navigationType == .linkActivated {
                parent.onOpenExternalURL(targetURL)
                decisionHandler(.cancel)
                return
            }

            guard navigationAction.targetFrame?.isMainFrame == true else {
                decisionHandler(.cancel)
                return
            }

            if isTrustedURL(targetURL) {
                lastTrustedMainFrameURL = targetURL
                decisionHandler(.allow)
                return
            }

            // Keep the in-app onboarding surface constrained to trusted origins.
            // Non-user-initiated navigations to untrusted origins are blocked silently.
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let currentURL = webView.url, isTrustedURL(currentURL) else {
                lastTrustedMainFrameURL = nil
                return
            }
            lastTrustedMainFrameURL = currentURL
        }

        private func isTrustedMessageOrigin(_ message: WKScriptMessage) -> Bool {
            let origin = message.frameInfo.securityOrigin
            let originScheme = origin.`protocol`.lowercased()
            guard isTrustedOrigin(
                scheme: originScheme,
                host: origin.host.lowercased(),
                port: origin.port
            ) else {
                return false
            }

            // `WKSecurityOrigin.port` can report 0 for default ports.
            // Once origin is trusted, allow bridge calls even if URL tracking has not been set yet.
            if let currentURL = lastTrustedMainFrameURL {
                return isTrustedURL(currentURL)
            }
            return true
        }

        private func isTrustedURL(_ url: URL) -> Bool {
            guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else {
                return false
            }
            let port = url.port ?? defaultPort(for: scheme)
            return isTrustedOrigin(scheme: scheme, host: host, port: port)
        }

        private func isTrustedOrigin(scheme: String, host: String, port: Int) -> Bool {
            let incomingPort = normalizedPort(for: scheme, port: port)
            let trustedURLs = [AppConfig.frontendURL, AppConfig.backendURL]

            for trustedURL in trustedURLs {
                guard let trustedScheme = trustedURL.scheme?.lowercased(),
                      let trustedHost = trustedURL.host?.lowercased()
                else {
                    continue
                }
                let trustedPort = normalizedPort(
                    for: trustedScheme,
                    port: trustedURL.port ?? defaultPort(for: trustedScheme)
                )
                if scheme == trustedScheme && host == trustedHost && incomingPort == trustedPort {
                    return true
                }
            }

            return false
        }

        private func normalizedPort(for scheme: String, port: Int) -> Int {
            if port == 0 || port == -1 {
                return defaultPort(for: scheme)
            }
            return port
        }

        private func defaultPort(for scheme: String) -> Int {
            switch scheme {
            case "https":
                return 443
            case "http":
                return 80
            default:
                return -1
            }
        }
    }
}
