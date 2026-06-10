import SwiftUI

struct TopToolbarView: View {
    var state: CloudwardAppState

    var body: some View {
        HStack(spacing: 12) {
            Button {
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text(state.currentTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                Text(state.currentSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                state.presentReleasePreview()
            } label: {
                Label("全部归云", systemImage: "icloud.and.arrow.up.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(CloudwardColors.celadon, in: RoundedRectangle(cornerRadius: 8))
            .opacity(state.canPrepareRelease ? 1 : 0.45)
            .disabled(!state.canPrepareRelease)
        }
        .padding(.horizontal, 18)
        .background(CloudwardColors.card.opacity(0.72))
    }
}
