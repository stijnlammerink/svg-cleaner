import SwiftUI

@main
struct SVGCleanerApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Window("SVG Cleaner", id: "main") {
            ContentView()
                .environment(delegate.model)
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 1040, height: 720)
        .commands {
            AppCommands(model: delegate.model)
        }

        Settings {
            PreferencesView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Appearance.apply(Appearance.stored)
    }

    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        model.add(urls: urls)
    }
}

struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Files…") { model.chooseFiles() }
                .keyboardShortcut("o")
            Button("Paste SVG") { model.pasteFromClipboard() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            Divider()
            Button("Copy Optimized SVG") { model.copySelected() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(model.selectedFile.flatMap { model.results[$0.id]?.output } == nil)
            Button("Save All to Folder…") { model.exportToFolder() }
                .keyboardShortcut("e")
                .disabled(model.exportable.isEmpty)
            Button("Overwrite Originals…") { model.isConfirmingOverwrite = true }
                .disabled(model.overwritableCount == 0)
            Divider()
            Button("Remove All Files") { model.clear() }
                .disabled(model.files.isEmpty)
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    static var stored: Appearance {
        UserDefaults.standard.string(forKey: storageKey).flatMap(Appearance.init) ?? .system
    }

    @MainActor
    static func apply(_ appearance: Appearance) {
        NSApp.appearance = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
