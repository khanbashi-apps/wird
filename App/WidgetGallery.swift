import SwiftUI
import WidgetKit

/// Renders every widget design to PNG files (Documents/widgets) so they can be checked
/// without a device. Used only when the app is launched with WIRD_ROUTE=widgets.
@MainActor
enum WidgetGallery {
    static func run() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dir = docs.appendingPathComponent("widgets")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var s = IstState()
        let cal = Calendar(identifier: .gregorian)
        for (i, v) in [120, 300, 210, 80, 310, 150, 45].enumerated() {
            if let d = cal.date(byAdding: .day, value: -(6 - i), to: Date()) { s.days[IstStore.dayKey(d)] = v }
        }
        s.total = 4_820
        s.goal = 300
        if let sand = WirdPalette.all["sand"] { s.palette = sand }

        let small = CGSize(width: 170, height: 170), medium = CGSize(width: 364, height: 170), large = CGSize(width: 364, height: 382)
        let circ = CGSize(width: 76, height: 76), rect = CGSize(width: 172, height: 76)

        func e(_ st: WStyle = WStyle()) -> IstEntry { IstEntry(date: Date(), state: s, style: st) }
        let navyNight = WStyle(colors: .navy, mode: .night)
        let emeraldDay = WStyle(colors: .emerald, mode: .day, digits: .english)
        let tealSolid = WStyle(colors: .teal, mode: .night, digits: .arabic, background: .solid)

        var items: [(String, AnyView, CGSize, Bool)] = [
            ("ring-s", AnyView(RingView(e: e(navyNight), forced: .systemSmall)), small, false),
            ("ring-m", AnyView(RingView(e: e(), forced: .systemMedium)), medium, false),
            ("ring-l", AnyView(RingView(e: e(emeraldDay), forced: .systemLarge)), large, false),
            ("oct-s", AnyView(OctagramView(e: e(), forced: .systemSmall)), small, false),
            ("oct-s-day", AnyView(OctagramView(e: e(emeraldDay), forced: .systemSmall)), small, false),
            ("oct-m", AnyView(OctagramView(e: e(navyNight), forced: .systemMedium)), medium, false),
            ("oct-l", AnyView(OctagramView(e: e(tealSolid), forced: .systemLarge)), large, false),
            ("btn-s", AnyView(ButtonView(e: e(navyNight), forced: .systemSmall)), small, false),
            ("btn-m", AnyView(ButtonView(e: e(emeraldDay), forced: .systemMedium)), medium, false),
            ("beads-s", AnyView(BeadsView(e: e(navyNight), forced: .systemSmall)), small, false),
            ("beads-m", AnyView(BeadsView(e: e(), forced: .systemMedium)), medium, false),
            ("week-m", AnyView(WeekView(e: e(navyNight), forced: .systemMedium)), medium, false),
            ("week-l", AnyView(WeekView(e: e(emeraldDay), forced: .systemLarge)), large, false),
            ("lock-ring-c", AnyView(LockRingView(e: e(), forced: .accessoryCircular)), circ, true),
            ("lock-ring-r", AnyView(LockRingView(e: e(), forced: .accessoryRectangular)), rect, true),
            ("lock-oct-c", AnyView(LockOctagramView(e: e(), forced: .accessoryCircular)), circ, true),
            ("lock-oct-r", AnyView(LockOctagramView(e: e(), forced: .accessoryRectangular)), rect, true),
            ("lock-btn-c", AnyView(LockButtonView(e: e(), forced: .accessoryCircular)), circ, true),
            ("lock-btn-r", AnyView(LockButtonView(e: e(), forced: .accessoryRectangular)), rect, true),
            ("lock-beads-c", AnyView(LockBeadsView(e: e())), circ, true),
            ("lock-week-r", AnyView(LockWeekView(e: e())), rect, true)
        ]
        let attrs = WirdActivityAttributes(formShort: s.formShort, formText: s.formText, palette: s.palette)
        items.append(("live", AnyView(LiveCard(attributes: attrs, state: .init(today: 45, goal: 300, session: 12))), CGSize(width: 370, height: 96), true))

        for (name, view, size, lock) in items {
            let framed = ZStack {
                if lock { Color(white: 0.18) }
                view.padding(lock ? 0 : 16)
            }
            .frame(width: size.width, height: size.height)
            .background(lock ? AnyView(Color(white: 0.18)) : AnyView(galleryBackground(name, s)))
            .clipShape(RoundedRectangle(cornerRadius: lock ? 12 : 22, style: .continuous))
            .environment(\.colorScheme, lock ? .dark : .light)
            let r = ImageRenderer(content: framed)
            r.scale = 2
            if let img = r.uiImage, let png = img.pngData() {
                try? png.write(to: dir.appendingPathComponent("\(name).png"))
            }
        }
        try? "done".write(to: dir.appendingPathComponent("done.txt"), atomically: true, encoding: .utf8)
    }

    /// containerBackground isn't drawn outside a widget, so paint it here.
    private static func galleryBackground(_ name: String, _ s: IstState) -> some View {
        let st: WStyle
        switch name {
        case "ring-s", "oct-m", "btn-s", "beads-s", "week-m": st = WStyle(colors: .navy, mode: .night)
        case "ring-l", "oct-s-day", "btn-m", "week-l": st = WStyle(colors: .emerald, mode: .day, digits: .english)
        case "oct-l": st = WStyle(colors: .teal, mode: .night, digits: .arabic, background: .solid)
        default: st = WStyle()
        }
        let th = Theme(IstEntry(date: Date(), state: s, style: st), .light)
        return th.bg
    }
}
