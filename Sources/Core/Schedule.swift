import Foundation

func parseHM(_ raw: String) -> (h: Int, m: Int)? {
    let parts = raw.split(separator: ":")
    guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
          (0...23).contains(h), (0...59).contains(m) else { return nil }
    return (h, m)
}

let weekdayNames = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]

extension Schedule {
    func allows(_ date: Date) -> Bool {
        guard enabled, !windows.isEmpty else { return true }
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = comps.weekday, let hour = comps.hour, let minute = comps.minute else { return true }
        let today = weekdayNames[(weekday - 1) % 7]
        if !days.map({ $0.lowercased() }).contains(today) { return false }
        let now = hour * 60 + minute
        for window in windows {
            guard let s = parseHM(window.start), let e = parseHM(window.end) else { continue }
            let start = s.h * 60 + s.m
            let end = e.h * 60 + e.m
            if start <= end {
                if now >= start && now < end { return true }
            } else if now >= start || now < end {
                return true
            }
        }
        return false
    }

    func nextTransition(after date: Date) -> Date? {
        guard enabled, !windows.isEmpty else { return nil }
        let calendar = Calendar.current
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            for window in windows {
                for hm in [window.start, window.end] {
                    guard let t = parseHM(hm) else { continue }
                    var comps = calendar.dateComponents([.year, .month, .day], from: day)
                    comps.hour = t.h
                    comps.minute = t.m
                    comps.second = 0
                    if let candidate = calendar.date(from: comps), candidate > date {
                        return candidate
                    }
                }
            }
        }
        return nil
    }
}

func nextOccurrence(ofHM raw: String, after now: Date) -> Date? {
    guard let hm = parseHM(raw) else { return nil }
    let calendar = Calendar.current
    var comps = calendar.dateComponents([.year, .month, .day], from: now)
    comps.hour = hm.h
    comps.minute = hm.m
    comps.second = 0
    guard let today = calendar.date(from: comps) else { return nil }
    if today > now { return today }
    return calendar.date(byAdding: .day, value: 1, to: today)
}
