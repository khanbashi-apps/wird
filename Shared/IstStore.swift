import Foundation
import Security
import UIKit
import SwiftUI

/// Shared storage between the app, its widgets and its intents.
/// Signing tools often rename the App Group (e.g. add the team ID), so the real group is read
/// from the installed provisioning profile. If no group works, a shared Keychain item is used.
enum WirdShared {
    static let baseGroup = "group.om.alkhanbashi.wird"

    /// "group" | "keychain" | "pasteboard" | "local"
    static var mode: String { groupID != nil ? "group" : (Keychain.available ? "keychain" : (SharedBoard.available ? "pasteboard" : "local")) }
    static var groupAvailable: Bool { mode != "local" }

    static let groupID: String? = {
        var candidates: [String] = []
        candidates += profileGroups()
        candidates.append(baseGroup)
        var app = Bundle.main.bundleIdentifier ?? ""
        if Bundle.main.bundleURL.pathExtension == "appex" {
            // om.alkhanbashi.wird.widgets(.XXXX) → om.alkhanbashi.wird(.XXXX)
            app = app.replacingOccurrences(of: ".widgets", with: "")
        }
        if !app.isEmpty { candidates += ["group." + app, "group.\(app).shared"] }
        var seen = Set<String>()
        for g in candidates where !g.isEmpty && seen.insert(g).inserted {
            if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: g) != nil { return g }
        }
        return nil
    }()

    /// App groups listed in embedded.mobileprovision (the profile the signing tool used).
    static func profileGroups() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else { return [] }
        let xml = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: xml, format: nil) as? [String: Any],
              let ent = plist["Entitlements"] as? [String: Any] else { return [] }
        let groups = (ent["com.apple.security.application-groups"] as? [String]) ?? []
        // prefer groups that look like ours
        return groups.filter { $0.contains("wird") } + groups.filter { !$0.contains("wird") && !$0.contains("*") }
    }

    static var defaults: UserDefaults {
        if let g = groupID, let d = UserDefaults(suiteName: g) { return d }
        return .standard
    }

    static func data(forKey key: String) -> Data? {
        if groupID != nil { return defaults.data(forKey: key) }
        if Keychain.available { return Keychain.read(key) }
        if SharedBoard.available, let d = SharedBoard.read(key) { return d }
        return UserDefaults.standard.data(forKey: key)
    }

    static func set(_ data: Data, forKey key: String) {
        if groupID != nil { defaults.set(data, forKey: key); return }
        if Keychain.available { Keychain.write(key, data); return }
        UserDefaults.standard.set(data, forKey: key)
        if SharedBoard.available { SharedBoard.write(key, data) }
    }
}

/// Last resort when the signing certificate allows neither App Groups nor shared Keychain:
/// a named pasteboard, which apps and extensions signed by the same team can both open.
enum SharedBoard {
    static let name = UIPasteboard.Name("om.alkhanbashi.wird.shared")
    static var board: UIPasteboard? { UIPasteboard(name: name, create: true) }
    static let available: Bool = board != nil
    private static func type(_ key: String) -> String { "om.alkhanbashi.wird." + key }

    static func read(_ key: String) -> Data? {
        guard let b = board, let item = b.items.first else { return nil }
        return item[type(key)] as? Data
    }

    static func write(_ key: String, _ data: Data) {
        guard let b = board else { return }
        var item = b.items.first ?? [:]
        item[type(key)] = data
        b.setItems([item], options: [:])
    }
}

/// Keychain items in a team-wide access group are readable by the app and its widget extension
/// when the signing profile allows the team's keychain groups (most signing tools do).
enum Keychain {
    static let service = "om.alkhanbashi.wird.shared"

    static let accessGroup: String? = {
        // learn the team prefix from an item in the default group
        let probe: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service + ".probe",
                                    kSecAttrAccount as String: "probe"]
        var q = probe
        q[kSecReturnAttributes as String] = true
        var out: CFTypeRef?
        var st = SecItemCopyMatching(q as CFDictionary, &out)
        if st == errSecItemNotFound {
            var add = probe
            add[kSecValueData as String] = Data([1])
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            add[kSecReturnAttributes as String] = true
            st = SecItemAdd(add as CFDictionary, &out)
        }
        guard st == errSecSuccess, let attrs = out as? [String: Any],
              let g = attrs[kSecAttrAccessGroup as String] as? String,
              let dot = g.firstIndex(of: ".") else { return nil }
        let team = String(g[..<dot])
        return team + ".om.alkhanbashi.wird.shared"
    }()

    static let available: Bool = {
        guard let g = accessGroup else { return false }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: "check",
                                kSecAttrAccessGroup as String: g]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = Data([1])
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }()

    private static func base(_ key: String) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: key]
        if let g = accessGroup { q[kSecAttrAccessGroup as String] = g }
        return q
    }

    static func read(_ key: String) -> Data? {
        var q = base(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }

    static func write(_ key: String, _ data: Data) {
        let q = base(key)
        let st = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if st == errSecItemNotFound {
            var add = q
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
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
