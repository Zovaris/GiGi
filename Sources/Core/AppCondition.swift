import AppKit

struct SelectedApp: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

struct AppCondition: Codable {
    var enabled = false
    var mode = "running"
    var apps: [SelectedApp] = []

    func allows(_ activity: AppActivity) -> Bool {
        guard enabled, !apps.isEmpty else { return true }
        let ids = Set(apps.map(\.id))
        if mode == "frontmost" {
            return activity.frontmost.map(ids.contains) ?? false
        }
        return !ids.isDisjoint(with: activity.running)
    }
}

struct AppActivity {
    var running: Set<String> = []
    var frontmost: String?

    static func current() -> AppActivity {
        let workspace = NSWorkspace.shared
        return AppActivity(running: Set(workspace.runningApplications.compactMap(\.bundleIdentifier)),
                           frontmost: workspace.frontmostApplication?.bundleIdentifier)
    }
}
