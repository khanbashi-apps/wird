import Foundation
import CoreLocation

/// Offline prayer-time calculation (standard astronomical method).
/// Defaults: Fajr 18°, Isha 18°, Asr Shafi'i (shadow ×1) — the method used in Oman.
struct PrayerTimes {
    var fajr: Date, sunrise: Date, dhuhr: Date, asr: Date, maghrib: Date, isha: Date

    static var fajrAngle = 18.0
    static var ishaAngle = 18.0
    static var asrFactor = 1.0
    /// Minutes added to each time, in order: fajr, sunrise, dhuhr, asr, maghrib, isha.
    static var offsets: [Double] = [0, 0, 0, 0, 0, 0]

    static func today() -> PrayerTimes? {
        let c = LocationService.shared.coordinate
        return compute(date: Date(), lat: c.latitude, lng: c.longitude)
    }

    static func compute(date: Date, lat: Double, lng: Double, tz: TimeZone = .current) -> PrayerTimes? {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day,
              let midnight = cal.date(from: DateComponents(year: y, month: m, day: d)) else { return nil }
        let tzHours = Double(tz.secondsFromGMT(for: date)) / 3600
        let jd = julian(y, m, d) - lng / (15 * 24)

        func dtr(_ x: Double) -> Double { x * .pi / 180 }
        func rtd(_ x: Double) -> Double { x * 180 / .pi }
        func fixAngle(_ a: Double) -> Double { let r = a - 360 * floor(a / 360); return r < 0 ? r + 360 : r }
        func fixHour(_ a: Double) -> Double { let r = a - 24 * floor(a / 24); return r < 0 ? r + 24 : r }
        func sunPos(_ j: Double) -> (decl: Double, eqt: Double) {
            let D = j - 2451545.0
            let g = fixAngle(357.529 + 0.98560028 * D)
            let q = fixAngle(280.459 + 0.98564736 * D)
            let L = fixAngle(q + 1.915 * sin(dtr(g)) + 0.020 * sin(dtr(2 * g)))
            let e = 23.439 - 0.00000036 * D
            let RA = rtd(atan2(cos(dtr(e)) * sin(dtr(L)), cos(dtr(L)))) / 15
            let eqt = q / 15 - fixHour(RA)
            let decl = rtd(asin(sin(dtr(e)) * sin(dtr(L))))
            return (decl, eqt)
        }
        func midDay(_ t: Double) -> Double { fixHour(12 - sunPos(jd + t).eqt) }
        func sunAngleTime(_ angle: Double, _ t: Double, ccw: Bool) -> Double? {
            let decl = sunPos(jd + t).decl
            let noon = midDay(t)
            let x = (-sin(dtr(angle)) - sin(dtr(decl)) * sin(dtr(lat))) / (cos(dtr(decl)) * cos(dtr(lat)))
            guard x >= -1, x <= 1 else { return nil }
            let T = rtd(acos(x)) / 15
            return noon + (ccw ? -T : T)
        }
        func asrTime(_ t: Double) -> Double? {
            let decl = sunPos(jd + t).decl
            let angle = -rtd(atan(1 / (asrFactor + tan(dtr(abs(lat - decl))))))
            return sunAngleTime(angle, t, ccw: false)
        }

        // first pass with rough times, second pass refined (as in PrayTimes)
        var times: [Double] = [5, 6, 12, 13, 18, 18]
        for _ in 0..<2 {
            let p = times.map { $0 / 24 }
            let fajr = sunAngleTime(fajrAngle, p[0], ccw: true) ?? times[0]
            let rise = sunAngleTime(0.833, p[1], ccw: true) ?? times[1]
            let dhuhr = midDay(p[2])
            let asr = asrTime(p[3]) ?? times[3]
            let sunset = sunAngleTime(0.833, p[4], ccw: false) ?? times[4]
            let isha = sunAngleTime(ishaAngle, p[5], ccw: false) ?? times[5]
            times = [fajr, rise, dhuhr, asr, sunset, isha]
        }
        let adjusted = times.enumerated().map { (i, h) in h + tzHours - lng / 15 + offsets[i] / 60 }
        let dates = adjusted.map { midnight.addingTimeInterval($0 * 3600) }
        return PrayerTimes(fajr: dates[0], sunrise: dates[1], dhuhr: dates[2], asr: dates[3], maghrib: dates[4], isha: dates[5])
    }

    private static func julian(_ year: Int, _ month: Int, _ day: Int) -> Double {
        var y = Double(year), m = Double(month)
        if m <= 2 { y -= 1; m += 12 }
        let A = floor(y / 100), B = 2 - A + floor(A / 4)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + Double(day) + B - 1524.5
    }

    /// Local hours (e.g. 4.83) for the page.
    func asHours() -> [String: Double] {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        func h(_ d: Date) -> Double { let c = cal.dateComponents([.hour, .minute, .second], from: d); return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600 }
        return ["fajr": h(fajr), "sunrise": h(sunrise), "dhuhr": h(dhuhr), "asr": h(asr), "maghrib": h(maghrib), "isha": h(isha)]
    }

    var all: [(name: String, date: Date)] { [("الفجر", fajr), ("الظهر", dhuhr), ("العصر", asr), ("المغرب", maghrib), ("العشاء", isha)] }
}

/// Finds the user's place once (when in use), remembers it, falls back to Muscat.
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    private let manager = CLLocationManager()
    private let d = UserDefaults.standard
    var onUpdate: (() -> Void)?

    var coordinate: CLLocationCoordinate2D {
        if d.object(forKey: "loc.lat") != nil {
            return CLLocationCoordinate2D(latitude: d.double(forKey: "loc.lat"), longitude: d.double(forKey: "loc.lng"))
        }
        return CLLocationCoordinate2D(latitude: 23.5880, longitude: 58.3829) // Muscat
    }
    var placeName: String { d.string(forKey: "loc.name") ?? "مسقط" }
    var note: String {
        switch manager.authorizationStatus {
        case .denied, .restricted: return "الموقع غير مسموح، المواقيت محسوبة لمسقط. اسمح بالموقع من الإعدادات ← وِرد."
        case .notDetermined: return "المواقيت محسوبة لمسقط حتى تسمح بالموقع"
        default: return d.object(forKey: "loc.lat") == nil ? "جارٍ تحديد الموقع…" : "من موقعك، بدون إنترنت"
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start(force: Bool = false) {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            let last = d.double(forKey: "loc.at")
            if force || Date().timeIntervalSince1970 - last > 6 * 3600 { manager.requestLocation() }
        default: onUpdate?()
        }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        if m.authorizationStatus == .authorizedWhenInUse || m.authorizationStatus == .authorizedAlways { m.requestLocation() }
        else { onUpdate?() }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        d.set(loc.coordinate.latitude, forKey: "loc.lat")
        d.set(loc.coordinate.longitude, forKey: "loc.lng")
        d.set(Date().timeIntervalSince1970, forKey: "loc.at")
        CLGeocoder().reverseGeocodeLocation(loc, preferredLocale: Locale(identifier: "ar")) { [weak self] marks, _ in
            if let p = marks?.first {
                let name = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea
                if let name { self?.d.set(name, forKey: "loc.name") }
            }
            DispatchQueue.main.async { self?.onUpdate?() }
        }
        DispatchQueue.main.async { self.onUpdate?() }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.onUpdate?() }
    }
}
