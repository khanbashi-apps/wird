import Foundation
import ActivityKit

/// Lock Screen counter (Live Activity). On iPhones with the Dynamic Island it shows there too.
final class LiveCounter {
    static let shared = LiveCounter()

    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    var isRunning: Bool { !Activity<WirdActivityAttributes>.activities.isEmpty }

    func start(state: IstState, done: @escaping (Bool, String?) -> Void) {
        guard enabled else { done(false, "فعّل «الأنشطة الحية» لوِرد من الإعدادات"); return }
        if isRunning { refresh(); done(true, nil); return }
        let attrs = WirdActivityAttributes(formShort: state.formShort, formText: state.formText, palette: state.palette)
        let content = ActivityContent(state: WirdActivityAttributes.ContentState(today: IstStore.today(state), goal: state.goal, session: 0), staleDate: nil)
        do {
            _ = try Activity.request(attributes: attrs, content: content, pushType: nil)
            DispatchQueue.main.async { done(true, "العدّاد يظهر الآن على شاشة القفل") }
        } catch {
            DispatchQueue.main.async { done(false, "تعذّر تشغيل العدّاد على شاشة القفل") }
        }
    }

    func update(state: IstState, addSession: Int) {
        let today = IstStore.today(state)
        Task {
            for a in Activity<WirdActivityAttributes>.activities {
                let st = WirdActivityAttributes.ContentState(today: today, goal: state.goal, session: a.content.state.session + addSession)
                await a.update(ActivityContent(state: st, staleDate: nil))
            }
        }
    }

    func refresh() { update(state: IstStore.load(), addSession: 0) }

    func stop(done: @escaping () -> Void) {
        Task {
            for a in Activity<WirdActivityAttributes>.activities {
                await a.end(nil, dismissalPolicy: .immediate)
            }
            await MainActor.run { done() }
        }
    }
}
