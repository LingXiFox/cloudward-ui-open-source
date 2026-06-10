import AppKit
import SwiftUI

struct OnboardingView: View {
    @Bindable var state: CloudwardAppState

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(CloudwardColors.celadon.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(CloudwardColors.celadon)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 520)
            }

            HStack(spacing: 12) {
                Button {
                    openICloudSettings()
                } label: {
                    Label("打开系统设置", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)

                Button {
                    Task {
                        await state.refreshContainers()
                    }
                } label: {
                    Label("重新检测", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(CloudwardColors.celadon)
            }

            VStack(alignment: .leading, spacing: 10) {
                OnboardingStep(symbolName: "1.circle", title: "保留云端文件", detail: "归云只移除本地缓存副本,文件仍在 iCloud 中。")
                OnboardingStep(symbolName: "2.circle", title: "需要读取 iCloud Drive", detail: "如果 macOS 拦截访问,请在隐私与安全性中允许完全磁盘访问。")
                OnboardingStep(symbolName: "3.circle", title: "可随时重试", detail: "登录 iCloud 或授权后点重新检测,主界面会自动恢复。")
            }
            .padding(16)
            .frame(maxWidth: 520)
            .background(CloudwardColors.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(CloudwardColors.separator))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(CloudwardColors.moonWhite)
    }

    private var title: String {
        state.isICloudAccountAvailable ? "需要 iCloud Drive 权限" : "未检测到 iCloud Drive"
    }

    private var message: String {
        if let lastError = state.lastError {
            return lastError
        }

        return "请确认已登录 iCloud 并启用 iCloud Drive。若首次启动时无法读取 Mobile Documents,请授予完全磁盘访问权限。"
    }

    private func openICloudSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct OnboardingStep: View {
    let symbolName: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(CloudwardColors.celadon)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CloudwardColors.inkBlue)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
