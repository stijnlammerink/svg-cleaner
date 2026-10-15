import Foundation

struct OptimizeSettings: Codable, Equatable {
    var multipass = false
    var precision = 3
    var pretty = true
    var currentColor = true
    var plugins = PluginCatalog.defaultState

    init() {}

    // Merges saved values over defaults so newly added plugins keep sane values.
    init(from decoder: Decoder) throws {
        let defaults = OptimizeSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        multipass = try container.decodeIfPresent(Bool.self, forKey: .multipass) ?? defaults.multipass
        precision = try container.decodeIfPresent(Int.self, forKey: .precision) ?? defaults.precision
        pretty = try container.decodeIfPresent(Bool.self, forKey: .pretty) ?? defaults.pretty
        currentColor = try container.decodeIfPresent(Bool.self, forKey: .currentColor) ?? defaults.currentColor
        let saved = try container.decodeIfPresent([String: Bool].self, forKey: .plugins) ?? [:]
        plugins = defaults.plugins.merging(saved) { _, saved in saved }
    }

    func isEnabled(_ plugin: String) -> Bool {
        plugins[plugin] ?? false
    }

    var svgoConfig: [String: Any] {
        var overrides: [String: Any] = [:]
        for name in PluginCatalog.presetDefault where plugins[name] == false {
            overrides[name] = false
        }
        if currentColor, isEnabled("convertColors") {
            overrides["convertColors"] = ["currentColor": true]
        }

        var pluginList: [Any] = [["name": "preset-default", "params": ["overrides": overrides]]]
        for plugin in PluginCatalog.all where isEnabled(plugin.name) && !PluginCatalog.presetDefault.contains(plugin.name) {
            pluginList.append(plugin.name)
        }

        var config: [String: Any] = [
            "multipass": multipass,
            "floatPrecision": precision,
            "plugins": pluginList,
        ]
        if pretty {
            config["js2svg"] = ["pretty": true, "indent": 2]
        }
        return config
    }
}

enum SettingsStore {
    private static let key = "optimizeSettings"

    static func load() -> OptimizeSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(OptimizeSettings.self, from: data)
        else { return OptimizeSettings() }
        return settings
    }

    static func save(_ settings: OptimizeSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
