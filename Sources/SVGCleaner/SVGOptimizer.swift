import Foundation
import JavaScriptCore

/// Runs the bundled SVGO build inside JavaScriptCore. An actor because a JSContext must not be used concurrently.
actor SVGOptimizer {
    private let context: JSContext?
    private let setupError: String?

    init() {
        guard let url = Bundle.main.url(forResource: "svgo", withExtension: "js"),
              let script = try? String(contentsOf: url, encoding: .utf8)
        else {
            context = nil
            setupError = "svgo.js is missing from the app bundle"
            return
        }
        let context = JSContext()!
        context.evaluateScript(script)
        context.evaluateScript("function runSvgo(input, config) { return SVGOBundle.optimize(input, JSON.parse(config)).data; }")
        if let exception = context.exception {
            self.context = nil
            setupError = "Could not load SVGO: \(exception)"
        } else {
            self.context = context
            setupError = nil
        }
    }

    func optimize(_ svg: String, settings: OptimizeSettings) -> SVGResult {
        run(svg, config: settings.svgoConfig)
    }

    /// Pretty-prints the markup without optimizing it, so two versions can be compared line by line.
    func format(_ svg: String) -> String? {
        run(svg, config: ["plugins": [Any](), "js2svg": ["pretty": true, "indent": 2]]).output
    }

    private func run(_ svg: String, config: [String: Any]) -> SVGResult {
        guard let context, let run = context.objectForKeyedSubscript("runSvgo") else {
            return .failed(setupError ?? "SVGO is not available")
        }
        guard let configData = try? JSONSerialization.data(withJSONObject: config),
              let config = String(data: configData, encoding: .utf8)
        else {
            return .failed("Invalid optimizer settings")
        }

        let output = run.call(withArguments: [svg, config])
        if let exception = context.exception {
            context.exception = nil
            return .failed(exception.toString())
        }
        guard let output, output.isString, let data = output.toString() else {
            return .failed("SVGO returned no output")
        }
        return .optimized(data)
    }
}
