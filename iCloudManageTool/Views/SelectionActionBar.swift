import SwiftUI

struct SelectionActionBar: View {
    var state: CloudwardAppState

    var body: some View {
        HStack(spacing: 14) {
            Label("\(state.selectedNodes.count) 项", systemImage: "checkmark.circle.fill")
                .foregroundStyle(CloudwardColors.celadon)

            Text("预计释放 \(state.selectedBytes.cloudwardBytes)")
                .monospacedDigit()

            Divider()
                .frame(height: 20)

            Button {
                state.releaseSelection.removeAll()
            } label: {
                Label("清空", systemImage: "xmark")
            }

            Button {
                state.presentReleasePreview()
            } label: {
                Label("释放所选", systemImage: "icloud.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.selectedBytes <= 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 18, y: 6)
    }
}
