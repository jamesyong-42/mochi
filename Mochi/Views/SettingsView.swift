import SwiftUI

struct SettingsView: View {
    @Environment(VMManager.self) private var vmManager
    @Environment(IPSWService.self) private var ipswService

    @State private var totalUsage: Int64 = 0
    @State private var vmsUsage: Int64 = 0
    @State private var ipswUsage: Int64 = 0
    @State private var isCalculating = false
    @State private var showClearCacheConfirmation = false
    @State private var showClearAllConfirmation = false

    var body: some View {
        Form {
            Section("Storage Usage") {
                LabeledContent("Virtual Machines") {
                    Text(formattedSize(vmsUsage))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                LabeledContent("IPSW Cache") {
                    HStack(spacing: 8) {
                        Text(formattedSize(ipswUsage))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button("Clear") {
                            showClearCacheConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                LabeledContent("Total") {
                    Text(formattedSize(totalUsage))
                        .font(.body.monospacedDigit().weight(.semibold))
                }

                HStack {
                    if isCalculating {
                        ProgressView()
                            .controlSize(.small)
                        Text("Calculating…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Refresh") {
                        recalculate()
                    }
                    .disabled(isCalculating)
                }
            }

            Section("Danger Zone") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Clear All Data")
                            .font(.body)
                        Text("Delete all VMs, disk images, and cached downloads")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Clear All…", role: .destructive) {
                        showClearAllConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Locations") {
                LabeledContent("VM Storage") {
                    Text(StorageService.vmsBaseURL.path)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                LabeledContent("IPSW Cache") {
                    Text(StorageService.ipswCacheURL.path)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 420)
        .task {
            recalculate()
        }
        .confirmationDialog("Clear IPSW Cache?", isPresented: $showClearCacheConfirmation) {
            Button("Clear Cache", role: .destructive) {
                try? StorageService.clearIPSWCache()
                ipswService.cachedIPSWURL = nil
                recalculate()
            }
        } message: {
            Text("This will delete all cached macOS restore images. You'll need to re-download them when creating new VMs.")
        }
        .confirmationDialog("Clear All Mochi Data?", isPresented: $showClearAllConfirmation) {
            Button("Delete Everything", role: .destructive) {
                Task {
                    await vmManager.suspendAllRunningVMs()
                    for vm in vmManager.virtualMachines {
                        await vmManager.deleteVM(id: vm.id)
                    }
                    try? StorageService.clearIPSWCache()
                    ipswService.cachedIPSWURL = nil
                    recalculate()
                }
            }
        } message: {
            Text("This will permanently delete ALL virtual machines, disk images, and cached downloads. This cannot be undone.")
        }
    }

    private func recalculate() {
        isCalculating = true
        Task.detached {
            StorageService.cleanupTempFiles()
            let vms = StorageService.vmsDiskUsage()
            let ipsw = StorageService.ipswCacheDiskUsage()
            let total = StorageService.totalDiskUsage()
            await MainActor.run {
                vmsUsage = vms
                ipswUsage = ipsw
                totalUsage = total
                isCalculating = false
            }
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
