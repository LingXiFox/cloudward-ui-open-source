import SwiftUI
import SwiftData

struct ContentView: View {
    @Bindable var state: CloudwardAppState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if state.needsOnboarding {
                OnboardingView(state: state)
            } else {
                HStack(spacing: 0) {
                    SidebarView(state: state)
                        .frame(width: 224)

                    Divider()

                    VStack(spacing: 0) {
                        TopToolbarView(state: state)
                            .frame(height: 52)

                        Divider()

                        FileBrowserView(state: state)
                    }
                }
            }
        }
        .background(CloudwardColors.panel)
        .sheet(isPresented: $state.isReleasePreviewPresented) {
            ReleaseFlowView(state: state)
                .frame(width: 1120, height: 640)
        }
        .onChange(of: state.pendingHistoryDraft?.id) {
            persistPendingHistoryIfNeeded()
        }
        .task {
            state.bootstrap()
        }
    }

    private func persistPendingHistoryIfNeeded() {
        guard let draft = state.consumePendingHistoryDraft(),
              draft.releasedBytes > 0 || draft.fileCount > 0 else {
            return
        }

        modelContext.insert(ReleaseHistoryRecord(draft: draft))
        try? modelContext.save()
    }
}

#Preview {
    ContentView(state: CloudwardAppState())
}
