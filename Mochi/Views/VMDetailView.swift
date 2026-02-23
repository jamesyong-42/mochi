import SwiftUI

struct VMDetailView: View {
    @Environment(VMManager.self) private var vmManager
    @Environment(\.openWindow) private var openWindow
    let vmID: UUID

    @State private var showForceStopConfirmation = false
    @State private var showDeleteConfirmation = false

    // Editable resource sliders
    @State private var editCPU: Double = 2
    @State private var editMemory: Double = 8
    @State private var editDisk: Double = 64
    @State private var minDiskSize: Double = 32

    private var config: VMConfig? {
        vmManager.virtualMachines.first { $0.id == vmID }
    }

    private var state: VMState {
        vmManager.state(for: vmID)
    }

    private var session: VMSession? {
        vmManager.session(for: vmID)
    }

    var body: some View {
        if let config {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection(config: config)
                    controlsSection
                    installProgressSection
                    configurationSection(config: config)
                    sharedFoldersSection(config: config)
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        openWindow(value: vmID)
                    } label: {
                        Label("Open Display", systemImage: "macwindow")
                    }
                    .disabled(state != .running)
                    .accessibilityLabel("Open VM display window")
                }
            }
            .confirmationDialog(
                "Force Stop VM?",
                isPresented: $showForceStopConfirmation
            ) {
                Button("Force Stop", role: .destructive) {
                    vmManager.forceStopVM(id: vmID)
                }
            } message: {
                Text("Force stopping may corrupt the virtual machine. Use graceful stop when possible.")
            }
            .confirmationDialog(
                "Delete VM?",
                isPresented: $showDeleteConfirmation
            ) {
                Button("Delete", role: .destructive) {
                    Task { await vmManager.deleteVM(id: vmID) }
                }
            } message: {
                Text("This will permanently delete the VM and its disk image. This cannot be undone.")
            }
        } else {
            ContentUnavailableView(
                "No VM Selected",
                systemImage: "desktopcomputer",
                description: Text("Select a virtual machine from the sidebar.")
            )
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection(config: VMConfig) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if state == .stopped {
                    TextField("VM Name", text: Binding(
                        get: { config.name },
                        set: { newValue in
                            guard var updated = self.config else { return }
                            updated.name = newValue
                            vmManager.updateConfig(updated)
                        }
                    ))
                    .font(.title)
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                } else {
                    Text(config.name)
                        .font(.title)
                        .fontWeight(.semibold)
                }
                StatusBadge(state: state)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var controlsSection: some View {
        HStack(spacing: 12) {
            if state.canStart {
                Button {
                    Task { await vmManager.startVM(id: vmID) }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .controlSize(.large)
                .accessibilityLabel("Start virtual machine")
            }

            if state.canStop {
                Button {
                    Task { await vmManager.stopVM(id: vmID) }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .accessibilityLabel("Stop virtual machine")

                Button {
                    showForceStopConfirmation = true
                } label: {
                    Label("Force Stop", systemImage: "xmark.octagon.fill")
                }
                .foregroundStyle(.red)
                .accessibilityLabel("Force stop virtual machine")
            }

            if state.canPause {
                Button {
                    Task { await vmManager.pauseVM(id: vmID) }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .accessibilityLabel("Pause virtual machine")
            }

            if state.canResume {
                Button {
                    Task { await vmManager.resumeVM(id: vmID) }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .accessibilityLabel("Resume virtual machine")
            }

            if state.canSuspend {
                Button {
                    Task { await vmManager.suspendVM(id: vmID) }
                } label: {
                    Label("Suspend", systemImage: "moon.fill")
                }
                .accessibilityLabel("Suspend virtual machine and save state")
            }
        }
    }

    @ViewBuilder
    private var installProgressSection: some View {
        if let session, session.state == .installing {
            ProgressOverlay(
                title: "Installing macOS…",
                progress: session.installProgress
            )
        }
    }

    private let maxCPU = Double(ProcessInfo.processInfo.processorCount)
    private let maxMemory = Double(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))

    @ViewBuilder
    private func configurationSection(config: VMConfig) -> some View {
        let isStopped = state == .stopped

        GroupBox("Configuration") {
            VStack(alignment: .leading, spacing: 12) {
                if isStopped {
                    ResourceSlider(
                        title: "CPU Cores",
                        value: $editCPU,
                        range: 2...maxCPU,
                        step: 1,
                        unit: "cores"
                    )
                    .onChange(of: editCPU) { _, newValue in
                        guard var updated = self.config else { return }
                        updated.cpuCount = Int(newValue)
                        vmManager.updateConfig(updated)
                    }

                    ResourceSlider(
                        title: "Memory",
                        value: $editMemory,
                        range: 4...maxMemory,
                        step: 1,
                        unit: "GB"
                    )
                    .onChange(of: editMemory) { _, newValue in
                        guard var updated = self.config else { return }
                        updated.memoryInGB = Int(newValue)
                        vmManager.updateConfig(updated)
                    }

                    ResourceSlider(
                        title: "Disk Size",
                        value: $editDisk,
                        range: minDiskSize...512,
                        step: 8,
                        unit: "GB"
                    )
                    .onChange(of: editDisk) { _, newValue in
                        guard var updated = self.config else { return }
                        let newSize = Int(newValue)
                        guard newSize >= Int(minDiskSize) else { return }
                        updated.diskSizeInGB = newSize
                        vmManager.updateConfig(updated)
                    }

                    Text("Changes take effect on next start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    configRow(label: "CPU Cores", value: "\(config.cpuCount)")
                    configRow(label: "Memory", value: "\(config.memoryInGB) GB")
                    configRow(label: "Disk Size", value: "\(config.diskSizeInGB) GB")
                }

                configRow(
                    label: "Disk Usage",
                    value: ByteCountFormatter.string(
                        fromByteCount: StorageService.vmDiskUsage(for: config.id),
                        countStyle: .file
                    )
                )
                configRow(label: "Display", value: "\(config.displayWidth)×\(config.displayHeight) @ \(config.displayPPI) PPI")
                configRow(label: "MAC Address", value: config.macAddress)
            }
            .padding(8)
        }
        .onAppear { syncEditValues(from: config) }
        .onChange(of: vmID) { syncEditValues(from: config) }
    }

    @ViewBuilder
    private func sharedFoldersSection(config: VMConfig) -> some View {
        let isStopped = state == .stopped
        let id = vmID

        GroupBox("Shared Folders") {
            if isStopped,
               vmManager.virtualMachines.contains(where: { $0.id == id }) {
                SharedFolderPicker(folders: Binding(
                    get: {
                        vmManager.virtualMachines.first(where: { $0.id == id })?.sharedFolders ?? []
                    },
                    set: { newValue in
                        guard var updated = vmManager.virtualMachines.first(where: { $0.id == id }) else { return }
                        updated.sharedFolders = newValue
                        vmManager.updateConfig(updated)
                    }
                ))
                .padding(8)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if config.sharedFolders.isEmpty {
                        Text("No shared folders configured")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(config.sharedFolders) { folder in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                Text(folder.name)
                                if folder.readOnly {
                                    Text("(Read-only)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    if !isStopped {
                        Text("Stop the VM to edit shared folders")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }
        }
    }

    private func syncEditValues(from config: VMConfig) {
        editCPU = Double(config.cpuCount)
        editMemory = Double(config.memoryInGB)
        editDisk = Double(config.diskSizeInGB)
        minDiskSize = Double(config.diskSizeInGB)
    }

    private func configRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
        }
    }
}
