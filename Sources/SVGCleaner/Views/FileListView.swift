import SwiftUI

struct FileListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List(selection: $model.selection) {
            ForEach(model.files) { file in
                FileRow(file: file, result: model.results[file.id])
                    .tag(file.id)
                    .onDrag { model.dragItem(for: file) }
                    .contextMenu {
                        Button("Save As…") { model.save(file.id) }
                            .disabled(model.results[file.id]?.output == nil)
                        Divider()
                        Button("Remove") { model.remove(file.id) }
                    }
            }
        }
        .onDeleteCommand {
            if let id = model.selection { model.remove(id) }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { model.chooseFiles() } label: { Label("Add SVG files", systemImage: "plus") }
                    .help("Add SVG files")
                Button { model.pasteFromClipboard() } label: {
                    Label("Paste SVG", systemImage: "list.clipboard")
                }
                .help("Paste SVG from clipboard")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !model.files.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(model.files.count) file\(model.files.count == 1 ? "" : "s")")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        if let total = model.totalSavings {
                            Text(total.bytes >= 0
                                 ? "\(Format.bytes(total.bytes)) saved (\(Format.percent(total.percent)))"
                                 : "\(Format.bytes(-total.bytes)) larger (\(Format.percent(total.percent)))")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(total.bytes > 0 ? .green : .secondary)
                        }
                    }
                    Spacer()
                    Button("Clear All") { model.clear() }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }
}

private struct FileRow: View {
    let file: SVGFile
    let result: SVGResult?

    var body: some View {
        HStack(spacing: 8) {
            Thumbnail(image: file.thumbnail)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 4)
            SavingsBadge(originalSize: file.originalSize, result: result)
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        guard let size = result?.size else { return Format.bytes(file.originalSize) }
        return "\(Format.bytes(file.originalSize)) → \(Format.bytes(size))"
    }
}

private struct Thumbnail: View {
    let image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "questionmark.square.dashed").foregroundStyle(.secondary)
            }
        }
        .frame(width: 18, height: 18)
        .padding(3)
        .background(.white, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.separator))
    }
}

private struct SavingsBadge: View {
    let originalSize: Int
    let result: SVGResult?

    var body: some View {
        switch result {
        case .optimized(let output):
            let percent = Format.savings(from: originalSize, to: output.utf8.count)
            badge(Format.percent(percent), color: percent > 0 ? .green : .secondary)
        case .failed:
            badge("error", color: .red)
        case .loading, nil:
            ProgressView().controlSize(.mini)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
    }
}
