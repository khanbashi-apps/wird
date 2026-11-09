import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

#if WIDGET_EXTENSION
@main
struct WirdWidgetBundle: WidgetBundle {
    var body: some Widget {
        RingWidget()
        OctagramWidget()
        ButtonWidget()
        BeadsWidget()
        WeekWidget()
        LockRingWidget()
        LockOctagramWidget()
        LockButtonWidget()
        LockBeadsWidget()
        LockWeekWidget()
        WirdLiveActivity()
    }
}

#endif

// MARK: - «تعديل الأداة» options
#if WIDGET_EXTENSION
enum WColors: String, AppEnum {
    case app, navy, emerald, sand, teal
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "الألوان"
    static var caseDisplayRepresentations: [WColors: DisplayRepresentation] = [
        .app: "حسب التطبيق", .navy: "كحلي ذهبي", .emerald: "زمرّدي", .sand: "رملي", .teal: "فيروزي"
    ]
}
#endif

#if WIDGET_EXTENSION
enum WMode: String, AppEnum {
    case auto, day, night
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "الوضع"
    static var caseDisplayRepresentations: [WMode: DisplayRepresentation] = [
        .auto: "تلقائي مع الآيفون", .day: "نهاري", .night: "ليلي"
    ]
}
#endif

#if WIDGET_EXTENSION
enum WDigits: String, AppEnum {
    case arabic, english
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "الأرقام"
    static var caseDisplayRepresentations: [WDigits: DisplayRepresentation] = [
        .arabic: "عربية ١٢٣", .english: "إنجليزية 123"
    ]
}
#endif

#if WIDGET_EXTENSION
enum WBackground: String, AppEnum {
    case gradient, solid
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "الخلفية"
    static var caseDisplayRepresentations: [WBackground: DisplayRepresentation] = [
        .gradient: "متدرّجة", .solid: "سادة"
    ]
}
#endif

#if WIDGET_EXTENSION
struct WirdStyleIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "شكل الأداة"
    static var description = IntentDescription("الألوان والوضع والأرقام والخلفية.")

    @Parameter(title: "الألوان", default: .app) var colors: WColors
    @Parameter(title: "الوضع", default: .auto) var mode: WMode
    @Parameter(title: "الأرقام", default: .arabic) var digits: WDigits
    @Parameter(title: "الخلفية", default: .gradient) var background: WBackground

    init() {}
}
#endif

#if WIDGET_EXTENSION
struct WirdLockIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "أداة شاشة القفل"
    static var description = IntentDescription("طريقة كتابة الأرقام.")

    @Parameter(title: "الأرقام", default: .arabic) var digits: WDigits

    init() {}
}
#endif

#if !WIDGET_EXTENSION
// The app only needs plain values (for the widget preview gallery); intents live in the extension.
enum WColors: String { case app, navy, emerald, sand, teal }
enum WMode: String { case auto, day, night }
enum WDigits: String { case arabic, english }
enum WBackground: String { case gradient, solid }
#endif

// MARK: - timeline
struct WStyle {
    var colors: WColors = .app
    var mode: WMode = .auto
    var digits: WDigits = .arabic
    var background: WBackground = .gradient
}

struct IstEntry: TimelineEntry {
    let date: Date
    let state: IstState
    var style = WStyle()
    var today: Int { IstStore.today(state) }
    var progress: Double { min(1, Double(today) / Double(max(1, state.goal))) }
    func n(_ v: Int) -> String { style.digits == .english ? String(v) : ArabicNum.str(v) }
    var plus: String { style.digits == .english ? "+1" : "+١" }
}

private func placeholderState() -> IstState {
    var s = IstState(); s.days[IstStore.dayKey()] = 120; return s
}
func makeTimeline(_ s: IstState, _ style: WStyle) -> Timeline<IstEntry> {
    let cal = Calendar(identifier: .gregorian)
    let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    return Timeline(entries: [IstEntry(date: Date(), state: s, style: style),
                              IstEntry(date: midnight.addingTimeInterval(1), state: s, style: style)],
                    policy: .after(midnight.addingTimeInterval(2)))
}

#if WIDGET_EXTENSION
struct StyleProvider: AppIntentTimelineProvider {
    func style(_ c: WirdStyleIntent) -> WStyle { WStyle(colors: c.colors, mode: c.mode, digits: c.digits, background: c.background) }
    func placeholder(in context: Context) -> IstEntry { IstEntry(date: Date(), state: placeholderState()) }
    func snapshot(for configuration: WirdStyleIntent, in context: Context) async -> IstEntry {
        let s = IstStore.load()
        return IstEntry(date: Date(), state: context.isPreview && s.total == 0 ? placeholderState() : s, style: style(configuration))
    }
    func timeline(for configuration: WirdStyleIntent, in context: Context) async -> Timeline<IstEntry> {
        makeTimeline(IstStore.load(), style(configuration))
    }
}
#endif

#if WIDGET_EXTENSION
struct LockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> IstEntry { IstEntry(date: Date(), state: placeholderState()) }
    func snapshot(for configuration: WirdLockIntent, in context: Context) async -> IstEntry {
        let s = IstStore.load()
        return IstEntry(date: Date(), state: context.isPreview && s.total == 0 ? placeholderState() : s, style: WStyle(digits: configuration.digits))
    }
    func timeline(for configuration: WirdLockIntent, in context: Context) async -> Timeline<IstEntry> {
        makeTimeline(IstStore.load(), WStyle(digits: configuration.digits))
    }
}
#endif

// MARK: - colors
struct Theme {
    let c: WirdColors
    let solid: Bool
    init(_ e: IstEntry, _ scheme: ColorScheme) {
        let pal: WirdPalette = e.style.colors == .app ? e.state.palette : (WirdPalette.all[e.style.colors.rawValue] ?? .navy)
        let dark: Bool
        switch e.style.mode {
        case .auto: dark = scheme == .dark
        case .day: dark = false
        case .night: dark = true
        }
        c = dark ? pal.dark : pal.light
        solid = e.style.background == .solid
    }
    @ViewBuilder var bg: some View {
        if solid { Color(hex: c.bg2) }
        else { LinearGradient(colors: [Color(hex: c.bg1), Color(hex: c.bg2)], startPoint: .topTrailing, endPoint: .bottomLeading) }
    }
    var bead: Color { Color(hex: c.bead) }
    var text: Color { Color(hex: c.tx) }
    var orn: Color { Color(hex: c.orn) }
    var acc: Color { Color(hex: c.acc) }
    var accFg: Color { Color(hex: c.accFg) }
    /// text on a bead-coloured button
    var onBead: Color { Color(hex: c.bg2) }
}

// MARK: - shared pieces
struct Ring: View {
    let progress: Double
    let color: Color
    let width: CGFloat
    var track: Color? = nil
    var body: some View {
        ZStack {
            Circle().stroke(track ?? color.opacity(0.18), lineWidth: width)
            Circle().trim(from: 0, to: max(0.001, progress))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// The eight-pointed star used inside the app (two squares, 16 points).
struct Octagram: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY, R = min(rect.width, rect.height) / 2
        var p = Path()
        for k in 0..<16 {
            let a = (Double(k) * 22.5 - 90) * .pi / 180
            let r = k % 2 == 1 ? R * 0.7654 : R
            let pt = CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Ring + star like the app's counter. The star turns a step with every istighfar.
struct OctagramDial: View {
    let today: Int
    let progress: Double
    let label: String
    let sub: String?
    let ring: Color, star: Color, text: Color, track: Color
    var size: CGFloat
    var body: some View {
        ZStack {
            Ring(progress: progress, color: ring, width: max(3, size * 0.035), track: track)
            Octagram()
                .fill(star.opacity(0.12))
                .overlay(Octagram().stroke(star, lineWidth: max(1, size * 0.012)))
                .padding(size * 0.15)
                .rotationEffect(.degrees(Double(today % 8) * 45))
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: today)
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                    .foregroundStyle(text)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .contentTransition(.numericText(value: Double(today)))
                if let sub {
                    Text(sub).font(.system(size: max(9, size * 0.075))).foregroundStyle(text.opacity(0.65)).lineLimit(1)
                }
            }
            .padding(.horizontal, size * 0.24)
        }
        .frame(width: size, height: size)
    }
}

struct PlusButton: View {
    let label: String
    let fg: Color, bg: Color
    var wide = false
    var body: some View {
        Button(intent: AddIstighfarIntent()) {
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(fg)
                .frame(maxWidth: wide ? .infinity : nil)
                .frame(minWidth: 58, minHeight: 36)
                .background(Capsule().fill(bg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("أضف استغفاراً")
    }
}

struct BeadsRing: View {
    let count: Int
    let lit: Int
    let on: Color, off: Color
    var body: some View {
        GeometryReader { g in
            let r = min(g.size.width, g.size.height) / 2
            // bead size from the spacing on the circle, so neighbours never touch
            let step = 2 * Double.pi / Double(count)
            let b = r * sin(step / 2) / (1 + sin(step / 2)) * 0.78
            let rr = r - b - 1
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let a = Double(i) * step - .pi / 2
                    Circle().fill(i < lit ? on : off)
                        .frame(width: b * 2, height: b * 2)
                        .position(x: g.size.width / 2 + rr * cos(a), y: g.size.height / 2 + rr * sin(a))
                }
            }
        }
    }
}

struct WeekBars: View {
    let state: IstState
    let color: Color, label: Color
    var compact = false
    var body: some View {
        let days = IstStore.lastDays(state, count: 7)
        let mx = max(Double(state.goal), Double(days.map(\.value).max() ?? 1))
        let f: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "ar"); f.dateFormat = "EEEEE"; return f }()
        HStack(alignment: .bottom, spacing: compact ? 3 : 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { item in
                let i = item.offset
                let d = item.element
                VStack(spacing: 3) {
                    GeometryReader { g in
                        VStack { Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: compact ? 2 : 4).fill(i == days.count - 1 ? color : color.opacity(0.4))
                                .frame(height: max(3, g.size.height * CGFloat(Double(d.value) / mx)))
                        }
                    }
                    if !compact {
                        Text(f.string(from: d.date)).font(.system(size: 9)).foregroundStyle(label.opacity(0.6))
                    }
                }
            }
        }
    }
}

// MARK: - 1. ring (small, medium, large)
#if WIDGET_EXTENSION
struct RingWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "wird.ring", intent: WirdStyleIntent.self, provider: StyleProvider()) { e in RingView(e: e) }
            .configurationDisplayName("حلقة الاستغفار")
            .description("عدد اليوم حول حلقة الهدف. النقر عليها يضيف استغفاراً.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
#endif

struct RingView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var envFamily
    var forced: WidgetFamily? = nil
    var family: WidgetFamily { forced ?? envFamily }
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let th = Theme(e, scheme)
        Group {
            switch family {
            case .systemMedium:
                HStack(spacing: 14) {
                    ZStack {
                        Ring(progress: e.progress, color: th.bead, width: 9)
                        VStack(spacing: 2) {
                            Text(e.n(e.today)).font(.system(size: 34, weight: .bold)).foregroundStyle(th.bead)
                                .contentTransition(.numericText(value: Double(e.today)))
                            Text("من \(e.n(e.state.goal))").font(.system(size: 11)).foregroundStyle(th.text.opacity(0.7))
                        }
                    }.frame(width: 120, height: 120)
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(e.state.formText).font(.system(size: 17, weight: .semibold)).foregroundStyle(th.text).lineLimit(2).multilineTextAlignment(.trailing)
                        Spacer(minLength: 0)
                        PlusButton(label: e.plus, fg: th.onBead, bg: th.bead)
                    }.frame(maxWidth: .infinity, alignment: .trailing)
                }
            case .systemLarge:
                VStack(spacing: 12) {
                    HStack {
                        Text("وِرد · الاستغفار").font(.system(size: 13, weight: .semibold)).foregroundStyle(th.text)
                        Spacer()
                        Text("سلسلة \(e.n(IstStore.streak(e.state)))").font(.system(size: 11)).foregroundStyle(th.text.opacity(0.7))
                    }
                    ZStack {
                        Ring(progress: e.progress, color: th.bead, width: 10)
                        VStack(spacing: 2) {
                            Text(e.n(e.today)).font(.system(size: 46, weight: .bold)).foregroundStyle(th.bead)
                                .contentTransition(.numericText(value: Double(e.today)))
                            Text("من \(e.n(e.state.goal))").font(.system(size: 12)).foregroundStyle(th.text.opacity(0.7))
                        }
                    }.frame(width: 150, height: 150)
                    Text(e.state.formText).font(.system(size: 18, weight: .semibold)).foregroundStyle(th.text).lineLimit(2).multilineTextAlignment(.center)
                    WeekBars(state: e.state, color: th.bead, label: th.text).frame(height: 64)
                    PlusButton(label: e.plus, fg: th.onBead, bg: th.bead, wide: true)
                }
            default:
                Button(intent: AddIstighfarIntent()) {
                    ZStack {
                        Ring(progress: e.progress, color: th.bead, width: 9).padding(4)
                        VStack(spacing: 2) {
                            Text(e.n(e.today)).font(.system(size: 34, weight: .bold)).foregroundStyle(th.bead)
                                .minimumScaleFactor(0.6).lineLimit(1)
                                .contentTransition(.numericText(value: Double(e.today)))
                            Text("من \(e.n(e.state.goal))").font(.system(size: 11)).foregroundStyle(th.text.opacity(0.7))
                        }.padding(.horizontal, 18)
                    }
                }.buttonStyle(.plain)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(for: .widget) { th.bg }
    }
}

// MARK: - 2. octagram, like the counter inside the app (small, medium, large)
#if WIDGET_EXTENSION
struct OctagramWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "wird.octagram", intent: WirdStyleIntent.self, provider: StyleProvider()) { e in OctagramView(e: e) }
            .configurationDisplayName("النجمة الثمانية")
            .description("نفس عدّاد التطبيق: النجمة تدور مع كل استغفار.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
#endif

struct OctagramView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var envFamily
    var forced: WidgetFamily? = nil
    var family: WidgetFamily { forced ?? envFamily }
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let th = Theme(e, scheme)
        let track = th.text.opacity(0.14)
        Group {
            switch family {
            case .systemMedium:
                HStack(spacing: 14) {
                    Button(intent: AddIstighfarIntent()) {
                        OctagramDial(today: e.today, progress: e.progress, label: e.n(e.today), sub: nil,
                                     ring: th.orn, star: th.orn, text: th.text, track: track, size: 128)
                    }.buttonStyle(.plain)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(e.state.formText).font(.system(size: 18, weight: .semibold)).foregroundStyle(th.text)
                            .lineLimit(2).multilineTextAlignment(.trailing)
                        Text("الهدف اليومي \(e.n(e.state.goal))").font(.system(size: 12)).foregroundStyle(th.text.opacity(0.7))
                        Spacer(minLength: 0)
                        PlusButton(label: e.plus, fg: th.accFg, bg: th.acc, wide: true)
                    }.frame(maxWidth: .infinity, alignment: .trailing)
                }
            case .systemLarge:
                VStack(spacing: 10) {
                    Text(e.state.formText).font(.system(size: 22, weight: .semibold)).foregroundStyle(th.text)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Button(intent: AddIstighfarIntent()) {
                        OctagramDial(today: e.today, progress: e.progress, label: e.n(e.today), sub: "من \(e.n(e.state.goal))",
                                     ring: th.orn, star: th.orn, text: th.text, track: track, size: 210)
                    }.buttonStyle(.plain)
                    Spacer(minLength: 0)
                    HStack {
                        Text("المجموع \(e.n(e.state.total))").font(.system(size: 12)).foregroundStyle(th.text.opacity(0.75))
                        Spacer()
                        Text("سلسلة الهدف \(e.n(IstStore.streak(e.state)))").font(.system(size: 12)).foregroundStyle(th.text.opacity(0.75))
                    }
                }
            default:
                Button(intent: AddIstighfarIntent()) {
                    GeometryReader { g in
                        OctagramDial(today: e.today, progress: e.progress, label: e.n(e.today), sub: nil,
                                     ring: th.orn, star: th.orn, text: th.text, track: track, size: min(g.size.width, g.size.height))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }.buttonStyle(.plain)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(for: .widget) { th.bg }
    }
}

// MARK: - 3. button (small + medium)
#if WIDGET_EXTENSION
struct ButtonWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "wird.button", intent: WirdStyleIntent.self, provider: StyleProvider()) { e in ButtonView(e: e) }
            .configurationDisplayName("زر الاستغفار")
            .description("الصيغة والعدد وزر +١ كبير.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
#endif

struct ButtonView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var envFamily
    var forced: WidgetFamily? = nil
    var family: WidgetFamily { forced ?? envFamily }
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let th = Theme(e, scheme)
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                Text(e.state.formShort).font(.system(size: 12, weight: .medium)).foregroundStyle(th.text.opacity(0.75)).lineLimit(1)
                Spacer()
                Octagram().stroke(th.orn, lineWidth: 1.2).frame(width: 14, height: 14)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline) {
                Text(e.n(e.today)).font(.system(size: family == .systemMedium ? 44 : 38, weight: .bold)).foregroundStyle(th.orn)
                    .minimumScaleFactor(0.6).lineLimit(1)
                    .contentTransition(.numericText(value: Double(e.today)))
                Spacer()
                if family == .systemMedium {
                    Text("الهدف \(e.n(e.state.goal))").font(.system(size: 12)).foregroundStyle(th.text.opacity(0.7))
                }
            }
            ProgressView(value: e.progress).tint(th.orn)
            PlusButton(label: e.plus, fg: th.accFg, bg: th.acc, wide: true)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(for: .widget) { th.bg }
    }
}

// MARK: - 4. beads (small + medium)
#if WIDGET_EXTENSION
struct BeadsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "wird.beads", intent: WirdStyleIntent.self, provider: StyleProvider()) { e in BeadsView(e: e) }
            .configurationDisplayName("السبحة")
            .description("ثلاث وثلاثون حبة تضيء كلما اقتربت من هدفك.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
#endif

struct BeadsView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var envFamily
    var forced: WidgetFamily? = nil
    var family: WidgetFamily { forced ?? envFamily }
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let th = Theme(e, scheme)
        let lit = Int((e.progress * 33).rounded(.down))
        let dial = Button(intent: AddIstighfarIntent()) {
            ZStack {
                BeadsRing(count: 33, lit: lit, on: th.bead, off: th.text.opacity(0.16))
                VStack(spacing: 0) {
                    Text(e.n(e.today)).font(.system(size: 30, weight: .bold)).foregroundStyle(th.text)
                        .minimumScaleFactor(0.5).lineLimit(1)
                        .contentTransition(.numericText(value: Double(e.today)))
                    Text("من \(e.n(e.state.goal))").font(.system(size: 10)).foregroundStyle(th.text.opacity(0.6))
                }.padding(.horizontal, 22)
            }
        }.buttonStyle(.plain)
        Group {
            if family == .systemMedium {
                HStack(spacing: 14) {
                    dial.frame(width: 130, height: 130)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(e.state.formText).font(.system(size: 18, weight: .semibold)).foregroundStyle(th.text)
                            .lineLimit(2).multilineTextAlignment(.trailing)
                        Spacer(minLength: 0)
                        PlusButton(label: e.plus, fg: th.onBead, bg: th.bead, wide: true)
                    }.frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                dial
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(for: .widget) { th.bg }
    }
}

// MARK: - 5. week (medium + large)
#if WIDGET_EXTENSION
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "wird.week", intent: WirdStyleIntent.self, provider: StyleProvider()) { e in WeekView(e: e) }
            .configurationDisplayName("أسبوع الاستغفار")
            .description("عدد كل يوم في آخر سبعة أيام.")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}
#endif

struct WeekView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var envFamily
    var forced: WidgetFamily? = nil
    var family: WidgetFamily { forced ?? envFamily }
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let th = Theme(e, scheme)
        let week = IstStore.lastDays(e.state, count: 7).map(\.value).reduce(0, +)
        VStack(alignment: .trailing, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("اليوم").font(.system(size: 11)).foregroundStyle(th.text.opacity(0.7))
                    Text(e.n(e.today)).font(.system(size: 36, weight: .bold)).foregroundStyle(th.bead)
                        .contentTransition(.numericText(value: Double(e.today)))
                    Text("الأسبوع \(e.n(week))").font(.system(size: 11)).foregroundStyle(th.text.opacity(0.7))
                }
                Spacer()
                PlusButton(label: e.plus, fg: th.onBead, bg: th.bead)
            }
            WeekBars(state: e.state, color: th.bead, label: th.text)
            if family == .systemLarge {
                HStack {
                    Text("المجموع \(e.n(e.state.total))").font(.system(size: 12)).foregroundStyle(th.text.opacity(0.75))
                    Spacer()
                    Text("سلسلة الهدف \(e.n(IstStore.streak(e.state)))").font(.system(size: 12)).foregroundStyle(th.text.opacity(0.75))
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(for: .widget) { th.bg }
    }
}

// MARK: - Lock Screen widgets (small = circle, medium = rectangle, line = inline)
#if WIDGET_EXTENSION
struct LockRingWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "wird.lock.ring", intent: WirdLockIntent.self, provider: LockProvider()) { e in LockRingView(e: e) }
            .configurationDisplayName("حلقة الاستغفار")
            .description("لشاشة القفل. النقر يضيف استغفاراً.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
#endif

struct LockRingView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var envFamily
    var forced: WidgetFamily? = nil
    var family: WidgetFamily { forced ?? envFamily }
    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                Button(intent: AddIstighfarIntent()) {
                    HStack(spacing: 8) {
                        Gauge(value: e.progress) { Text("") } currentValueLabel: {
                            Text(e.n(Int((e.progress * 100).rounded()))).font(.system(size: 12, weight: .semibold))
                        }
                        .gaugeStyle(.accessoryCircularCapacity)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(e.state.formShort).font(.system(size: 12)).lineLimit(1).widgetAccentable()
                            Text(e.n(e.today)).font(.system(size: 22, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                                .contentTransition(.numericText(value: Double(e.today)))
                            Text("من \(e.n(e.state.goal))").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.buttonStyle(.plain)
            case .accessoryInline:
                Text("\(e.state.formShort) \(e.n(e.today)) / \(e.n(e.state.goal))")
            default:
                Button(intent: AddIstighfarIntent()) {
                    Gauge(value: e.progress) { Text("") } currentValueLabel: {
                        Text(e.n(e.today)).font(.system(size: 15, weight: .bold)).minimumScaleFactor(0.5)
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                }.buttonStyle(.plain)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

#if WIDGET_EXTENSION
struct LockOctagramWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "wird.lock.octagram", intent: WirdLockIntent.self, provider: LockProvider()) { e in LockOctagramView(e: e) }
            .configurationDisplayName("النجمة الثمانية")
            .description("نجمة التطبيق على شاشة القفل، تدور مع كل استغفار.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
#endif

struct LockOctagramView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var envFamily
    var forced: WidgetFamily? = nil
    var family: WidgetFamily { forced ?? envFamily }
    var body: some View {
        Group {
            if family == .accessoryRectangular {
                Button(intent: AddIstighfarIntent()) {
                    HStack(spacing: 8) {
                        OctagramDial(today: e.today, progress: e.progress, label: "", sub: nil,
                                     ring: .primary, star: .primary, text: .primary, track: .primary.opacity(0.25), size: 50)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(e.state.formShort).font(.system(size: 12)).lineLimit(1).widgetAccentable()
                            Text(e.n(e.today)).font(.system(size: 22, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                                .contentTransition(.numericText(value: Double(e.today)))
                            Text("الهدف \(e.n(e.state.goal))").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.buttonStyle(.plain)
            } else {
                Button(intent: AddIstighfarIntent()) {
                    ZStack {
                        AccessoryWidgetBackground()
                        GeometryReader { g in
                            OctagramDial(today: e.today, progress: e.progress, label: e.n(e.today), sub: nil,
                                         ring: .primary, star: .primary, text: .primary, track: .primary.opacity(0.25),
                                         size: min(g.size.width, g.size.height))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }.buttonStyle(.plain)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

#if WIDGET_EXTENSION
struct LockButtonWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "wird.lock.button", intent: WirdLockIntent.self, provider: LockProvider()) { e in LockButtonView(e: e) }
            .configurationDisplayName("زر +١")
            .description("زر كبير على شاشة القفل يضيف استغفاراً.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
#endif

struct LockButtonView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var envFamily
    var forced: WidgetFamily? = nil
    var family: WidgetFamily { forced ?? envFamily }
    var body: some View {
        Group {
            if family == .accessoryRectangular {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(e.state.formShort).font(.system(size: 12)).lineLimit(1)
                        Text(e.n(e.today)).font(.system(size: 24, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                            .contentTransition(.numericText(value: Double(e.today)))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button(intent: AddIstighfarIntent()) {
                        Text(e.plus).font(.system(size: 20, weight: .bold))
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(.primary.opacity(0.22)))
                    }.buttonStyle(.plain).widgetAccentable()
                }
            } else {
                Button(intent: AddIstighfarIntent()) {
                    ZStack {
                        AccessoryWidgetBackground()
                        VStack(spacing: -2) {
                            Text(e.plus).font(.system(size: 20, weight: .bold)).widgetAccentable()
                            Text(e.n(e.today)).font(.system(size: 11, weight: .semibold)).minimumScaleFactor(0.5).lineLimit(1)
                                .contentTransition(.numericText(value: Double(e.today)))
                        }.padding(.horizontal, 6)
                    }
                }.buttonStyle(.plain)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

#if WIDGET_EXTENSION
struct LockBeadsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "wird.lock.beads", intent: WirdLockIntent.self, provider: LockProvider()) { e in LockBeadsView(e: e) }
            .configurationDisplayName("السبحة")
            .description("حبات تضيء مع التقدم نحو الهدف.")
            .supportedFamilies([.accessoryCircular])
    }
}
#endif

struct LockBeadsView: View {
    let e: IstEntry
    var body: some View {
        Button(intent: AddIstighfarIntent()) {
            ZStack {
                BeadsRing(count: 20, lit: Int((e.progress * 20).rounded(.down)), on: .primary, off: .primary.opacity(0.25))
                Text(e.n(e.today)).font(.system(size: 14, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1)
                    .padding(.horizontal, 12)
                    .contentTransition(.numericText(value: Double(e.today)))
            }
        }
        .buttonStyle(.plain)
        .containerBackground(for: .widget) { Color.clear }
    }
}

#if WIDGET_EXTENSION
struct LockWeekWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "wird.lock.week", intent: WirdLockIntent.self, provider: LockProvider()) { e in LockWeekView(e: e) }
            .configurationDisplayName("أسبوع الاستغفار")
            .description("عدد اليوم وأعمدة آخر سبعة أيام.")
            .supportedFamilies([.accessoryRectangular])
    }
}
#endif

struct LockWeekView: View {
    let e: IstEntry
    var body: some View {
        Button(intent: AddIstighfarIntent()) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("اليوم").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(e.n(e.today)).font(.system(size: 22, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                        .contentTransition(.numericText(value: Double(e.today)))
                }
                WeekBars(state: e.state, color: .primary, label: .primary, compact: true)
                    .environment(\.layoutDirection, .leftToRight)
                    .widgetAccentable()
            }
        }
        .buttonStyle(.plain)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct LiveCard: View {
    let attributes: WirdActivityAttributes
    let state: WirdActivityAttributes.ContentState
    var body: some View {
            let c = attributes.palette.dark
            let gold = Color(hex: c.bead)
            let p = min(1, Double(state.today) / Double(max(1, state.goal)))
            HStack(spacing: 14) {
                ZStack {
                    Ring(progress: p, color: gold, width: 6, track: .primary.opacity(0.18))
                    Text(ArabicNum.str(state.today)).font(.system(size: 20, weight: .bold)).foregroundStyle(.primary)
                        .minimumScaleFactor(0.5).lineLimit(1).padding(.horizontal, 8)
                        .contentTransition(.numericText(value: Double(state.today)))
                }.frame(width: 64, height: 64)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(attributes.formText).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary).lineLimit(1)
                    Text("الهدف \(ArabicNum.str(state.goal)) · هذه الجلسة \(ArabicNum.str(state.session))").font(.system(size: 12)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .trailing)
                Button(intent: LiveAddIstighfarIntent()) {
                    Text("+١").font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: c.bg2))
                        .frame(width: 58, height: 58).background(Circle().fill(gold))
                }.buttonStyle(.plain)
            }
            .padding(16)
            .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Lock Screen live activity (+ Dynamic Island where available)
// No background tint, so iOS draws its own glass like other notifications.
#if WIDGET_EXTENSION
struct WirdLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WirdActivityAttributes.self) { ctx in
            LiveCard(attributes: ctx.attributes, state: ctx.state)
                .activitySystemActionForegroundColor(Color(hex: ctx.attributes.palette.dark.bead))
        } dynamicIsland: { ctx in
            let c = ctx.attributes.palette.dark
            let p = min(1, Double(ctx.state.today) / Double(max(1, ctx.state.goal)))
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(ArabicNum.str(ctx.state.today)).font(.system(size: 26, weight: .bold)).foregroundStyle(Color(hex: c.bead))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: LiveAddIstighfarIntent()) {
                        Text("+١").font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: c.bg2))
                            .frame(width: 50, height: 50).background(Circle().fill(Color(hex: c.bead)))
                    }.buttonStyle(.plain)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(ctx.attributes.formText).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: p).tint(Color(hex: c.bead))
                }
            } compactLeading: {
                Octagram().stroke(Color(hex: c.bead), lineWidth: 1.5).frame(width: 16, height: 16)
            } compactTrailing: {
                Text(ArabicNum.str(ctx.state.today)).font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: c.bead))
            } minimal: {
                Text(ArabicNum.str(ctx.state.today)).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: c.bead))
            }
        }
    }
}
#endif
