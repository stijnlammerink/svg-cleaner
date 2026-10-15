import SwiftUI
import WebKit

/// Renders SVG markup with WebKit, so previews match how browsers display the file.
struct SVGPreview: NSViewRepresentable {
    let svg: String?

    func makeNSView(context: Context) -> PassiveWebView {
        let view = PassiveWebView()
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ view: PassiveWebView, context: Context) {
        let html = Self.html(for: svg)
        guard view.renderedHTML != html else { return }
        view.renderedHTML = html
        view.loadHTMLString(html, baseURL: nil)
    }

    // An <img> keeps the SVG sandboxed, but there currentColor is always black. Substitute the label
    // color per appearance so currentColor icons stay visible in dark mode.
    private static func html(for svg: String?) -> String {
        let image = svg.map { svg in
            """
            <picture>
              <source media="(prefers-color-scheme: dark)" srcset="\(dataURL(svg, currentColor: "#f5f5f7"))">
              <img src="\(dataURL(svg, currentColor: "#1d1d1f"))">
            </picture>
            """
        } ?? ""
        return """
        <!doctype html>
        <meta name="color-scheme" content="light dark">
        <style>
          :root { --base: #f4f4f5; --tile: rgba(0, 0, 0, 0.06); }
          @media (prefers-color-scheme: dark) { :root { --base: #1f1f22; --tile: rgba(255, 255, 255, 0.06); } }
          html, body { margin: 0; height: 100%; }
          body {
            display: flex;
            background-color: var(--base);
            background-image:
              linear-gradient(45deg, var(--tile) 25%, transparent 25%),
              linear-gradient(-45deg, var(--tile) 25%, transparent 25%),
              linear-gradient(45deg, transparent 75%, var(--tile) 75%),
              linear-gradient(-45deg, transparent 75%, var(--tile) 75%);
            background-size: 16px 16px;
            background-position: 0 0, 0 8px, 8px -8px, -8px 0;
          }
          picture { flex: 1; display: flex; min-width: 0; min-height: 0; }
          img { flex: 1; min-width: 0; min-height: 0; object-fit: contain; padding: 24px; box-sizing: border-box; }
        </style>
        \(image)
        """
    }

    private static func dataURL(_ svg: String, currentColor: String) -> String {
        let colored = svg.replacingOccurrences(of: "currentColor", with: currentColor, options: .caseInsensitive)
        return "data:image/svg+xml;base64,\(Data(colored.utf8).base64EncodedString())"
    }
}

/// A web view that ignores mouse and drag events, so clicks and file drops reach the SwiftUI window.
final class PassiveWebView: WKWebView {
    var renderedHTML: String?

    init() {
        super.init(frame: .zero, configuration: WKWebViewConfiguration())
        unregisterDraggedTypes()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func registerForDraggedTypes(_ newTypes: [NSPasteboard.PasteboardType]) {}

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
