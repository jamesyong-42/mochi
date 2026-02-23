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

    static func makeDefault(name: String) -> VMConfig {
        let hostCores = ProcessInfo.processInfo.processorCount
        let cpuCount = max(2, hostCores / 2)

        return VMConfig(
            id: UUID(),
            name: name,
            cpuCount: cpuCount,
            memoryInGB: 8,
            diskSizeInGB: 64,
            displayWidth: 1920,
            displayHeight: 1080,
            displayPPI: 144,
            sharedFolders: [],
            macAddress: generateMACAddress()
        )
    }

    static func generateMACAddress() -> String {
        var bytes = (0..<6).map { _ in UInt8.random(in: 0...255) }
        bytes[0] = (bytes[0] & 0xFE) | 0x02 // locally administered unicast
        return bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
    }
}
