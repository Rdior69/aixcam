//
//  DetailView.swift
//  H4X0R News
//
//  Created by Ray Wenderlich on 1/7/21.
//

import SwiftUI

struct DetailView: View {
    let url: String?
    var body: some View {
        NavigationView {
            if let url = url {
                WebView(urlString: url)
                    .navigationBarTitle(Text(""), displayMode: .inline)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("Invalid URL")
                    .foregroundColor(.red)
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed with error: \(error.localizedDescription)")
        }
    }
}

struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        DetailView(url: "https://www.google.com")
    }
}
