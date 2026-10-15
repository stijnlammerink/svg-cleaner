import SwiftUI

struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 28) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)

            VStack(spacing: 10) {
                Text("Drop SVGs to optimize")
                    .font(.largeTitle.weight(.semibold))
                Text("Drag files or folders anywhere in this window,\nchoose them manually or paste SVG markup.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 14) {
                Button {
                    model.chooseFiles()
                } label: {
                    Text("Choose Files…").padding(.horizontal, 10)
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)

                Button {
                    model.pasteFromClipboard()
                } label: {
                    Text("Paste SVG").padding(.horizontal, 10)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.extraLarge)

            Text("⌘O to choose files  ·  ⇧⌘V to paste")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                .padding(20)
        }
    }
}
