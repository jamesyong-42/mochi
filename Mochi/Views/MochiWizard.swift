import SwiftUI

struct MochiWizard: View {
    @Environment(VMManager.self) private var vmManager
    @Environment(IPSWService.self) private var ipswService
    @Environment(\.colorScheme) private var colorScheme

    enum Mode {
        case create
        case edit(VMConfig)
    }

    let mode: Mode
    var onDismiss: () -> Void

    @State private var vmName: String = "My Mochi"
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
        ZStack {
            // Backdrop with blur
            Rectangle()
                .fill(isDark ? Color.black.opacity(0.6) : Color.white.opacity(0.4))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isCreating { onDismiss() }
                }

            // Modal card
            VStack(spacing: 0) {
                if isCreating {
                    installingView
                } else {
                    formView
                }
            }
            .frame(maxWidth: 440)
            .background(
                RoundedRectangle(cornerRadius: 40)
                    .fill(isDark ? Color(hex: "1c1c1e") : Color.white.opacity(0.9))
                    .shadow(color: isDark ? .black.opacity(0.5) : .black.opacity(0.1), radius: 30, y: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 40)
                    .strokeBorder(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 40))
        }
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
                Text(isEditMode ? "Edit Mochi" : "New Mochi")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.3)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isDark ? Color.white.opacity(0.4) : Color(hex: "9ca3af"))
                        .frame(width: 32, height: 32)
                        .background(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 32) {
                    // Name input
                    nameInput

                    // Resources
                    resourcesSection

                    // Color picker
                    colorPickerSection

                    // Advanced section (edit mode)
                    if isEditMode {
                        advancedSection
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }

            // Footer buttons
            footerButtons
        }
    }

    // MARK: - Name Input

    private var nameInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NAME")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(isDark ? Color.white.opacity(0.6) : Color(hex: "6b7280"))
                .padding(.leading, 4)

            TextField("My New Mochi", text: $vmName)
                .font(.system(size: 17, weight: .bold))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDark ? Color.black.opacity(0.2) : Color.black.opacity(0.05))
                )
        }
    }

    // MARK: - Resources Section

    private var resourcesSection: some View {
        VStack(spacing: 20) {
            MochiResourceSlider(
                label: "CPU CORES",
                value: $cpuCount,
                range: 2...maxCPU,
                step: 1,
                displayValue: "\(Int(cpuCount)) Cores",
                theme: theme
            )

            MochiResourceSlider(
                label: "MEMORY",
                value: $memoryInGB,
                range: 4...maxMemory,
                step: 1,
                displayValue: "\(Int(memoryInGB)) GB",
                theme: theme
            )

            MochiResourceSlider(
                label: "DISK SIZE",
                value: $diskSizeInGB,
                range: (isEditMode ? minDiskSize : 32)...512,
                step: 8,
                displayValue: "\(Int(diskSizeInGB)) GB",
                theme: theme
            )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.6))
        )
    }

    // MARK: - Color Picker

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THEME")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(isDark ? Color.white.opacity(0.6) : Color(hex: "6b7280"))

            HStack(spacing: 12) {
                ForEach(MochiColorKey.allCases, id: \.self) { key in
                    let t = MochiTheme.forKey(key)
                    Circle()
                        .fill(t.accent)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if colorKey == key {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 3)
                                    .frame(width: 28, height: 28)
                            }
                        }
                        .shadow(color: t.accent.opacity(0.3), radius: colorKey == key ? 6 : 0)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                colorKey = key
                            }
                        }
                }
                Spacer()
            }
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
            // Cancel - subtle
            Button {
                onDismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isDark ? Color.white.opacity(0.4) : Color(hex: "9ca3af"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Create/Save - inverted colors (black in light, white in dark)
            Button {
                if isEditMode {
                    saveChanges()
                } else {
                    createVM()
                }
            } label: {
                Text(isEditMode ? "Save Changes" : "Create Mochi")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isDark ? .black : .white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(isDark ? Color.white : Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(vmName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                .frame(height: 1)
        }
        .background(isDark ? Color.black.opacity(0.2) : Color(hex: "f9fafb").opacity(0.5)) // gray-50/50
    }

    // MARK: - Installing View

    private var installingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Spinner with glow
            ZStack {
                Circle()
                    .fill(isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)

                Circle()
                    .fill(isDark ? Color.white.opacity(0.1) : .white)
                    .overlay(
                        Circle()
                            .strokeBorder(isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.05), lineWidth: 1)
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.2), radius: 20)

                ProgressView()
                    .controlSize(.large)
            }

            VStack(spacing: 12) {
                Text("Cooking Mochi...")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.3)

                // Step text from real progress
                Group {
                    if ipswService.isDownloading {
                        VStack(spacing: 12) {
                            Text("Downloading System Image...")
                                .font(.system(size: 13, weight: .medium).monospaced())
                                .tracking(1)
                                .textCase(.uppercase)
                                .opacity(0.6)

                            progressBar(value: ipswService.downloadProgress)

                            HStack {
                                Text("0%")
                                Spacer()
                                Text("\(Int(ipswService.downloadProgress * 100))%")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .opacity(0.4)
                        }
                    } else if let session = vmManager.sessions.values.first(where: { $0.state == .installing }) {
                        VStack(spacing: 12) {
                            Text("Installing macOS...")
                                .font(.system(size: 13, weight: .medium).monospaced())
                                .tracking(1)
                                .textCase(.uppercase)
                                .opacity(0.6)

                            progressBar(value: session.installProgress)

                            HStack {
                                Text("0%")
                                Spacer()
                                Text("\(Int(session.installProgress * 100))%")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .opacity(0.4)
                        }
                    } else {
                        Text("Initializing...")
                            .font(.system(size: 13, weight: .medium).monospaced())
                            .tracking(1)
                            .textCase(.uppercase)
                            .opacity(0.6)
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
                    .shadow(color: isDark ? .white.opacity(0.5) : .black.opacity(0.2), radius: 5)
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
            onDismiss()
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
        onDismiss()
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

// MARK: - Custom Resource Slider

struct MochiResourceSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let displayValue: String
    let theme: MochiTheme

    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(isDark ? Color.white.opacity(0.6) : Color(hex: "6b7280"))
                Spacer()
                Text(displayValue)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(isDark ? Color.white.opacity(0.9) : Color(hex: "1f2937"))
            }

            GeometryReader { geo in
                let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let fillWidth = max(0, geo.size.width * fraction)

                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(isDark ? Color.black.opacity(0.2) : Color.black.opacity(0.05))
                        .shadow(color: .black.opacity(isDark ? 0.3 : 0.08), radius: 2, y: 1)

                    // White fill bar
                    Capsule()
                        .fill(.white)
                        .shadow(
                            color: isDark ? .white.opacity(0.4) : .black.opacity(0.1),
                            radius: isDark ? 6 : 4,
                            y: isDark ? 0 : 2
                        )
                        .frame(width: fillWidth)

                    // Custom thumb
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: isDark ? .black.opacity(0.4) : .black.opacity(0.1), radius: 4, y: 2)
                        .overlay(
                            Circle()
                                .fill(isDark ? Color.black.opacity(0.2) : Color.black.opacity(0.1))
                                .frame(width: 6, height: 6)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(isDark ? .clear : Color.black.opacity(0.05), lineWidth: 1)
                        )
                        .offset(x: fillWidth - 12)
                }
                .frame(height: 16)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let fraction = max(0, min(1, drag.location.x / geo.size.width))
                            let rawValue = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                            value = (rawValue / step).rounded() * step
                            value = max(range.lowerBound, min(range.upperBound, value))
                        }
                )
            }
            .frame(height: 24)
        }
    }
}
