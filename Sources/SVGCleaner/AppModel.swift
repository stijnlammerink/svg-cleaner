import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class AppModel {
    var files: [SVGFile] = []
    var results: [SVGFile.ID: SVGResult] = [:]
    var selection: SVGFile.ID?
    var toast: Toast?
    var isConfirmingOverwrite = false

    var settings = SettingsStore.load() {
        didSet {
            guard settings != oldValue else { return }
            SettingsStore.save(settings)
            reoptimizeAll()
        }
    }

    private let optimizer = SVGOptimizer()
    private var jobs: [Task<Void, Never>] = []

    var selectedFile: SVGFile? { files.first { $0.id == selection } }

    var exportable: [(file: SVGFile, output: String)] {
        files.compactMap { file in results[file.id]?.output.map { (file, $0) } }
    }

    var overwritableCount: Int { exportable.filter { $0.file.url != nil }.count }

    // MARK: File intake

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = "Choose SVG files"
        panel.allowedContentTypes = [.svg]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK else { return }
        add(urls: panel.urls)
    }

    /// Adds SVG files, expanding folders recursively. Returns whether anything was added.
    @discardableResult
    func add(urls: [URL]) -> Bool {
        var loaded: [SVGFile] = []
        var failures = 0
        for url in svgURLs(in: urls) {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                loaded.append(SVGFile(name: url.lastPathComponent, original: content, url: url))
            } else {
                failures += 1
            }
        }
        if failures > 0 {
            show(Toast(kind: .failure, title: "\(failures) file\(failures == 1 ? "" : "s") could not be read"))
        }
        add(loaded)
        return !loaded.isEmpty
    }

    func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty, add(urls: urls) {
            return
        }

        let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard text.range(of: #"<svg[\s>]"#, options: [.regularExpression, .caseInsensitive]) != nil else {
            show(Toast(kind: .failure, title: "Clipboard doesn't contain SVG markup"))
            return
        }
        let pastedCount = files.filter { $0.name.hasPrefix("Pasted SVG") }.count
        let name = pastedCount > 0 ? "Pasted SVG \(pastedCount + 1).svg" : "Pasted SVG.svg"
        add([SVGFile(name: name, original: text)])
    }

    func remove(_ id: SVGFile.ID) {
        guard let index = files.firstIndex(where: { $0.id == id }) else { return }
        files.remove(at: index)
        results[id] = nil
        if selection == id {
            selection = files.indices.contains(index) ? files[index].id : files.last?.id
        }
    }

    func clear() {
        cancelJobs()
        files = []
        results = [:]
        selection = nil
    }

    private func add(_ incoming: [SVGFile]) {
        guard !incoming.isEmpty else { return }
        files.append(contentsOf: incoming)
        if selection == nil {
            selection = incoming[0].id
        }
        optimize(incoming)
    }

    private func svgURLs(in urls: [URL]) -> [URL] {
        urls.flatMap { url -> [URL] in
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory else {
                return url.pathExtension.lowercased() == "svg" ? [url] : []
            }
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            let found = (enumerator?.allObjects as? [URL] ?? []).filter { $0.pathExtension.lowercased() == "svg" }
            return found.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        }
    }

    // MARK: Optimization

    private func reoptimizeAll() {
        cancelJobs()
        optimize(files)
    }

    private func optimize(_ batch: [SVGFile]) {
        let settings = settings
        for file in batch {
            results[file.id] = .loading
        }
        let job = Task { [optimizer] in
            for file in batch {
                let result = await optimizer.optimize(file.original, settings: settings)
                guard !Task.isCancelled, settings == self.settings else { return }
                if results[file.id] != nil {
                    results[file.id] = result
                }
            }
        }
        jobs.append(job)
    }

    private func cancelJobs() {
        jobs.forEach { $0.cancel() }
        jobs = []
    }

    // MARK: Output

    func copySelected() {
        guard let file = selectedFile, let output = results[file.id]?.output else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        show(Toast(kind: .success, title: "Copied optimized SVG"))
    }

    func exportToFolder() {
        let items = exportable
        guard !items.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.title = "Choose export folder"
        panel.prompt = "Export"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        let errors = write(items.map { (folder.appendingPathComponent($0.file.name), $0.output) })
        let written = items.count - errors.count
        if errors.isEmpty {
            show(Toast(kind: .success, title: "Saved \(written) file\(written == 1 ? "" : "s")", detail: folder.path))
        } else {
            show(Toast(kind: .failure, title: "Saved \(written), \(errors.count) failed", detail: errors.first))
        }
    }

    func overwriteOriginals() {
        let items = exportable.compactMap { item in item.file.url.map { ($0, item.output) } }
        guard !items.isEmpty else {
            show(Toast(kind: .failure, title: "No files have a known path to overwrite"))
            return
        }
        let errors = write(items)
        let written = items.count - errors.count
        if errors.isEmpty {
            show(Toast(kind: .success, title: "Overwrote \(written) file\(written == 1 ? "" : "s")"))
        } else {
            show(Toast(kind: .failure, title: "Overwrote \(written), \(errors.count) failed", detail: errors.first))
        }
    }

    private func write(_ items: [(URL, String)]) -> [String] {
        items.compactMap { url, content in
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                return nil
            } catch {
                return "\(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }

    // MARK: Feedback

    func show(_ toast: Toast) {
        self.toast = toast
        Task {
            try? await Task.sleep(for: .seconds(3))
            if self.toast?.id == toast.id {
                self.toast = nil
            }
        }
    }
}
