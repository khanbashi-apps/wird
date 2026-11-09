import Foundation
import UserNotifications

/// Local reminders built from the day's prayer times (next 6 days, within iOS's 64 limit).
enum Reminders {
    private static let flagsKey = "rem.flags"
    static var status = "unknown"

    static var flags: [String: Bool] {
        UserDefaults.standard.dictionary(forKey: flagsKey) as? [String: Bool]
            ?? ["morning": true, "evening": true, "kahf": true, "mulk": false, "prayer": false, "sahar": false]
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
            let loc = LocationService.shared.coordinate
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

            for dayOffset in 0..<6 {
                guard let day = cal.date(byAdding: .day, value: dayOffset, to: now),
                      let t = PrayerTimes.compute(date: day, lat: loc.latitude, lng: loc.longitude) else { continue }
                let key = IstStore.dayKey(day)
                let weekday = cal.component(.weekday, from: day) // 5 = Thursday, 6 = Friday
                if f["morning"] == true { add("morning.\(key)", t.fajr.addingTimeInterval(15 * 60), "أذكار الصباح", "حان وقت أذكار الصباح، ابدأ وردك.", "morning") }
                if f["evening"] == true { add("evening.\(key)", t.asr.addingTimeInterval(15 * 60), "أذكار المساء", "حان وقت أذكار المساء.", "evening") }
                if f["mulk"] == true { add("mulk.\(key)", t.isha.addingTimeInterval(2 * 3600), "سورة الملك", "ورد ما قبل النوم: سورة الملك، المنجية.", "mulk") }
                if f["kahf"] == true {
                    if weekday == 5 { add("kahf.thu.\(key)", t.maghrib.addingTimeInterval(10 * 60), "ليلة الجمعة", "اغتنم قراءة سورة الكهف.", "kahf") }
                    if weekday == 6 { add("kahf.fri.\(key)", t.dhuhr.addingTimeInterval(60 * 60), "سورة الكهف", "لم يبقَ من يوم الجمعة إلا قليل، أكمل سورة الكهف.", "kahf") }
                }
                if f["prayer"] == true {
                    for (i, p) in t.all.enumerated() {
                        add("prayer.\(i).\(key)", p.date.addingTimeInterval(10 * 60), "أستغفر الله", "بعد صلاة \(p.name): أستغفر الله، أستغفر الله، أستغفر الله.", "istighfar")
                    }
                }
                if f["sahar"] == true,
                   let next = PrayerTimes.compute(date: cal.date(byAdding: .day, value: 1, to: day) ?? day, lat: loc.latitude, lng: loc.longitude) {
                    let night = next.fajr.timeIntervalSince(t.maghrib)
                    add("sahar.\(key)", next.fajr.addingTimeInterval(-night / 3), "وقت الأسحار", "﴿وَبِالْأَسْحَارِ هُمْ يَسْتَغْفِرُونَ﴾", "istighfar")
                }
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
