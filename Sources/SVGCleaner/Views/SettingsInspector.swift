import SwiftUI

struct SettingsInspector: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Form {
            Section("Options") {
                Toggle("Multipass", isOn: $model.settings.multipass)
                LabeledContent("Number precision") {
                    HStack(spacing: 8) {
                        Slider(value: precision, in: 0...8, step: 1)
                            .controlSize(.small)
                        Text("\(model.settings.precision)")
                            .monospacedDigit()
                            .frame(width: 14, alignment: .trailing)
                    }
                    .frame(maxWidth: 150)
                }
                Toggle("Format code", isOn: $model.settings.pretty)
                Toggle("currentColor fill", isOn: $model.settings.currentColor)
            }

            ForEach(PluginCatalog.categories) { category in
                Section(category.label) {
                    ForEach(category.plugins) { plugin in
                        Toggle(isOn: pluginBinding(plugin.name)) {
                            Text(plugin.label)
                        }
                        .help(plugin.description)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .controlSize(.small)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Text("Applies to all files")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset to Defaults") { model.settings = OptimizeSettings() }
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
    }

    private var precision: Binding<Double> {
        Binding(
            get: { Double(model.settings.precision) },
            set: { model.settings.precision = Int($0.rounded()) }
        )
    }

    private func pluginBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { model.settings.isEnabled(name) },
            set: { model.settings.plugins[name] = $0 }
        )
    }
}
