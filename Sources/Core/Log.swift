import Foundation

let logTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

enum Log {
    static var fileURL: URL?
    private(set) static var recent: [String] = []
    private static let maxRecent = 200
    private static var handle: FileHandle?

    static func info(_ message: String) {
        emit(message)
    }

    static func error(_ message: String) {
        emit("ERROR: \(message)")
    }

    private static func emit(_ message: String) {
        let line = "[\(logTimestampFormatter.string(from: Date()))] \(message)"
        print(line)
        fflush(stdout)

        recent.append(line)
        if recent.count > maxRecent {
            recent.removeFirst(recent.count - maxRecent)
        }

        guard let url = fileURL else { return }
        if handle == nil {
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.path) {
                fm.createFile(atPath: url.path, contents: nil)
            }
            handle = try? FileHandle(forWritingTo: url)
            handle?.seekToEndOfFile()
        }
        if let data = (line + "\n").data(using: .utf8) {
            handle?.write(data)
        }
    }

    static func recentText(_ count: Int) -> [String] {
        Array(recent.suffix(count))
    }
}

func configureAppLogging() {
    let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/GiGi")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    Log.fileURL = dir.appendingPathComponent("app.log")
}
