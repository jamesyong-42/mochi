import SwiftUI

struct MochiWizard: View {
    @Environment(VMManager.self) private var vmManager
    @Environment(IPSWService.self) private var ipswService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case create
        case edit(VMConfig)
    }

    let mode: Mode

    @State private var vmName: String = "My Mac"
    @State private var cpuCount: Double = Double(max(2, ProcessInfo.processInfo.processorCount / 2))
    @State private var memoryInGB: Double = 8
    @State private var diskSizeInGB: Double = 64
    @State private var colorKey: MochiColorKey = .blue
    @State private var isCreating = false
    @State private var showAdvanced = false

    // Edit-mode state
    @State private var editSharedFolders: [SharedFolder] = []
    @State private var minDiskSize: Double = 32

    private let maxCPU = Double(ProcessInfo.processInfo.processorCount)
    private let maxMemory = Double(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))

    private var isDark: Bool { colorScheme == .dark }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var editConfig: VMConfig? {
        if case .edit(let config) = mode { return config }
        return nil
    }

    private var theme: MochiTheme {
        MochiTheme.forKey(colorKey)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isCreating {
                installingView
            } else {
                formView
            }
        }
        .frame(minWidth: 440, idealWidth: 440)
        .interactiveDismissDisabled(isCreating)
        .onAppear {
            if let config = editConfig {
                vmName = config.name
                cpuCount = Double(config.cpuCount)
                memoryInGB = Double(config.memoryInGB)
                diskSizeInGB = Double(config.diskSizeInGB)
                colorKey = config.colorKey
                editSharedFolders = config.sharedFolders
                minDiskSize = Double(config.diskSizeInGB)
            } else {
                colorKey = .random
            }
        }
    }

    // MARK: - Form View

    private var formView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditMode ? "Edit Mac" : "New Mac")
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 32) {
                    nameInput

                    if isEditMode {
                        resourcesSection
                        advancedSection
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }

            footerButtons
        }
    }

    // MARK: - Name Input

    private var nameInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            TextField("My New Mac", text: $vmName)
                .font(.body.bold())
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isDark ? Color.black.opacity(0.2) : Color.black.opacity(0.05))
                )
        }
    }

    // MARK: - Resources Section

    private var resourcesSection: some View {
        VStack(spacing: 20) {
            sliderRow(
                label: "CPU Cores",
                value: $cpuCount,
                range: 2...maxCPU,
                step: 1,
                display: "\(Int(cpuCount)) Cores"
            )

            sliderRow(
                label: "Memory",
                value: $memoryInGB,
                range: 4...maxMemory,
                step: 1,
                display: "\(Int(memoryInGB)) GB"
            )

            sliderRow(
                label: "Disk Size",
                value: $diskSizeInGB,
                range: (isEditMode ? minDiskSize : 32)...512,
                step: 8,
                display: "\(Int(diskSizeInGB)) GB"
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.5))
        )
    }

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        display: String
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(display)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
            }

            Slider(value: value, in: range, step: step)
        }
    }

    // MARK: - Advanced Section (Edit Mode)

    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: 16) {
                if let config = editConfig {
                    SharedFolderPicker(folders: $editSharedFolders)

                    Divider()

                    infoRow(label: "Display", value: "\(config.displayWidth)\u{00D7}\(config.displayHeight) @ \(config.displayPPI) PPI")

                    infoRow(
                        label: "Disk Usage",
                        value: ByteCountFormatter.string(
                            fromByteCount: StorageService.vmDiskUsage(for: config.id),
                            countStyle: .file
                        )
                    )

                    infoRow(label: "MAC Address", value: config.macAddress)
                }
            }
            .padding(.top, 12)
        } label: {
            Text("Advanced")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .tint(.secondary)
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button(isEditMode ? "Save Changes" : "Create Mac") {
                if isEditMode {
                    saveChanges()
                } else {
                    createVM()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(vmName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Installing View

    private var installingView: some View {
        VStack(spacing: 32) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .frame(width: 80, height: 80)

            VStack(spacing: 12) {
                Text("Creating Mac...")
                    .font(.title2.bold())

                Group {
                    if ipswService.isDownloading {
                        VStack(spacing: 12) {
                            Text("Downloading System Image...")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            progressBar(value: ipswService.downloadProgress)

                            HStack {
                                Text("0%")
                                Spacer()
                                Text("\(Int(ipswService.downloadProgress * 100))%")
                            }
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        }
                    } else if let session = vmManager.sessions.values.first(where: { $0.state == .installing }) {
                        VStack(spacing: 12) {
                            Text("Installing macOS...")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            progressBar(value: session.installProgress)

                            HStack {
                                Text("0%")
                                Spacer()
                                Text("\(Int(session.installProgress * 100))%")
                            }
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        }
                    } else {
                        Text("Initializing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 280)
            }

            Spacer()
        }
        .padding(40)
        .frame(height: 420)
    }

    private func progressBar(value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))

                Capsule()
                    .fill(isDark ? .white : .black)
                    .frame(width: max(0, geo.size.width * value))
                    .animation(.spring(response: 0.5), value: value)
            }
        }
        .frame(height: 8)
    }

    // MARK: - Actions

    private func createVM() {
        isCreating = true
        Task {
            await vmManager.createVM(
                name: vmName,
                cpuCount: Int(cpuCount),
                memoryInGB: Int(memoryInGB),
                diskSizeInGB: Int(diskSizeInGB)
            )
            if var newVM = vmManager.virtualMachines.last(where: { $0.name == vmName }) {
                newVM.colorKey = colorKey
                vmManager.updateConfig(newVM)
            }
            isCreating = false
            dismiss()
        }
    }

    private func saveChanges() {
        guard var config = editConfig else { return }
        config.name = vmName
        config.cpuCount = Int(cpuCount)
        config.memoryInGB = Int(memoryInGB)
        config.diskSizeInGB = Int(diskSizeInGB)
        config.colorKey = colorKey
        config.sharedFolders = editSharedFolders
        vmManager.updateConfig(config)
        dismiss()
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
    }
}
