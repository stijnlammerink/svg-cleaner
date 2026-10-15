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
            ContentUnavailableView {
                Label("Drop SVGs to optimize", systemImage: "wand.and.sparkles")
            } description: {
                Text("Drag and drop SVG files or folders anywhere, choose them manually, or paste SVG markup.")
            } actions: {
                Button("Choose Files…") { model.chooseFiles() }
                    .buttonStyle(.borderedProminent)
                Button("Paste SVG", systemImage: "list.clipboard") { model.pasteFromClipboard() }
            }
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
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
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
                CodeView(text: result?.output ?? "")
            }
        }
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
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
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
        .padding(12)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.red.opacity(0.3)))
    }
}
