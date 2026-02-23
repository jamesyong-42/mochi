import Foundation

enum StorageService {

    // MARK: - Paths

    static let appSupportURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Mochi", isDirectory: true)
    }()

    static let vmsBaseURL: URL = appSupportURL.appendingPathComponent("VMs", isDirectory: true)

    static func vmDirectory(for id: UUID) -> URL {
        vmsBaseURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func configURL(for id: UUID) -> URL {
        vmDirectory(for: id).appendingPathComponent("config.json")
    }

    static func diskImageURL(for id: UUID) -> URL {
        vmDirectory(for: id).appendingPathComponent("disk.img")
    }

    static func auxiliaryStorageURL(for id: UUID) -> URL {
        vmDirectory(for: id).appendingPathComponent("auxiliary-storage")
    }

    static func hardwareModelURL(for id: UUID) -> URL {
        vmDirectory(for: id).appendingPathComponent("hardware-model")
    }

    static func machineIdentifierURL(for id: UUID) -> URL {
        vmDirectory(for: id).appendingPathComponent("machine-identifier")
    }

    static func savedStateURL(for id: UUID) -> URL {
        vmDirectory(for: id).appendingPathComponent("saved-state")
    }

    // MARK: - Directory Management

    static func ensureDirectoriesExist() throws {
        try FileManager.default.createDirectory(at: vmsBaseURL, withIntermediateDirectories: true)
    }

    static func createVMDirectory(for id: UUID) throws {
        try FileManager.default.createDirectory(at: vmDirectory(for: id), withIntermediateDirectories: true)
    }

    static func deleteVMDirectory(for id: UUID) throws {
        let dir = vmDirectory(for: id)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - Disk Image (sparse file)

    static func createDiskImage(for id: UUID, sizeInGB: Int) throws {
        let url = diskImageURL(for: id)
        let sizeInBytes = UInt64(sizeInGB) * 1024 * 1024 * 1024
        let fd = Darwin.open(url.path, O_WRONLY | O_CREAT, 0o644)
        guard fd >= 0 else { throw StorageError.diskCreationFailed(errno: errno) }
        defer { Darwin.close(fd) }
        guard lseek(fd, off_t(sizeInBytes) - 1, SEEK_SET) >= 0 else {
            throw StorageError.diskCreationFailed(errno: errno)
        }
        var zero: UInt8 = 0
        guard Darwin.write(fd, &zero, 1) == 1 else {
            throw StorageError.diskCreationFailed(errno: errno)
        }
    }

    // MARK: - Disk Resize (grow only)

    static func resizeDiskImage(for id: UUID, newSizeInGB: Int) throws {
        let url = diskImageURL(for: id)
        let newSizeInBytes = UInt64(newSizeInGB) * 1024 * 1024 * 1024
        let fd = Darwin.open(url.path, O_WRONLY)
        guard fd >= 0 else { throw StorageError.diskCreationFailed(errno: errno) }
        defer { Darwin.close(fd) }
        guard lseek(fd, off_t(newSizeInBytes) - 1, SEEK_SET) >= 0 else {
            throw StorageError.diskCreationFailed(errno: errno)
        }
        var zero: UInt8 = 0
        guard Darwin.write(fd, &zero, 1) == 1 else {
            throw StorageError.diskCreationFailed(errno: errno)
        }
    }

    // MARK: - Config Persistence

    static func saveConfig(_ config: VMConfig) throws {
        let url = configURL(for: config.id)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }

    static func loadConfig(for id: UUID) throws -> VMConfig {
        let data = try Data(contentsOf: configURL(for: id))
        return try JSONDecoder().decode(VMConfig.self, from: data)
    }

    static func loadAllConfigs() throws -> [VMConfig] {
        try ensureDirectoriesExist()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: vmsBaseURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        var configs: [VMConfig] = []
        for dir in contents {
            let configFile = dir.appendingPathComponent("config.json")
            if FileManager.default.fileExists(atPath: configFile.path),
               let data = try? Data(contentsOf: configFile),
               let config = try? JSONDecoder().decode(VMConfig.self, from: data) {
                configs.append(config)
            }
        }
        return configs.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Clone (APFS COW)

    static func cloneVM(source sourceID: UUID, destination destID: UUID) throws {
        try FileManager.default.copyItem(
            at: vmDirectory(for: sourceID),
            to: vmDirectory(for: destID)
        )
    }

    // MARK: - Hardware Model & Machine Identifier

    static func saveHardwareModel(_ data: Data, for id: UUID) throws {
        try data.write(to: hardwareModelURL(for: id), options: .atomic)
    }

    static func loadHardwareModel(for id: UUID) throws -> Data {
        try Data(contentsOf: hardwareModelURL(for: id))
    }

    static func saveMachineIdentifier(_ data: Data, for id: UUID) throws {
        try data.write(to: machineIdentifierURL(for: id), options: .atomic)
    }

    static func loadMachineIdentifier(for id: UUID) throws -> Data {
        try Data(contentsOf: machineIdentifierURL(for: id))
    }

    // MARK: - IPSW Cache

    static let ipswCacheURL: URL = appSupportURL.appendingPathComponent("IPSWCache", isDirectory: true)

    static func cleanupTempFiles() {
        let fm = FileManager.default
        // Clean IPSW cache temp files
        if let contents = try? fm.contentsOfDirectory(at: ipswCacheURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for file in contents where file.pathExtension == "tmp" {
                try? fm.removeItem(at: file)
            }
        }
        // Clean system temp directory for our .ipsw temps
        if let contents = try? fm.contentsOfDirectory(at: fm.temporaryDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for file in contents where file.pathExtension == "ipsw" {
                try? fm.removeItem(at: file)
            }
        }
    }

    static func clearIPSWCache() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: ipswCacheURL.path) {
            try fm.removeItem(at: ipswCacheURL)
        }
        try fm.createDirectory(at: ipswCacheURL, withIntermediateDirectories: true)
    }

    static func deleteAllVMs() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: vmsBaseURL.path) {
            try fm.removeItem(at: vmsBaseURL)
        }
        try fm.createDirectory(at: vmsBaseURL, withIntermediateDirectories: true)
    }

    // MARK: - Storage Size Calculation

    static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else { continue }
            // totalFileAllocatedSize accounts for sparse files; fall back to fileAllocatedSize
            let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
            total += Int64(size)
        }
        return total
    }

    static func vmsDiskUsage() -> Int64 {
        directorySize(at: vmsBaseURL)
    }

    static func ipswCacheDiskUsage() -> Int64 {
        directorySize(at: ipswCacheURL)
    }

    static func totalDiskUsage() -> Int64 {
        directorySize(at: appSupportURL)
    }

    static func vmDiskUsage(for id: UUID) -> Int64 {
        directorySize(at: vmDirectory(for: id))
    }

    // MARK: - Saved State

    static func hasSavedState(for id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: savedStateURL(for: id).path)
    }

    static func deleteSavedState(for id: UUID) throws {
        let url = savedStateURL(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

enum StorageError: LocalizedError {
    case diskCreationFailed(errno: Int32)
    case configNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .diskCreationFailed(let errno):
            "Failed to create disk image: \(String(cString: strerror(errno)))"
        case .configNotFound(let id):
            "Configuration not found for VM \(id.uuidString)"
        }
    }
}
