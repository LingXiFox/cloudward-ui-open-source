import SwiftUI
import SwiftData

struct SettingsView: View {
    var state: CloudwardAppState
    @Query(sort: \ReleaseHistoryRecord.createdAt, order: .reverse) private var records: [ReleaseHistoryRecord]
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @AppStorage("quickLookBeforeEviction") private var quickLookBeforeEviction = true
    @AppStorage("icloudPlanCapacityBytes") private var storedPlanCapacityBytes = ""
    @State private var planSelection: ICloudPlanCapacity = .unset
    @State private var customPlanGigabytes = ""
    @State private var exportedLogPath: String?

    private var totalReleasedBytes: Int64 {
        records.reduce(0) { $0 + $1.releasedBytes }
    }

    var body: some View {
        Form {
            Section("通用") {
                Toggle("释放前快速预览", isOn: $quickLookBeforeEviction)
                Toggle("显示菜单栏入口", isOn: $showMenuBarExtra)
            }

            Section("iCloud 套餐容量") {
                Picker("套餐容量", selection: $planSelection) {
                    ForEach(ICloudPlanCapacity.allCases) { plan in
                        Text(plan.title).tag(plan)
                    }
                }
                .onChange(of: planSelection) {
                    applyPlanSelection()
                }

                if planSelection == .custom {
                    HStack {
                        TextField("1–99999", text: $customPlanGigabytes)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .onSubmit(applyCustomPlan)
                            .onChange(of: customPlanGigabytes) {
                                applyCustomPlan()
                            }
                        Text("GB")
                            .foregroundStyle(.secondary)
                    }

                    if customPlanValidationMessage != nil {
                        Text(customPlanValidationMessage ?? "")
                            .font(.caption)
                            .foregroundStyle(CloudwardColors.amber)
                    }
                }

                Text("容量为手动设置,用于与 brctl 剩余配额组合估算全账户已用空间。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("历史") {
                HStack {
                    Text("已累计归云")
                    Spacer()
                    Text(totalReleasedBytes.cloudwardBytes)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(CloudwardColors.celadon)
                }
                HStack {
                    Text("历史记录")
                    Spacer()
                    Text("\(records.count) 次")
                        .foregroundStyle(.secondary)
                }
            }

            Section("诊断") {
                Button("导出诊断日志") {
                    exportedLogPath = state.exportedDiagnosticLogURL()?.path
                }

                if let exportedLogPath {
                    Text(exportedLogPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420)
        .onAppear {
            planSelection = ICloudPlanCapacity.selection(for: storedPlanCapacityBytes)
            if let bytes = Int64(storedPlanCapacityBytes), planSelection == .custom {
                customPlanGigabytes = String(bytes / 1_000_000_000)
            }
        }
        .onChange(of: storedPlanCapacityBytes) {
            planSelection = ICloudPlanCapacity.selection(for: storedPlanCapacityBytes)
        }
    }

    private var customPlanValidationMessage: String? {
        guard planSelection == .custom else {
            return nil
        }

        return ICloudPlanCapacity.storedBytes(for: customPlanGigabytes) == nil
            ? "请输入 1–99999 的正整数。"
            : nil
    }

    private func applyPlanSelection() {
        switch planSelection {
        case .unset:
            storedPlanCapacityBytes = ""
        case .custom:
            applyCustomPlan()
        default:
            storedPlanCapacityBytes = planSelection.bytes.map(String.init) ?? ""
        }
    }

    private func applyCustomPlan() {
        guard planSelection == .custom,
              let storedBytes = ICloudPlanCapacity.storedBytes(for: customPlanGigabytes) else {
            return
        }

        storedPlanCapacityBytes = storedBytes
    }
}
