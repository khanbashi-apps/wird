import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

@main
struct WirdWidgetBundle: WidgetBundle {
    var body: some Widget {
        RingWidget()
        ButtonWidget()
        BeadsWidget()
        WeekWidget()
        WirdLiveActivity()
    }
}

// MARK: - timeline
struct IstEntry: TimelineEntry {
    let date: Date
    let state: IstState
    var today: Int { IstStore.today(state) }
    var progress: Double { min(1, Double(today) / Double(max(1, state.goal))) }
}

struct IstProvider: TimelineProvider {
    func placeholder(in context: Context) -> IstEntry {
        var s = IstState(); s.days[IstStore.dayKey()] = 120
        return IstEntry(date: Date(), state: s)
    }
    func getSnapshot(in context: Context, completion: @escaping (IstEntry) -> Void) {
        completion(context.isPreview && IstStore.load().total == 0 ? placeholder(in: context) : IstEntry(date: Date(), state: IstStore.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<IstEntry>) -> Void) {
        let s = IstStore.load()
        let cal = Calendar(identifier: .gregorian)
        let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        completion(Timeline(entries: [IstEntry(date: Date(), state: s), IstEntry(date: midnight.addingTimeInterval(1), state: s)], policy: .after(midnight.addingTimeInterval(2))))
    }
}

// MARK: - shared pieces
struct Theme {
    let c: WirdColors
    init(_ s: IstState, _ scheme: ColorScheme) { c = s.palette.colors(scheme) }
    var bg: LinearGradient { LinearGradient(colors: [Color(hex: c.bg1), Color(hex: c.bg2)], startPoint: .topTrailing, endPoint: .bottomLeading) }
    var bead: Color { Color(hex: c.bead) }
    var text: Color { Color(hex: c.tx) }
    var orn: Color { Color(hex: c.orn) }
    var acc: Color { Color(hex: c.acc) }
    var accFg: Color { Color(hex: c.accFg) }
}

struct Ring: View {
    let progress: Double
    let color: Color
    let width: CGFloat
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: width)
            Circle().trim(from: 0, to: max(0.001, progress))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct PlusButton: View {
    let fg: Color, bg: Color
    var wide = false
    var body: some View {
        Button(intent: AddIstighfarIntent()) {
            Text("+١")
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

func num(_ n: Int) -> String { ArabicNum.str(n) }

// MARK: - 1. ring (small, medium, large + lock screen)
struct RingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "wird.ring", provider: IstProvider()) { e in RingView(e: e) }
            .configurationDisplayName("حلقة الاستغفار")
            .description("عدد اليوم حول حلقة الهدف. النقر عليها يضيف استغفاراً.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct RingView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let th = Theme(e.state, scheme)
        Group {
            switch family {
            case .accessoryCircular:
                Button(intent: AddIstighfarIntent()) {
                    Gauge(value: e.progress) { Text("") } currentValueLabel: { Text(num(e.today)).font(.system(size: 15, weight: .bold)) }
                        .gaugeStyle(.accessoryCircularCapacity)
                }.buttonStyle(.plain)
            case .accessoryRectangular:
                Button(intent: AddIstighfarIntent()) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.state.formShort).font(.system(size: 12)).lineLimit(1)
                        Text("\(num(e.today)) من \(num(e.state.goal))").font(.system(size: 18, weight: .bold))
                        ProgressView(value: e.progress).tint(.primary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            case .accessoryInline:
                Text("✦ \(num(e.today)) / \(num(e.state.goal)) استغفار")
            case .systemMedium:
                HStack(spacing: 14) {
                    ZStack {
                        Ring(progress: e.progress, color: th.bead, width: 9)
                        VStack(spacing: 2) {
                            Text(num(e.today)).font(.system(size: 34, weight: .bold)).foregroundStyle(th.bead)
                            Text("من \(num(e.state.goal))").font(.system(size: 11)).foregroundStyle(th.text.opacity(0.7))
                        }
                    }.frame(width: 120, height: 120)
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(e.state.formText).font(.system(size: 17, weight: .semibold)).foregroundStyle(th.text).lineLimit(2).multilineTextAlignment(.trailing)
                        Spacer(minLength: 0)
                        PlusButton(fg: th.c.bg2.isEmpty ? .black : Color(hex: th.c.bg2), bg: th.bead)
                    }.frame(maxWidth: .infinity, alignment: .trailing)
                }
            case .systemLarge:
                VStack(spacing: 12) {
                    HStack {
                        Text("وِرد · الاستغفار").font(.system(size: 13, weight: .semibold)).foregroundStyle(th.text)
                        Spacer()
                        Text("سلسلة \(num(IstStore.streak(e.state)))").font(.system(size: 11)).foregroundStyle(th.text.opacity(0.7))
                    }
                    ZStack {
                        Ring(progress: e.progress, color: th.bead, width: 10)
                        VStack(spacing: 2) {
                            Text(num(e.today)).font(.system(size: 46, weight: .bold)).foregroundStyle(th.bead)
                            Text("من \(num(e.state.goal))").font(.system(size: 12)).foregroundStyle(th.text.opacity(0.7))
                        }
                    }.frame(width: 150, height: 150)
                    Text(e.state.formText).font(.system(size: 18, weight: .semibold)).foregroundStyle(th.text).lineLimit(2).multilineTextAlignment(.center)
                    WeekBars(state: e.state, color: th.bead, label: th.text).frame(height: 64)
                    PlusButton(fg: Color(hex: th.c.bg2), bg: th.bead, wide: true)
                }
            default:
                Button(intent: AddIstighfarIntent()) {
                    ZStack {
                        Ring(progress: e.progress, color: th.bead, width: 9).padding(4)
                        VStack(spacing: 2) {
                            Text(num(e.today)).font(.system(size: 34, weight: .bold)).foregroundStyle(th.bead)
                            Text("من \(num(e.state.goal))").font(.system(size: 11)).foregroundStyle(th.text.opacity(0.7))
                        }
                    }
                }.buttonStyle(.plain)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(for: .widget) { th.bg }
    }
}

// MARK: - 2. button (small + medium)
struct ButtonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "wird.button", provider: IstProvider()) { e in ButtonView(e: e) }
            .configurationDisplayName("زر الاستغفار")
            .description("الصيغة والعدد وزر +١ كبير.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ButtonView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let th = Theme(e.state, scheme)
        let paper = scheme == .dark ? Color(hex: e.state.palette.dark.bg) : Color(hex: "#FBF6EA")
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                Text(e.state.formShort).font(.system(size: 12, weight: .medium)).foregroundStyle(th.text.opacity(0.75)).lineLimit(1)
                Spacer()
                Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(th.orn)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline) {
                Text(num(e.today)).font(.system(size: family == .systemMedium ? 44 : 38, weight: .bold)).foregroundStyle(th.orn)
                Spacer()
                if family == .systemMedium {
                    Text("الهدف \(num(e.state.goal))").font(.system(size: 12)).foregroundStyle(th.text.opacity(0.7))
                }
            }
            ProgressView(value: e.progress).tint(th.orn)
            PlusButton(fg: th.accFg, bg: th.acc, wide: true)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(for: .widget) { paper }
    }
}

// MARK: - 3. beads (small + lock circular)
struct BeadsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "wird.beads", provider: IstProvider()) { e in BeadsView(e: e) }
            .configurationDisplayName("السبحة")
            .description("ثلاث وثلاثون حبة تضيء كلما اقتربت من هدفك.")
            .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct BeadsRing: View {
    let lit: Int
    let on: Color, off: Color
    var body: some View {
        GeometryReader { g in
            let r = min(g.size.width, g.size.height) / 2
            let bead = r * 0.13
            ZStack {
                ForEach(0..<33, id: \.self) { i in
                    let a = (Double(i) * 360 / 33 - 90) * .pi / 180
                    Circle().fill(i < lit ? on : off)
                        .frame(width: bead * 2, height: bead * 2)
                        .position(x: g.size.width / 2 + (r - bead) * cos(a), y: g.size.height / 2 + (r - bead) * sin(a))
                }
            }
        }
    }
}

struct BeadsView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let th = Theme(e.state, scheme)
        let lit = Int((e.progress * 33).rounded())
        Button(intent: AddIstighfarIntent()) {
            ZStack {
                if family == .accessoryCircular {
                    BeadsRing(lit: lit, on: .primary, off: .primary.opacity(0.25))
                    Text("+١").font(.system(size: 16, weight: .bold))
                } else {
                    BeadsRing(lit: lit, on: th.bead, off: th.bead.opacity(0.22)).padding(2)
                    Text(num(e.today)).font(.system(size: 32, weight: .bold)).foregroundStyle(th.text)
                }
            }
        }
        .buttonStyle(.plain)
        .containerBackground(for: .widget) { th.bg }
    }
}

// MARK: - 4. week (medium + large)
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "wird.week", provider: IstProvider()) { e in WeekView(e: e) }
            .configurationDisplayName("أسبوع الاستغفار")
            .description("عدد كل يوم في آخر سبعة أيام.")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct WeekBars: View {
    let state: IstState
    let color: Color, label: Color
    var body: some View {
        let days = IstStore.lastDays(state, count: 7)
        let mx = max(Double(state.goal), Double(days.map(\.value).max() ?? 1))
        let f: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "ar"); f.dateFormat = "EEEEE"; return f }()
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { item in
                let i = item.offset
                let d = item.element
                VStack(spacing: 4) {
                    GeometryReader { g in
                        VStack { Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4).fill(i == days.count - 1 ? color : color.opacity(0.4))
                                .frame(height: max(4, g.size.height * CGFloat(Double(d.value) / mx)))
                        }
                    }
                    Text(f.string(from: d.date)).font(.system(size: 9)).foregroundStyle(label.opacity(0.6))
                }
            }
        }
    }
}

struct WeekView: View {
    let e: IstEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let th = Theme(e.state, scheme)
        let week = IstStore.lastDays(e.state, count: 7).map(\.value).reduce(0, +)
        VStack(alignment: .trailing, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("اليوم").font(.system(size: 11)).foregroundStyle(th.text.opacity(0.7))
                    Text(num(e.today)).font(.system(size: 36, weight: .bold)).foregroundStyle(th.bead)
                    Text("الأسبوع \(num(week))").font(.system(size: 11)).foregroundStyle(th.text.opacity(0.7))
                }
                Spacer()
                if family == .systemLarge {
                    PlusButton(fg: Color(hex: th.c.bg2), bg: th.bead)
                }
            }
            WeekBars(state: e.state, color: th.bead, label: th.text)
            if family == .systemLarge {
                HStack {
                    Text("المجموع \(num(e.state.total))").font(.system(size: 12)).foregroundStyle(th.text.opacity(0.75))
                    Spacer()
                    Text("سلسلة الهدف \(num(IstStore.streak(e.state)))").font(.system(size: 12)).foregroundStyle(th.text.opacity(0.75))
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(for: .widget) { th.bg }
    }
}

// MARK: - Lock Screen live activity (+ Dynamic Island where available)
struct WirdLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WirdActivityAttributes.self) { ctx in
            let c = ctx.attributes.palette.dark
            let p = min(1, Double(ctx.state.today) / Double(max(1, ctx.state.goal)))
            HStack(spacing: 14) {
                ZStack {
                    Ring(progress: p, color: Color(hex: c.bead), width: 6)
                    Text(num(ctx.state.today)).font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: c.bead))
                }.frame(width: 64, height: 64)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(ctx.attributes.formText).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(hex: c.tx)).lineLimit(1)
                    Text("الهدف \(num(ctx.state.goal)) · هذه الجلسة \(num(ctx.state.session))").font(.system(size: 12)).foregroundStyle(Color(hex: c.tx).opacity(0.7))
                }.frame(maxWidth: .infinity, alignment: .trailing)
                Button(intent: LiveAddIstighfarIntent()) {
                    Text("+١").font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: c.bg2))
                        .frame(width: 58, height: 58).background(Circle().fill(Color(hex: c.bead)))
                }.buttonStyle(.plain)
            }
            .padding(16)
            .environment(\.layoutDirection, .rightToLeft)
            .activityBackgroundTint(Color(hex: c.bg2))
            .activitySystemActionForegroundColor(Color(hex: c.bead))
        } dynamicIsland: { ctx in
            let c = ctx.attributes.palette.dark
            let p = min(1, Double(ctx.state.today) / Double(max(1, ctx.state.goal)))
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(num(ctx.state.today)).font(.system(size: 26, weight: .bold)).foregroundStyle(Color(hex: c.bead))
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
                Image(systemName: "sparkles").foregroundStyle(Color(hex: c.bead))
            } compactTrailing: {
                Text(num(ctx.state.today)).font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: c.bead))
            } minimal: {
                Text(num(ctx.state.today)).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: c.bead))
            }
        }
    }
}
