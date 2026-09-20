import Foundation

enum Notice: Equatable {
    case timerExpired
    case batteryStop(percent: Int, limit: Int)
    case missingAccessibility
    case updateAvailable(version: String)
}

extension Notice {
    var key: String {
        switch self {
        case .timerExpired: return "timer-expired"
        case .batteryStop: return "battery-stop"
        case .missingAccessibility: return "missing-accessibility"
        case .updateAvailable(let version): return "update-available-\(version)"
        }
    }

    var oncePerRun: Bool {
        switch self {
        case .missingAccessibility: return true
        case .timerExpired, .batteryStop, .updateAvailable: return false
        }
    }
}

struct NoticeCenter {
    var enabled = true
    var post: (Notice) -> Void = { _ in }
    private var delivered: Set<String> = []
    private var session = 0

    mutating func beginSession() {
        session += 1
    }

    mutating func offer(_ notice: Notice) {
        guard enabled else { return }
        let key = notice.oncePerRun ? notice.key : "\(session):\(notice.key)"
        guard delivered.insert(key).inserted else { return }
        post(notice)
    }
}
