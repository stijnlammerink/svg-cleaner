import SwiftUI

struct PreviewView: View {
    @Environment(AppModel.self) private var model
    @State private var mode = Mode.compare

    enum Mode: String, CaseIterable {
        case compare = "Compare"
        case code = "Code"
    }

    var body: some View {
        if let file = model.selectedFile {
            detail(file: file, result: model.results[file.id])
        } else if model.files.isEmpty {
            WelcomeView()
        } else {
            ContentUnavailableView("Select a file", systemImage: "sidebar.left",
                                   description: Text("Choose a file from the list to preview it."))
        }
    }

    private func detail(file: SVGFile, result: SVGResult?) -> some View {
        let optimizedSize = result?.size
        let percent = optimizedSize.map { Format.savings(from: file.originalSize, to: $0) } ?? 0

        return VStack(spacing: 0) {
            HStack(spacing: 32) {
                Stat(label: "Original", value: Format.bytes(file.originalSize))
                Stat(label: "Optimized", value: optimizedSize.map(Format.bytes) ?? "-")
                Stat(label: "Saved", value: optimizedSize != nil ? Format.percent(percent) : "-",
                     highlight: percent > 0)
                Spacer()
                GlassSegmentedPicker(selection: $mode, options: Mode.allCases.map { ($0, $0.rawValue) })
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            if case .failed(let message) = result {
                ErrorCallout(message: message)
                    .padding(24)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else if mode == .compare {
                HStack(spacing: 16) {
                    ComparePanel(label: "Original", size: file.originalSize, content: file.original)
                    ComparePanel(label: "Optimized", size: optimizedSize, content: result?.output)
                }
                .padding(24)
            } else {
                CodeAndDiff(file: file, output: result?.output)
            }
        }
    }
}

/// The optimized code with its diff underneath. A hand-rolled divider instead of `VSplitView`,
/// which loops on constraint updates when a pane changes size (the diff loads asynchronously).
private struct CodeAndDiff: View {
    let file: SVGFile
    let output: String?

    @AppStorage("codeDiffSplit") private var split = 0.55
    @State private var dragStart: Double?

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let codeHeight = min(max(height * split, 120), max(height - 120, 120))

            VStack(spacing: 0) {
                CodeView(text: output ?? "")
                    .frame(height: codeHeight)
                divider(totalHeight: height)
                DiffPane(file: file, output: output)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private func divider(totalHeight: CGFloat) -> some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let start = dragStart ?? split
                        dragStart = start
                        guard totalHeight > 0 else { return }
                        split = min(max(start + value.translation.height / totalHeight, 0.15), 0.85)
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .help("Drag to resize")
    }
}

private struct Stat: View {
    let label: String
    let value: String
    var highlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(highlight ? .green : .primary)
        }
    }
}

private struct ComparePanel: View {
    let label: String
    let size: Int?
    let content: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.callout.weight(.semibold))
                Spacer()
                Text(size.map(Format.bytes) ?? "…")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            SVGPreview(svg: content)
                .clipShape(.rect(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.separator))
        }
    }
}

private struct ErrorCallout: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text("Could not optimize this file").font(.callout.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.red.opacity(0.1), in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.red.opacity(0.3)))
    }
}
