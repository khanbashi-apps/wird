import Foundation
import UserNotifications

/// Local reminders at the times chosen in settings (next 7 days, within iOS's 64 limit).
enum Reminders {
    private static let flagsKey = "rem.flags"
    static var status = "unknown"

    static var flags: [String: Bool] {
        UserDefaults.standard.dictionary(forKey: flagsKey) as? [String: Bool]
            ?? ["morning": true, "evening": true, "kahf": true, "mulk": false, "sahar": false]
    }

    private static let timesKey = "rem.times"
    static let defaultTimes = ["morning": "05:30", "evening": "16:15", "kahf": "09:00", "mulk": "21:30", "sahar": "04:00"]
    static var times: [String: String] {
        var t = defaultTimes
        for (k, v) in (UserDefaults.standard.dictionary(forKey: timesKey) as? [String: String] ?? [:]) { t[k] = v }
        return t
    }
    static func saveTimes(_ t: [String: String]) {
        var cur = times
        for (k, v) in t where v.contains(":") { cur[k] = v }
        UserDefaults.standard.set(cur, forKey: timesKey)
    }
    /// "HH:mm" → (hour, minute)
    static func hm(_ key: String) -> (Int, Int) {
        let parts = (times[key] ?? defaultTimes[key] ?? "06:00").split(separator: ":").compactMap { Int($0) }
        return (parts.first ?? 6, parts.count > 1 ? parts[1] : 0)
    }
    static func saveFlags(_ f: [String: Bool]) {
        var cur = flags
        for (k, v) in f { cur[k] = v }
        UserDefaults.standard.set(cur, forKey: flagsKey)
    }

    static func requestIfNeeded() {
        let c = UNUserNotificationCenter.current()
        c.getNotificationSettings { s in
            if s.authorizationStatus == .notDetermined {
                c.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                    status = ok ? "granted" : "denied"
                    if ok { reschedule() }
                }
            } else {
                status = s.authorizationStatus == .denied ? "denied" : "granted"
                reschedule()
            }
        }
    }

    static func cancelFridayKahf() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix("kahf.fri.") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    static func reschedule(done: (() -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { s in
            guard s.authorizationStatus == .authorized || s.authorizationStatus == .provisional || s.authorizationStatus == .ephemeral else { done?(); return }
            center.removeAllPendingNotificationRequests()
            let f = flags
            let now = Date()
            let cal = Calendar(identifier: .gregorian)
            var reqs: [UNNotificationRequest] = []

            func add(_ id: String, _ date: Date, _ title: String, _ body: String, _ route: String) {
                guard date > now.addingTimeInterval(30) else { return }
                let c = UNMutableNotificationContent()
                c.title = title; c.body = body; c.sound = .default
                c.userInfo = ["route": route]
                c.threadIdentifier = route
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                reqs.append(UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }

            func at(_ day: Date, _ key: String) -> Date {
                let (h, m) = hm(key)
                return cal.date(bySettingHour: h, minute: m, second: 0, of: day) ?? day
            }
            for dayOffset in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                let key = IstStore.dayKey(day)
                let weekday = cal.component(.weekday, from: day) // 5 = Thursday, 6 = Friday
                if f["morning"] == true { add("morning.\(key)", at(day, "morning"), "أذكار الصباح", "حان وقت أذكار الصباح، ابدأ وردك.", "morning") }
                if f["evening"] == true { add("evening.\(key)", at(day, "evening"), "أذكار المساء", "حان وقت أذكار المساء.", "evening") }
                if f["mulk"] == true { add("mulk.\(key)", at(day, "mulk"), "سورة الملك", "ورد ما قبل النوم: سورة الملك، المنجية.", "mulk") }
                if f["kahf"] == true {
                    if weekday == 5, let thu = cal.date(bySettingHour: 19, minute: 30, second: 0, of: day) {
                        add("kahf.thu.\(key)", thu, "ليلة الجمعة", "اغتنم قراءة سورة الكهف.", "kahf")
                    }
                    if weekday == 6 { add("kahf.fri.\(key)", at(day, "kahf"), "سورة الكهف", "يوم الجمعة: نورٌ ما بين الجمعتين، اقرأ سورة الكهف.", "kahf") }
                }
                if f["sahar"] == true { add("sahar.\(key)", at(day, "sahar"), "وقت الأسحار", "﴿وَبِالْأَسْحَارِ هُمْ يَسْتَغْفِرُونَ﴾", "istighfar") }
            }
            reqs.sort { a, b in
                let da = (a.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
                let db = (b.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
                return da < db
            }
            for r in reqs.prefix(60) { center.add(r) }
            done?()
        }
    }
}
