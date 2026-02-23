import Foundation
import Virtualization

@Observable
final class VMSession: NSObject, VZVirtualMachineDelegate {

    let vmID: UUID
    var config: VMConfig
    var state: VMState = .stopped
    var installProgress: Double = 0.0

    private(set) var virtualMachine: VZVirtualMachine?
    private var installObservation: NSKeyValueObservation?

    init(vmID: UUID, config: VMConfig) {
        self.vmID = vmID
        self.config = config
        super.init()
    }

    // MARK: - Configuration Builder

    func buildConfiguration() throws -> VZVirtualMachineConfiguration {
        let vmConfig = VZVirtualMachineConfiguration()

        vmConfig.cpuCount = config.cpuCount
        vmConfig.memorySize = UInt64(config.memoryInGB) * 1024 * 1024 * 1024

        // Platform
        let platform = VZMacPlatformConfiguration()

        let hwModelData = try StorageService.loadHardwareModel(for: vmID)
        guard let hwModel = VZMacHardwareModel(dataRepresentation: hwModelData) else {
            throw VMSessionError.invalidHardwareModel
        }
        platform.hardwareModel = hwModel

        let machineIDData = try StorageService.loadMachineIdentifier(for: vmID)
        guard let machineID = VZMacMachineIdentifier(dataRepresentation: machineIDData) else {
            throw VMSessionError.invalidMachineIdentifier
        }
        platform.machineIdentifier = machineID

        platform.auxiliaryStorage = try VZMacAuxiliaryStorage(
            contentsOf: StorageService.auxiliaryStorageURL(for: vmID)
        )

        vmConfig.platform = platform

        // Boot Loader
        vmConfig.bootLoader = VZMacOSBootLoader()

        // Graphics
        let graphicsConfig = VZMacGraphicsDeviceConfiguration()
        graphicsConfig.displays = [
            VZMacGraphicsDisplayConfiguration(
                widthInPixels: config.displayWidth,
                heightInPixels: config.displayHeight,
                pixelsPerInch: config.displayPPI
            )
        ]
        vmConfig.graphicsDevices = [graphicsConfig]

        // Storage
        let diskAttachment = try VZDiskImageStorageDeviceAttachment(
            url: StorageService.diskImageURL(for: vmID),
            readOnly: false
        )
        vmConfig.storageDevices = [VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)]

        // Network
        let networkConfig = VZVirtioNetworkDeviceConfiguration()
        networkConfig.attachment = VZNATNetworkDeviceAttachment()
        if let macAddress = VZMACAddress(string: config.macAddress) {
            networkConfig.macAddress = macAddress
        }
        vmConfig.networkDevices = [networkConfig]

        // Input
        vmConfig.keyboards = [VZMacKeyboardConfiguration()]
        vmConfig.pointingDevices = [VZMacTrackpadConfiguration()]

        // Audio
        let audioConfig = VZVirtioSoundDeviceConfiguration()
        let audioInput = VZVirtioSoundDeviceInputStreamConfiguration()
        audioInput.source = VZHostAudioInputStreamSource()
        let audioOutput = VZVirtioSoundDeviceOutputStreamConfiguration()
        audioOutput.sink = VZHostAudioOutputStreamSink()
        audioConfig.streams = [audioInput, audioOutput]
        vmConfig.audioDevices = [audioConfig]

        // Entropy & Memory Balloon
        vmConfig.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        vmConfig.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]

        // Shared Folders
        if !config.sharedFolders.isEmpty {
            var shares: [String: VZSharedDirectory] = [:]
            for folder in config.sharedFolders {
                shares[folder.name] = VZSharedDirectory(
                    url: URL(fileURLWithPath: folder.path),
                    readOnly: folder.readOnly
                )
            }
            let fsConfig = VZVirtioFileSystemDeviceConfiguration(
                tag: VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag
            )
            fsConfig.share = VZMultipleDirectoryShare(directories: shares)
            vmConfig.directorySharingDevices = [fsConfig]
        }

        try vmConfig.validate()
        return vmConfig
    }

    // MARK: - Lifecycle

    func start() async throws {
        guard state.canStart else { return }
        state = .starting

        if StorageService.hasSavedState(for: vmID) {
            try await startFromSavedState()
            return
        }

        let configuration = try buildConfiguration()
        let vm = VZVirtualMachine(configuration: configuration)
        vm.delegate = self
        virtualMachine = vm

        try await vm.start()
        state = .running
    }

    func startFromSavedState() async throws {
        state = .restoring

        let configuration = try buildConfiguration()
        let vm = VZVirtualMachine(configuration: configuration)
        vm.delegate = self
        virtualMachine = vm

        let stateURL = StorageService.savedStateURL(for: vmID)
        try await vm.restoreMachineStateFrom(url: stateURL)
        try await vm.start()
        state = .running

        try? StorageService.deleteSavedState(for: vmID)
    }

    func stop() async throws {
        guard state.canStop else { return }
        state = .stopping
        guard let vm = virtualMachine else {
            state = .stopped
            return
        }
        try await vm.stop()
        state = .stopped
        virtualMachine = nil
    }

    func forceStop() throws {
        guard let vm = virtualMachine else {
            state = .stopped
            return
        }
        state = .stopping
        try vm.requestStop()
        state = .stopped
        virtualMachine = nil
    }

    func pause() async throws {
        guard state.canPause else { return }
        state = .pausing
        guard let vm = virtualMachine else { return }
        try await vm.pause()
        state = .paused
    }

    func resume() async throws {
        guard state.canResume else { return }
        state = .resuming
        guard let vm = virtualMachine else { return }
        try await vm.resume()
        state = .running
    }

    func suspend() async throws {
        guard state.canSuspend else { return }

        try await pause()

        state = .saving
        guard let vm = virtualMachine else { return }

        let stateURL = StorageService.savedStateURL(for: vmID)
        try await vm.saveMachineStateTo(url: stateURL)

        try await vm.stop()
        state = .stopped
        virtualMachine = nil
    }

    // MARK: - Installation

    func install(ipswURL: URL) async throws {
        state = .installing
        installProgress = 0.0

        let configuration = try buildConfiguration()
        let vm = VZVirtualMachine(configuration: configuration)
        vm.delegate = self
        virtualMachine = vm

        let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: ipswURL)

        installObservation = installer.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor [weak self] in
                self?.installProgress = progress.fractionCompleted
            }
        }

        try await installer.install()

        installObservation?.invalidate()
        installObservation = nil
        installProgress = 1.0
        state = .stopped
        virtualMachine = nil
    }

    // MARK: - VZVirtualMachineDelegate

    nonisolated func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        Task { @MainActor in
            self.state = .stopped
            self.virtualMachine = nil
        }
    }

    nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        Task { @MainActor in
            self.state = .error
            self.virtualMachine = nil
        }
    }
}

enum VMSessionError: LocalizedError {
    case invalidHardwareModel
    case invalidMachineIdentifier
    case vmNotRunning

    var errorDescription: String? {
        switch self {
        case .invalidHardwareModel:
            "Invalid hardware model data"
        case .invalidMachineIdentifier:
            "Invalid machine identifier data"
        case .vmNotRunning:
            "Virtual machine is not running"
        }
    }
}
