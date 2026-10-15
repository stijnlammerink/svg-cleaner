import SwiftUI

/// Segmented picker with a Liquid Glass pill that slides to the selected segment.
/// The stock macOS segmented Picker swaps selection without this transition.
struct GlassSegmentedPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    @Namespace private var namespace
    // Animated separately from `selection` so only the pill moves; animating the binding itself
    // also animates the layout of the view that swaps in, including the split view around it.
    @State private var pillValue: Value?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == (pillValue ?? selection)
                Button {
                    selection = option.value
                    withAnimation(.bouncy(duration: 0.4, extraBounce: 0.1)) { pillValue = option.value }
                } label: {
                    Text(option.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .padding(.horizontal, 18)
                        .frame(height: 30)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(.clear)
                                    .glassEffect(.regular.interactive(), in: .capsule)
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.fill.tertiary, in: .capsule)
        .fixedSize()
        .onChange(of: selection) { _, value in
            if pillValue != value { pillValue = value }
        }
    }
}
