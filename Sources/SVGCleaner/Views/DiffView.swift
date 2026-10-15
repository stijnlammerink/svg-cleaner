import SwiftUI

/// Git-style diff of the original and optimized SVG, both formatted the same way so only real changes show.
struct DiffPane: View {
    @Environment(AppModel.self) private var model
    let file: SVGFile
    let output: String?

    @State private var diff: LineDiffResult?

    var body: some View {
        Group {
            if let diff {
                if diff.hasChanges {
                    VStack(spacing: 0) {
                        DiffSummary(diff: diff)
                        Divider()
                        DiffLines(diff: diff)
                    }
                } else {
                    ContentUnavailableView("No changes", systemImage: "equal",
                                           description: Text("The optimized SVG has the same markup as the original."))
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: "\(file.id)-\(file.original.hashValue)-\(output?.hashValue ?? 0)") {
            diff = nil
            guard let output else { return }
            diff = await model.diff(original: file.original, optimized: output)
        }
    }
}

private struct DiffSummary: View {
    let diff: LineDiffResult

    var body: some View {
        HStack(spacing: 14) {
            Text("−\(diff.removed) line\(diff.removed == 1 ? "" : "s")").foregroundStyle(.red)
            Text("+\(diff.added) line\(diff.added == 1 ? "" : "s")").foregroundStyle(.green)
            Spacer()
            Text("Both versions are formatted the same way for comparison")
                .foregroundStyle(.tertiary)
        }
        .font(.callout.monospacedDigit())
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }
}

private struct DiffLines: View {
    let diff: LineDiffResult

    private static let fontSize: CGFloat = 12
    private static let charWidth = ("0" as NSString).size(withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
    ]).width

    var body: some View {
        let gutter = CGFloat(String(diff.maxLineNumber).count) * Self.charWidth + 20
        let textWidth = CGFloat(diff.maxLineLength) * Self.charWidth + 40

        GeometryReader { proxy in
            let rowWidth = max(proxy.size.width, gutter * 2 + 28 + textWidth)
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(diff.lines) { line in
                        DiffRow(line: line, gutter: gutter)
                            .frame(width: rowWidth, alignment: .leading)
                    }
                }
                .padding(.vertical, 6)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
        .font(.system(size: Self.fontSize, design: .monospaced))
    }
}

private struct DiffRow: View {
    let line: DiffLine
    let gutter: CGFloat

    var body: some View {
        if case .collapsed(let count) = line.kind {
            Text("⋯  \(count) unchanged lines")
                .foregroundStyle(.tertiary)
                .padding(.leading, gutter * 2 + 28)
                .frame(height: 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.fill.quaternary)
        } else {
            HStack(spacing: 0) {
                number(line.oldNumber)
                number(line.newNumber)
                Text(sign)
                    .foregroundStyle(accent ?? .secondary)
                    .frame(width: 28)
                Text(SVGSyntax.highlight(line.text))
                    .fixedSize()
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .frame(height: 20)
            .background(accent.map { $0.opacity(0.16) } ?? .clear)
        }
    }

    private var sign: String {
        switch line.kind {
        case .removed: "-"
        case .added: "+"
        default: ""
        }
    }

    private var accent: Color? {
        switch line.kind {
        case .removed: .red
        case .added: .green
        default: nil
        }
    }

    private func number(_ value: Int?) -> some View {
        Text(value.map(String.init) ?? "")
            .foregroundStyle(.tertiary)
            .frame(width: gutter, alignment: .trailing)
            .padding(.trailing, 4)
            .frame(maxHeight: .infinity)
            .background(accent.map { $0.opacity(0.1) } ?? .clear)
    }
}

/// Light XML highlighting: tag names, attribute names and quoted values.
enum SVGSyntax {
    private static let tag = #/<\/?[A-Za-z][\w:.-]*|\/?>/#
    private static let attribute = #/[A-Za-z_:][\w:.-]*(?==)/#
    private static let value = #/"[^"]*"|'[^']*'/#

    static func highlight(_ line: String) -> AttributedString {
        var result = AttributedString(line)
        apply(tag, color: Color(nsColor: .systemPink), in: line, to: &result)
        apply(attribute, color: Color(nsColor: .systemOrange), in: line, to: &result)
        apply(value, color: Color(nsColor: .systemTeal), in: line, to: &result)
        return result
    }

    private static func apply(_ regex: some RegexComponent, color: Color, in line: String, to result: inout AttributedString) {
        for match in line.matches(of: regex) {
            guard let lower = AttributedString.Index(match.range.lowerBound, within: result),
                  let upper = AttributedString.Index(match.range.upperBound, within: result)
            else { continue }
            result[lower..<upper].foregroundColor = color
        }
    }
}
