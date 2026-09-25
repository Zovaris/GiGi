import Foundation

struct Overrides: Codable, Equatable {
    var displayApplied: Double?
    var displayOriginal: Double?
    var keyboardApplied: Double?
    var keyboardOriginal: Double?

    var isEmpty: Bool {
        displayApplied == nil && displayOriginal == nil && keyboardApplied == nil && keyboardOriginal == nil
    }
}

struct OverrideStore {
    var load: () -> Overrides?
    var save: (Overrides) -> Void
    var clear: () -> Void

    init(load: @escaping () -> Overrides?, save: @escaping (Overrides) -> Void, clear: @escaping () -> Void) {
        self.load = load
        self.save = save
        self.clear = clear
    }

    init(configPath: String?) {
        let url = overridesURL(configPath: configPath)
        self.init(
            load: {
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(Overrides.self, from: data)
            },
            save: { overrides in
                do {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                            withIntermediateDirectories: true)
                    try JSONEncoder().encode(overrides).write(to: url, options: .atomic)
                } catch {
                    Log.error("overrides: cannot write \(url.path): \(error.localizedDescription)")
                }
            },
            clear: { try? FileManager.default.removeItem(at: url) }
        )
    }

    static let system = OverrideStore(configPath: nil)

    static let disabled = OverrideStore(load: { nil }, save: { _ in }, clear: {})
}

func overridesURL(configPath: String? = nil) -> URL {
    guard let configPath else {
        return defaultConfigURL().deletingLastPathComponent().appendingPathComponent("overrides.json")
    }
    let expanded = (configPath as NSString).expandingTildeInPath
    return URL(fileURLWithPath: expanded).deletingLastPathComponent().appendingPathComponent("overrides.json")
}
