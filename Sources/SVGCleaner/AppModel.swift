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

    /// Combined result over all optimized files: bytes saved (negative when larger) and percentage.
    var totalSavings: (bytes: Int, percent: Double)? {
        let sizes = files.compactMap { file in results[file.id]?.size.map { (file.originalSize, $0) } }
        guard !sizes.isEmpty else { return nil }
        let before = sizes.reduce(0) { $0 + $1.0 }
        let after = sizes.reduce(0) { $0 + $1.1 }
        return (before - after, Format.savings(from: before, to: after))
    }

    /// Temporary copies handed to Finder when dragging a row out; never re-imported.
    private let dragDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("Drag", isDirectory: true)

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
        let ownDrags = dragDirectory.standardizedFileURL.path + "/"
        return urls.filter { !$0.standardizedFileURL.path.hasPrefix(ownDrags) }.flatMap { url -> [URL] in
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

    func diff(original: String, optimized: String) async -> LineDiffResult {
        let before = await optimizer.format(original) ?? original
        let after = await optimizer.format(optimized) ?? optimized
        return await Task.detached { LineDiff.compute(old: before, new: after) }.value
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

    func save(_ id: SVGFile.ID? = nil) {
        guard let file = files.first(where: { $0.id == (id ?? selection) }),
              let output = results[file.id]?.output
        else { return }

        let panel = NSSavePanel()
        panel.title = "Save optimized SVG"
        panel.nameFieldStringValue = file.name
        panel.allowedContentTypes = [.svg]
        panel.directoryURL = file.url?.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let outcome = write([(file.id, url, output)])
        if outcome.errors.isEmpty {
            show(Toast(kind: .success, title: "Saved \(url.lastPathComponent)", detail: url.deletingLastPathComponent().path))
        } else {
            show(Toast(kind: .failure, title: "Could not save", detail: outcome.errors.first))
        }
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

        var targets = exportTargets(for: items.map(\.file.name), in: folder, avoidingExisting: false)
        let existing = targets.filter { FileManager.default.fileExists(atPath: $0.path) }.count
        if existing > 0 {
            switch confirmReplace(existing: existing, folder: folder) {
            case .alertFirstButtonReturn:
                break
            case .alertSecondButtonReturn:
                targets = exportTargets(for: items.map(\.file.name), in: folder, avoidingExisting: true)
            default:
                return
            }
        }

        let outcome = write(zip(items, targets).map { item, target in (item.file.id, target, item.output) })
        let written = outcome.written.count
        if outcome.errors.isEmpty {
            show(Toast(kind: .success, title: "Saved \(written) file\(written == 1 ? "" : "s")", detail: folder.path))
        } else {
            show(Toast(kind: .failure, title: "Saved \(written), \(outcome.errors.count) failed", detail: outcome.errors.first))
        }
    }

    func overwriteOriginals() {
        let items = exportable.compactMap { item in item.file.url.map { (item.file.id, $0, item.output) } }
        guard !items.isEmpty else {
            show(Toast(kind: .failure, title: "No files have a known path to overwrite"))
            return
        }
        let outcome = write(items)

        // The optimized output is now the file on disk, so it becomes the new baseline.
        let contents = Dictionary(uniqueKeysWithValues: items.map { ($0.0, $0.2) })
        var updated: [SVGFile] = []
        files = files.map { file in
            guard outcome.written.contains(file.id), let content = contents[file.id] else { return file }
            let replaced = file.replacingOriginal(with: content)
            updated.append(replaced)
            return replaced
        }
        optimize(updated)

        let written = outcome.written.count
        if outcome.errors.isEmpty {
            show(Toast(kind: .success, title: "Overwrote \(written) file\(written == 1 ? "" : "s")"))
        } else {
            show(Toast(kind: .failure, title: "Overwrote \(written), \(outcome.errors.count) failed", detail: outcome.errors.first))
        }
    }

    /// Writes the optimized output to a temporary file that Finder can copy when a row is dragged out.
    func dragItem(for file: SVGFile) -> NSItemProvider {
        guard let output = results[file.id]?.output else { return NSItemProvider() }
        let folder = dragDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = folder.appendingPathComponent(file.name)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try output.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return NSItemProvider()
        }
        return NSItemProvider(contentsOf: url) ?? NSItemProvider()
    }

    private func write(_ items: [(id: SVGFile.ID, url: URL, content: String)]) -> (written: Set<SVGFile.ID>, errors: [String]) {
        var written: Set<SVGFile.ID> = []
        var errors: [String] = []
        for item in items {
            do {
                try item.content.write(to: item.url, atomically: true, encoding: .utf8)
                written.insert(item.id)
            } catch {
                errors.append("\(item.url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return (written, errors)
    }

    /// One target per name, numbering duplicates ("icon 2.svg") so files in a batch never overwrite each other.
    private func exportTargets(for names: [String], in folder: URL, avoidingExisting: Bool) -> [URL] {
        var taken: Set<String> = []
        return names.map { name in
            let base = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
            var candidate = name
            var number = 2
            while taken.contains(candidate.lowercased())
                || (avoidingExisting && FileManager.default.fileExists(atPath: folder.appendingPathComponent(candidate).path)) {
                candidate = ext.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(ext)"
                number += 1
            }
            taken.insert(candidate.lowercased())
            return folder.appendingPathComponent(candidate)
        }
    }

    private func confirmReplace(existing: Int, folder: URL) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = existing == 1
            ? "A file with this name already exists in “\(folder.lastPathComponent)”."
            : "\(existing) files with these names already exist in “\(folder.lastPathComponent)”."
        alert.informativeText = "Replace them with the optimized versions, or keep both by numbering the new files."
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Keep Both")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal()
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
