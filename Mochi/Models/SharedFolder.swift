import Foundation

struct SharedFolder: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var path: String
    var readOnly: Bool

    init(id: UUID = UUID(), name: String, path: String, readOnly: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.readOnly = readOnly
    }
}
