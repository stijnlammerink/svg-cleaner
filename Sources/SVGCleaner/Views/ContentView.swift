import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var isDropTargeted = false
    @State private var showsInspector = true

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            FileListView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 400)
        } detail: {
            PreviewView()
                .inspector(isPresented: $showsInspector) {
                    SettingsInspector()
                        .inspectorColumnWidth(min: 300, ideal: 340, max: 440)
                }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.copySelected()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy optimized SVG")
                .disabled(model.selectedFile.flatMap { model.results[$0.id]?.output } == nil)
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Save All to Folder…") { model.exportToFolder() }
                    Button("Overwrite Originals…", role: .destructive) {
                        model.isConfirmingOverwrite = true
                    }
                    .disabled(model.overwritableCount == 0)
                } label: {
                    Label(exportTitle, systemImage: "square.and.arrow.down.on.square")
                }
                .buttonStyle(.glassProminent)
                .help("Export optimized SVGs")
                .disabled(model.exportable.isEmpty)
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsInspector.toggle()
                } label: {
                    Label("Settings", systemImage: "sidebar.trailing")
                }
                .help(showsInspector ? "Hide settings" : "Show settings")
            }
        }
        .navigationTitle(model.selectedFile?.name ?? "SVG Cleaner")
        .dropDestination(for: URL.self) { urls, _ in
            if model.add(urls: urls) { return true }
            model.show(Toast(kind: .failure, title: "No SVG files found in the drop"))
            return false
        } isTargeted: { isDropTargeted = $0 }
        .overlay { if isDropTargeted { DropOverlay() } }
        .overlay(alignment: .bottom) { ToastView() }
        .alert(overwriteTitle, isPresented: $model.isConfirmingOverwrite) {
            Button("Overwrite", role: .destructive) { model.overwriteOriginals() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The original SVG files on disk will be replaced with their optimized versions. This can't be undone. Files added without a known path are skipped.")
        }
    }

    private var exportTitle: String {
        let count = model.exportable.count
        return count > 0 ? "Export (\(count))" : "Export"
    }

    private var overwriteTitle: String {
        let count = model.overwritableCount
        return "Overwrite \(count) original file\(count == 1 ? "" : "s")?"
    }
}

private struct DropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.tint.opacity(0.08))
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(.tint, style: StrokeStyle(lineWidth: 2.5, dash: [10, 8]))
                .padding(20)
            VStack(spacing: 14) {
                Image(systemName: "arrow.down.document.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text("Drop to add SVGs")
                    .font(.title2.weight(.semibold))
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 36)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct ToastView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            if let toast = model.toast {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: toast.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(toast.kind == .success ? .green : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toast.title).font(.body.weight(.medium))
                        if let detail = toast.detail {
                            Text(detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .frame(maxWidth: 440)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { model.toast = nil }
            }
        }
        .animation(.spring(duration: 0.3), value: model.toast)
    }
}
