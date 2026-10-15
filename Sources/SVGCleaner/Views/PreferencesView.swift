import SwiftUI

struct PreferencesView: View {
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system

    var body: some View {
        Form {
            Picker("Theme", selection: $appearance) {
                ForEach(Appearance.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
        }
        .padding(20)
        .frame(width: 360)
        .onChange(of: appearance) { _, value in Appearance.apply(value) }
    }
}
