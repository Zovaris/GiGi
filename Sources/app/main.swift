import AppKit

configureAppLogging()
let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
Log.info("app: starting \(Bundle.main.bundleIdentifier ?? "no bundle") v\(version), language \(Locale.preferredLanguages.first ?? "unknown")")

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
