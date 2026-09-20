import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let languages = ["en", "es"]

func expression(_ pattern: String) -> NSRegularExpression {
    try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
}

func matches(_ pattern: String, in text: String, group: Int = 1) -> [String] {
    let regex = expression(pattern)
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, range: range).compactMap { match in
        guard match.numberOfRanges > group, let range = Range(match.range(at: group), in: text) else { return nil }
        return String(text[range])
    }
}

func swiftFiles() -> [URL] {
    let sources = root.appendingPathComponent("Sources")
    guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else { return [] }
    return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
}

func literals(in text: String) -> Set<String> {
    var found = Set<String>()
    var current = ""
    var open = false
    var escaped = false
    for character in text {
        if !open {
            if character == "\"" { open = true; current = "" }
            continue
        }
        if escaped {
            current.append(character)
            escaped = false
        } else if character == "\\" {
            escaped = true
        } else if character == "\"" {
            found.insert(current)
            open = false
        } else {
            current.append(character)
        }
    }
    return found
}

var used = Set<String>()
var mentioned = Set<String>()
for file in swiftFiles() {
    guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
    used.formUnion(matches(#"L\("((?:[^"\\]|\\.)*)"\)"#, in: text))
    mentioned.formUnion(literals(in: text))
}

var failed = false
var declared: [String: Set<String>] = [:]
for language in languages {
    let table = root.appendingPathComponent("Resources/\(language).lproj/Localizable.strings")
    guard let text = try? String(contentsOf: table, encoding: .utf8) else {
        print("\(language): cannot read \(table.path)")
        failed = true
        continue
    }
    let keys = Set(matches(#"^"((?:[^"\\]|\\.)*)"\s*="#, in: text))
    declared[language] = keys
    let missing = used.subtracting(keys).sorted()
    let unused = keys.subtracting(mentioned).sorted()
    print("\(language): \(keys.count) declared, \(used.count) used, \(missing.count) missing, \(unused.count) unused")
    for key in missing {
        print("  missing: \(key)")
        failed = true
    }
    for key in unused {
        print("  unused: \(key)")
    }
}

if declared.count == languages.count, let reference = declared[languages[0]] {
    for language in languages.dropFirst() {
        for key in (declared[language] ?? []).subtracting(reference).sorted() {
            print("  \(language) only: \(key)")
            failed = true
        }
    }
}

if failed {
    print("localization check FAILED")
    exit(1)
}
print("localization check passed")
