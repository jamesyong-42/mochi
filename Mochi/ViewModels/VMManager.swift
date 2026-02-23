import Foundation
import Virtualization

@Observable
final class VMManager {

    var virtualMachines: [VMConfig] = []
    var sessions: [UUID: VMSession] = [:]
    var isLoading = false
    var error: String?

    let ipswService = IPSWService()

    // MARK: - Load

    func loadVMs() {
        isLoading = true
        defer { isLoading = false }

        do {
            virtualMachines = try StorageService.loadAllConfigs()
        } catch {
            self.error = "Failed to load VMs: \(error.localizedDescription)"
        }
    }

    // MARK: - Create

    func createVM(
        name: String,
        cpuCount: Int,
        memoryInGB: Int,
        diskSizeInGB: Int
    ) async {
        do {
            error = nil

            let ipswURL = try await ipswService.ensureIPSWAvailable()

            let restoreImage = try await ipswService.fetchLatestImageInfo()
            guard let requirements = restoreImage.mostFeaturefulSupportedConfiguration else {
                throw VMManagerError.unsupportedConfiguration
            }

            var config = VMConfig.makeDefault(name: name)
            config.cpuCount = max(requirements.minimumSupportedCPUCount, cpuCount)
            config.memoryInGB = max(
                Int(requirements.minimumSupportedMemorySize / (1024 * 1024 * 1024)),
                memoryInGB
            )
            config.diskSizeInGB = diskSizeInGB

            try StorageService.createVMDirectory(for: config.id)

            do {
                try StorageService.createDiskImage(for: config.id, sizeInGB: config.diskSizeInGB)

                try StorageService.saveHardwareModel(
                    requirements.hardwareModel.dataRepresentation,
                    for: config.id
                )

                let machineIdentifier = VZMacMachineIdentifier()
                try StorageService.saveMachineIdentifier(
                    machineIdentifier.dataRepresentation,
                    for: config.id
                )

                _ = try VZMacAuxiliaryStorage(
                    creatingStorageAt: StorageService.auxiliaryStorageURL(for: config.id),
                    hardwareModel: requirements.hardwareModel,
                    options: []
                )

                try StorageService.saveConfig(config)
                virtualMachines.append(config)

                let session = VMSession(vmID: config.id, config: config)
                sessions[config.id] = session
                try await session.install(ipswURL: ipswURL)

            } catch {
                // Cleanup on failure
                try? StorageService.deleteVMDirectory(for: config.id)
                throw error
            }

        } catch {
            self.error = "Failed to create VM: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete

    func deleteVM(id: UUID) async {
        if let session = sessions[id], session.state == .running || session.state == .paused {
            try? session.forceStop()
        }
        sessions.removeValue(forKey: id)

        do {
            try StorageService.deleteVMDirectory(for: id)
        } catch {
            self.error = "Failed to delete VM: \(error.localizedDescription)"
        }

        virtualMachines.removeAll { $0.id == id }
    }

    // MARK: - Duplicate

    func duplicateVM(sourceID: UUID) async {
        guard let source = virtualMachines.first(where: { $0.id == sourceID }) else { return }

        do {
            var newConfig = source
            let newID = UUID()
            newConfig.id = newID
            newConfig.name = "\(source.name) (Copy)"
            newConfig.macAddress = VMConfig.generateMACAddress()

            try StorageService.cloneVM(source: sourceID, destination: newID)

            let newMachineID = VZMacMachineIdentifier()
            try StorageService.saveMachineIdentifier(
                newMachineID.dataRepresentation,
                for: newID
            )

            try StorageService.saveConfig(newConfig)
            virtualMachines.append(newConfig)

        } catch {
            self.error = "Failed to duplicate VM: \(error.localizedDescription)"
        }
    }

    // MARK: - Update Config

    func updateConfig(_ config: VMConfig) {
        do {
            if let index = virtualMachines.firstIndex(where: { $0.id == config.id }) {
                let old = virtualMachines[index]

                // Grow disk image if size increased
                if config.diskSizeInGB > old.diskSizeInGB {
                    try StorageService.resizeDiskImage(for: config.id, newSizeInGB: config.diskSizeInGB)
                }

                try StorageService.saveConfig(config)
                virtualMachines[index] = config

                // Invalidate session so next start picks up new hardware config
                if old.cpuCount != config.cpuCount ||
                   old.memoryInGB != config.memoryInGB ||
                   old.diskSizeInGB != config.diskSizeInGB {
                    sessions.removeValue(forKey: config.id)
                }
            }
        } catch {
            self.error = "Failed to save configuration: \(error.localizedDescription)"
        }
    }

    // MARK: - Lifecycle

    func startVM(id: UUID) async {
        do {
            let session = getOrCreateSession(for: id)
            try await session.start()
        } catch {
            self.error = "Failed to start VM: \(error.localizedDescription)"
        }
    }

    func stopVM(id: UUID) async {
        guard let session = sessions[id] else { return }
        do {
            try await session.stop()
        } catch {
            self.error = "Failed to stop VM: \(error.localizedDescription)"
        }
    }

    func forceStopVM(id: UUID) {
        guard let session = sessions[id] else { return }
        do {
            try session.forceStop()
        } catch {
            self.error = "Failed to force stop VM: \(error.localizedDescription)"
        }
    }

    func pauseVM(id: UUID) async {
        guard let session = sessions[id] else { return }
        do {
            try await session.pause()
        } catch {
            self.error = "Failed to pause VM: \(error.localizedDescription)"
        }
    }

    func resumeVM(id: UUID) async {
        guard let session = sessions[id] else { return }
        do {
            try await session.resume()
        } catch {
            self.error = "Failed to resume VM: \(error.localizedDescription)"
        }
    }

    func suspendVM(id: UUID) async {
        guard let session = sessions[id] else { return }
        do {
            try await session.suspend()
        } catch {
            self.error = "Failed to suspend VM: \(error.localizedDescription)"
        }
    }

    func suspendAllRunningVMs() async {
        for (_, session) in sessions where session.state == .running {
            try? await session.suspend()
        }
    }

    // MARK: - Helpers

    func state(for id: UUID) -> VMState {
        sessions[id]?.state ?? .stopped
    }

    func session(for id: UUID) -> VMSession? {
        sessions[id]
    }

    var runningVMs: [VMConfig] {
        virtualMachines.filter { sessions[$0.id]?.state == .running }
    }

    private func getOrCreateSession(for id: UUID) -> VMSession {
        if let existing = sessions[id] {
            return existing
        }
        guard let config = virtualMachines.first(where: { $0.id == id }) else {
            fatalError("VM config not found for id: \(id)")
        }
        let session = VMSession(vmID: id, config: config)
        sessions[id] = session
        return session
    }
}

enum VMManagerError: LocalizedError {
    case unsupportedConfiguration
    case vmNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .unsupportedConfiguration:
            "This Mac does not support the required virtualization configuration"
        case .vmNotFound(let id):
            "VM not found: \(id.uuidString)"
        }
    }
}
