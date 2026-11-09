import AppIntents
import WidgetKit
import ActivityKit

/// «استغفر» — adds to the counter without opening the app.
/// Used by widget buttons, the Shortcuts app, AssistiveTouch and Back Tap.
struct AddIstighfarIntent: AppIntent {
    static var title: LocalizedStringResource = "استغفر"
    static var description = IntentDescription("يضيف استغفاراً إلى عدّاد وِرد بدون فتح التطبيق.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "العدد", default: 1)
    var count: Int

    init() {}
    init(count: Int) { self.count = count }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let s = IstStore.add(max(1, min(count, 10_000)))
        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: IstStore.today(s))
    }
}

/// Button on the Lock Screen live activity. Runs in the app's process so it can update the activity.
struct LiveAddIstighfarIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "استغفار من شاشة القفل"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        let s = IstStore.add(1)
        let today = IstStore.today(s)
        for activity in Activity<WirdActivityAttributes>.activities {
            let st = WirdActivityAttributes.ContentState(today: today, goal: s.goal, session: activity.content.state.session + 1)
            await activity.update(ActivityContent(state: st, staleDate: nil))
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct WirdActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var today: Int
        var goal: Int
        var session: Int
    }
    var formShort: String
    var formText: String
    var palette: WirdPalette
}
