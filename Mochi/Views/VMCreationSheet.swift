import SwiftUI

struct VMCreationSheet: View {
    @Environment(VMManager.self) private var vmManager
    @Environment(IPSWService.self) private var ipswService
    @Environment(\.dismiss) private var dismiss

    @State private var vmName = "My VM"
    @State private var cpuCount: Double = Double(max(2, ProcessInfo.processInfo.processorCount / 2))
    @State private var memoryInGB: Double = 8
    @State private var diskSizeInGB: Double = 64
    @State private var isCreating = false

    private let maxCPU = Double(ProcessInfo.processInfo.processorCount)
    private let maxMemory = Double(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))

    var body: some View {
        VStack(spacing: 0) {
            if isCreating {
                creatingView
            } else {
                configurationForm
            }

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isCreating)

                Spacer()

                if !isCreating {
                    Button("Create") {
                        isCreating = true
                        Task {
                            await vmManager.createVM(
                                name: vmName,
                                cpuCount: Int(cpuCount),
                                memoryInGB: Int(memoryInGB),
                                diskSizeInGB: Int(diskSizeInGB)
                            )
                            isCreating = false
                            dismiss()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(vmName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 480)
    }

    // MARK: - Configuration Form

    private var configurationForm: some View {
        Form {
            Section("Name") {
                TextField("VM Name", text: $vmName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Virtual machine name")
            }

            Section("Resources") {
                ResourceSlider(
                    title: "CPU Cores",
                    value: $cpuCount,
                    range: 2...maxCPU,
                    step: 1,
                    unit: "cores"
                )

                ResourceSlider(
                    title: "Memory",
                    value: $memoryInGB,
                    range: 4...maxMemory,
                    step: 1,
                    unit: "GB"
                )

                ResourceSlider(
                    title: "Disk Size",
                    value: $diskSizeInGB,
                    range: 32...512,
                    step: 8,
                    unit: "GB"
                )
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Creating View (download + install progress)

    private var creatingView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Creating \"\(vmName)\"")
                .font(.title2)
                .fontWeight(.semibold)

            if ipswService.isDownloading {
                ProgressOverlay(
                    title: "Downloading macOS Restore Image…",
                    progress: ipswService.downloadProgress,
                    downloadedBytes: ipswService.downloadedBytes,
                    totalBytes: ipswService.totalBytes,
                    speed: ipswService.downloadSpeed
                )
            } else if let session = vmManager.sessions.values.first(where: { $0.state == .installing }) {
                ProgressOverlay(
                    title: "Installing macOS…",
                    progress: session.installProgress
                )
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Preparing…")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
