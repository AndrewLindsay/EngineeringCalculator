import SwiftUI
import WebKit

/// Renders MathML with the system WebKit engine. This is fully local: no MathJax,
/// JavaScript package, network connection or third-party dependency is required.
struct MathEquationView: View {
    let mathML: String
    @Environment(\.interfaceDensity) private var density

    var body: some View {
        MathMLWebView(mathML: mathML, pointSize: density.bodySize + 3)
            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 60)
            .accessibilityLabel("Equation")
    }
}

/// Compact MathML renderer for mathematical symbols used in variable lists.
struct MathSymbolView: View {
    let mathML: String
    @Environment(\.interfaceDensity) private var density

    var body: some View {
        MathMLWebView(mathML: mathML, pointSize: density.bodySize, minimumHeight: 24)
            .frame(width: 58, height: 28, alignment: .leading)
            .accessibilityLabel("Variable symbol")
    }
}

private struct MathMLWebView {
    let mathML: String
    let pointSize: CGFloat
    var minimumHeight: CGFloat = 44

    private var html: String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            :root { color-scheme: light dark; }
            html, body { margin: 0; padding: 0; background: transparent; }
            body {
              display: flex;
              align-items: center;
              justify-content: flex-start;
              min-height: \(minimumHeight)px;
              font-family: -apple-system, BlinkMacSystemFont, sans-serif;
              font-size: \(pointSize)px;
              color: -apple-system-label;
              overflow: hidden;
            }
            math { font-size: 1.08em; }
          </style>
        </head>
        <body>\(mathML)</body>
        </html>
        """
    }
}

#if os(iOS)
extension MathMLWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        view.loadHTMLString(html, baseURL: nil)
    }
}
#elseif os(macOS)
extension MathMLWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        view.loadHTMLString(html, baseURL: nil)
    }
}
#endif
