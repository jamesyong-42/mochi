import Foundation

enum VMState: String, Codable, Sendable {
    case stopped
    case starting
    case running
    case pausing
    case paused
    case resuming
    case stopping
    case saving
    case restoring
    case installing
    case error

    var isTransitional: Bool {
        switch self {
        case .starting, .pausing, .resuming, .stopping, .saving, .restoring, .installing:
            true
        default:
            false
        }
    }

    var canStart: Bool { self == .stopped }
    var canStop: Bool { self == .running || self == .paused }
    var canPause: Bool { self == .running }
    var canResume: Bool { self == .paused }
    var canSuspend: Bool { self == .running }

    var displayName: String {
        switch self {
        case .stopped: "Stopped"
        case .starting: "Starting…"
        case .running: "Running"
        case .pausing: "Pausing…"
        case .paused: "Paused"
        case .resuming: "Resuming…"
        case .stopping: "Stopping…"
        case .saving: "Saving State…"
        case .restoring: "Restoring…"
        case .installing: "Installing…"
        case .error: "Error"
        }
    }
}
