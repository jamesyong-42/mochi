import Foundation

struct VMConfig: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var cpuCount: Int
    var memoryInGB: Int
    var diskSizeInGB: Int
    var displayWidth: Int
    var displayHeight: Int
    var displayPPI: Int
    var sharedFolders: [SharedFolder]
    var macAddress: String
    var colorKey: MochiColorKey

    init(
        id: UUID = UUID(),
        name: String,
        cpuCount: Int,
        memoryInGB: Int,
        diskSizeInGB: Int,
        displayWidth: Int = 1920,
        displayHeight: Int = 1080,
        displayPPI: Int = 144,
        sharedFolders: [SharedFolder] = [],
        macAddress: String,
        colorKey: MochiColorKey = .blue
    ) {
        self.id = id
        self.name = name
        self.cpuCount = cpuCount
        self.memoryInGB = memoryInGB
        self.diskSizeInGB = diskSizeInGB
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
        self.displayPPI = displayPPI
        self.sharedFolders = sharedFolders
        self.macAddress = macAddress
        self.colorKey = colorKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cpuCount = try container.decode(Int.self, forKey: .cpuCount)
        memoryInGB = try container.decode(Int.self, forKey: .memoryInGB)
        diskSizeInGB = try container.decode(Int.self, forKey: .diskSizeInGB)
        displayWidth = try container.decode(Int.self, forKey: .displayWidth)
        displayHeight = try container.decode(Int.self, forKey: .displayHeight)
        displayPPI = try container.decode(Int.self, forKey: .displayPPI)
        sharedFolders = try container.decode([SharedFolder].self, forKey: .sharedFolders)
        macAddress = try container.decode(String.self, forKey: .macAddress)
        colorKey = try container.decodeIfPresent(MochiColorKey.self, forKey: .colorKey) ?? .blue
    }

    static func makeDefault(name: String) -> VMConfig {
        let hostCores = ProcessInfo.processInfo.processorCount
        let cpuCount = max(2, hostCores / 2)

        return VMConfig(
            name: name,
            cpuCount: cpuCount,
            memoryInGB: 8,
            diskSizeInGB: 64,
            macAddress: generateMACAddress(),
            colorKey: .random
        )
    }

    static func generateMACAddress() -> String {
        var bytes = (0..<6).map { _ in UInt8.random(in: 0...255) }
        bytes[0] = (bytes[0] & 0xFE) | 0x02 // locally administered unicast
        return bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
    }
}
