import SwiftUI

struct ByteValueText: View {
    let bytes: Int64
    var numberSize: CGFloat
    var unitSize: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(bytes: Int64, numberSize: CGFloat = 34, unitSize: CGFloat = 16) {
        self.bytes = bytes
        self.numberSize = numberSize
        self.unitSize = unitSize
    }

    var body: some View {
        let parts = bytes.cloudwardByteParts

        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(parts.value)
                .font(.system(size: numberSize, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(CloudwardColors.inkBlue)
                .animation(reduceMotion ? .default : Motion.standard, value: bytes)

            if parts.unit.isEmpty == false {
                Text(parts.unit)
                    .font(.system(size: unitSize, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
