import Foundation
import SwiftUI

/// Shared storage between the app, its widgets and its intents.
/// Without an App Group (some signing certificates don't allow one) each side keeps its own copy.
enum WirdShared {
    static let baseGroup = "group.om.alkhanbashi.wird"

    /// "group" | "local"
    static var mode: String { groupID != nil ? "group" : "local" }
    static var groupAvailable: Bool { mode != "local" }

    static let groupID: String? = {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: baseGroup) != nil ? baseGroup : nil
    }()

    static var defaults: UserDefaults {
        if let g = groupID, let d = UserDefaults(suiteName: g) { return d }
        return .standard
    }

    static func data(forKey key: String) -> Data? {
        if groupID != nil { return defaults.data(forKey: key) }
        return UserDefaults.standard.data(forKey: key)
    }

    static func set(_ data: Data, forKey key: String) {
        if groupID != nil { defaults.set(data, forKey: key); return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct WirdColors: Codable, Hashable {
    var bg1: String, bg2: String, bead: String, tx: String, orn: String, acc: String, accFg: String, bg: String, fg: String, muted: String
}

struct WirdPalette: Codable, Hashable {
    var light: WirdColors
    var dark: WirdColors
    static let navy = WirdPalette(
        light: WirdColors(bg1: "#FFFFFF", bg2: "#C7D5EE", bead: "#1D3A70", tx: "#13254A", orn: "#A57A2C", acc: "#1D3A70", accFg: "#FFFFFF", bg: "#E9EEF6", fg: "#13254A", muted: "#5A6886"),
        dark: WirdColors(bg1: "#1C3A6E", bg2: "#0A1631", bead: "#E3B861", tx: "#F2ECDD", orn: "#E3B861", acc: "#E3B861", accFg: "#0A1631", bg: "#0A1631", fg: "#F2ECDD", muted: "#9AA8C2"))
    func colors(_ scheme: ColorScheme) -> WirdColors { scheme == .dark ? dark : light }
}

struct IstState: Codable {
    var days: [String: Int] = [:]
    var total: Int = 0
    var goal: Int = 300
    var formShort: String = "أستغفر الله"
    var formText: String = "أَسْتَغْفِرُ اللَّهَ"
    var palette: WirdPalette = .navy
}

enum IstStore {
    private static let key = "ist.state.v1"
    private static let lock = NSLock()

    static func load() -> IstState {
        guard let data = WirdShared.data(forKey: key),
              let s = try? JSONDecoder().decode(IstState.self, from: data) else { return IstState() }
        return s
    }

    static func save(_ s: IstState) {
        if let data = try? JSONEncoder().encode(s) { WirdShared.set(data, forKey: key) }
    }

    static func dayKey(_ d: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    @discardableResult
    static func add(_ n: Int = 1) -> IstState {
        lock.lock(); defer { lock.unlock() }
        var s = load()
        let k = dayKey()
        s.days[k, default: 0] += n
        s.total += n
        save(s)
        return s
    }

    static func update(_ change: (inout IstState) -> Void) {
        lock.lock(); defer { lock.unlock() }
        var s = load()
        change(&s)
        save(s)
    }

    static func today(_ s: IstState) -> Int { s.days[dayKey()] ?? 0 }

    static func lastDays(_ s: IstState, count: Int = 7) -> [(date: Date, value: Int)] {
        let cal = Calendar(identifier: .gregorian)
        return (0..<count).reversed().map { i in
            let d = cal.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            return (d, s.days[dayKey(d)] ?? 0)
        }
    }

    static func streak(_ s: IstState) -> Int {
        let cal = Calendar(identifier: .gregorian)
        var d = Date()
        if (s.days[dayKey(d)] ?? 0) < s.goal { d = cal.date(byAdding: .day, value: -1, to: d) ?? d }
        var n = 0
        while (s.days[dayKey(d)] ?? 0) >= s.goal && n < 3650 {
            n += 1
            d = cal.date(byAdding: .day, value: -1, to: d) ?? d
        }
        return n
    }
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r, g, b: Double
        if h.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255; g = Double((v >> 8) & 0xFF) / 255; b = Double(v & 0xFF) / 255
        } else { r = 0.5; g = 0.5; b = 0.5 }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

enum ArabicNum {
    private static let digits: [Character] = ["٠","١","٢","٣","٤","٥","٦","٧","٨","٩"]
    static func str(_ n: Int) -> String {
        String(String(n).map { c in
            if let d = c.wholeNumberValue, (0...9).contains(d) { return digits[d] }
            return c
        })
    }
}
