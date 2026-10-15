import AppKit

struct SVGFile: Identifiable {
    let id = UUID()
    let name: String
    /// Original location on disk, when known. Enables overwriting the original.
    let url: URL?
    let original: String
    let thumbnail: NSImage?

    init(name: String, original: String, url: URL? = nil) {
        self.name = name
        self.url = url
        self.original = original
        thumbnail = NSImage(data: Data(original.utf8))
    }

    var originalSize: Int { original.utf8.count }
}

enum SVGResult {
    case loading
    case optimized(String)
    case failed(String)

    var output: String? {
        if case .optimized(let output) = self { return output }
        return nil
    }

    var size: Int? { output?.utf8.count }
}

struct Toast: Identifiable, Equatable {
    enum Kind { case success, failure }

    let id = UUID()
    let kind: Kind
    let title: String
    var detail: String?
}

enum Format {
    static func bytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: kb < 10 ? "%.2f KB" : "%.1f KB", kb) }
        return String(format: "%.2f MB", kb / 1024)
    }

    /// Percentage saved from `before` to `after` (positive means smaller).
    static func savings(from before: Int, to after: Int) -> Double {
        guard before > 0 else { return 0 }
        return Double(before - after) / Double(before) * 100
    }

    static func percent(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let sign = rounded > 0 ? "-" : rounded < 0 ? "+" : ""
        let magnitude = abs(rounded)
        let number = magnitude == magnitude.rounded() ? String(Int(magnitude)) : String(magnitude)
        return "\(sign)\(number)%"
    }
}
