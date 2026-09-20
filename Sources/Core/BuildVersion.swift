import Foundation

enum BuildVersion {
    static let unknown = "unknown"

    static var current: String {
        if let version = version(in: Bundle.main) { return version }
        for url in candidateBundles() {
            if let version = version(in: Bundle(url: url)) { return version }
        }
        return unknown
    }

    private static func version(in bundle: Bundle?) -> String? {
        guard let value = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String,
              !value.isEmpty, value != "?" else { return nil }
        return value
    }

    private static func candidateBundles() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var urls = [home.appendingPathComponent("Applications/GiGi.app"),
                    URL(fileURLWithPath: "/Applications/GiGi.app")]
        let executable = URL(fileURLWithPath: CommandLine.arguments.first ?? "")
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
        urls.insert(executable.appendingPathComponent("GiGi.app"), at: 0)
        urls.insert(executable.deletingLastPathComponent().appendingPathComponent("app/GiGi.app"), at: 1)
        return urls
    }
}
