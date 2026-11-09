import UIKit

/// Turns the page's vibrate patterns (ms numbers or [on, off, on…] arrays) into iPhone haptics.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notify = UINotificationFeedbackGenerator()

    static func play(_ pattern: Any) {
        DispatchQueue.main.async {
            if let n = (pattern as? NSNumber)?.doubleValue {
                pulse(n)
            } else if let arr = pattern as? [Any] {
                let ms = arr.compactMap { ($0 as? NSNumber)?.doubleValue }
                if ms.count >= 5 { notify.notificationOccurred(.success); return }
                var t = 0.0
                for (i, d) in ms.enumerated() {
                    if i % 2 == 0 {
                        let dur = d
                        DispatchQueue.main.asyncAfter(deadline: .now() + t / 1000) { pulse(dur) }
                    }
                    t += d
                }
            }
        }
    }

    private static func pulse(_ ms: Double) {
        if ms <= 0 { return }
        if ms <= 12 { light.impactOccurred(intensity: 0.8) }
        else if ms <= 25 { medium.impactOccurred() }
        else { heavy.impactOccurred() }
    }
}
