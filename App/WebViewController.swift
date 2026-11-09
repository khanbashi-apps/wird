import UIKit
import WebKit
import WidgetKit
import UniformTypeIdentifiers

/// Hosts the approved interface (bundled offline in Web/) and connects it to iOS.
final class WebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, UIDocumentPickerDelegate {
    static let shared = WebViewController()

    private var webView: WKWebView!
    private var ready = false
    private var pendingRoute: String?
    private var darkUI = false
    private var widgetReloadWork: DispatchWorkItem?
    let pip = PiPCounter()

    override var preferredStatusBarStyle: UIStatusBarStyle { darkUI ? .lightContent : .darkContent }

    override func loadView() {
        let cfg = WKWebViewConfiguration()
        cfg.setURLSchemeHandler(WebSchemeHandler(), forURLScheme: WebSchemeHandler.scheme)
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.dataDetectorTypes = []
        cfg.websiteDataStore = .default()
        let ucc = WKUserContentController()
        let boot = """
        window.__WIRD_NATIVE__ = true;
        window.addEventListener('error', function(e){ try{ window.webkit.messageHandlers.wird.postMessage({t:'jserr', m:(e.message||'')+' @'+String(e.filename||'').split('/').pop()+':'+(e.lineno||0)}) }catch(_){} });
        navigator.vibrate = function(p){ try{ window.webkit.messageHandlers.wird.postMessage({t:'haptic', p:p}) }catch(e){} return true };
        """
        ucc.addUserScript(WKUserScript(source: boot, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.add(WeakHandler(self), name: "wird")
        cfg.userContentController = ucc

        webView = WKWebView(frame: .zero, configuration: cfg)
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(named: "LaunchBG") ?? .systemBackground
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 1
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        pip.attach(to: view)
        pip.onAdd = { [weak self] in self?.addFromOutside(1) }
        pip.onStateChange = { [weak self] _ in self?.sendEnv() }
        if let r = ProcessInfo.processInfo.environment["WIRD_ROUTE"], !r.isEmpty { pendingRoute = r }
        webView.load(URLRequest(url: URL(string: "\(WebSchemeHandler.scheme)://app/index.html")!))
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(foreground), name: UIApplication.willEnterForegroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        LocationService.shared.onUpdate = { [weak self] in
            self?.sendTimes()
            Reminders.reschedule()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
    }

    // MARK: lifecycle
    @objc private func foreground() {
        syncIst()
        sendTimes()
        Reminders.reschedule()
        LiveCounter.shared.refresh()
        sendEnv()
    }
    @objc private func background() {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func open(route: String) {
        if ready { js("wirdNative.go(\(jsonString(route)))") } else { pendingRoute = route }
    }

    // MARK: JS helpers
    private func js(_ code: String) {
        guard let webView else { return }
        webView.evaluateJavaScript("try{ \(code) }catch(e){}", completionHandler: nil)
    }
    private func jsonString(_ v: Any) -> String {
        if let s = v as? String, let d = try? JSONSerialization.data(withJSONObject: [s]), let str = String(data: d, encoding: .utf8) {
            return String(str.dropFirst().dropLast())
        }
        guard JSONSerialization.isValidJSONObject(v), let d = try? JSONSerialization.data(withJSONObject: v), let s = String(data: d, encoding: .utf8) else { return "null" }
        return s
    }

    private func syncIst() {
        let s = IstStore.load()
        js("wirdNative.istSync(\(jsonString(["days": s.days, "total": s.total])))")
        pip.update(state: s)
    }

    private func sendTimes() {
        guard let t = PrayerTimes.today() else { return }
        js("wirdNative.setTimes(\(jsonString(t.asHours())))")
        sendEnv()
    }

    private func sendEnv() {
        let env: [String: Any] = [
            "group": WirdShared.groupAvailable,
            "live": LiveCounter.shared.enabled,
            "liveOn": LiveCounter.shared.isRunning,
            "pip": pip.isSupported,
            "pipOn": pip.isActive,
            "place": LocationService.shared.placeName,
            "locNote": LocationService.shared.note,
            "notif": Reminders.status
        ]
        js("wirdNative.setEnv(\(jsonString(env)))")
    }

    private func reloadWidgetsSoon() {
        widgetReloadWork?.cancel()
        let w = DispatchWorkItem { WidgetCenter.shared.reloadAllTimelines() }
        widgetReloadWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: w)
    }

    private func addFromOutside(_ n: Int) {
        let s = IstStore.add(n)
        reloadWidgetsSoon()
        LiveCounter.shared.update(state: s, addSession: n)
        pip.update(state: s)
        syncIst()
        Haptics.play(12)
    }

    // MARK: navigation
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.scheme == "http" || url.scheme == "https" {
            UIApplication.shared.open(url)
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false
        webView.reload()
    }

    // MARK: messages from the page
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let t = body["t"] as? String else { return }
        switch t {
        case "ready":
            ready = true
            syncIst(); sendTimes(); sendEnv()
            LocationService.shared.start()
            Reminders.requestIfNeeded()
            if let r = pendingRoute { pendingRoute = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.open(route: r) } }
        case "jserr":
            logJSError(body["m"] as? String ?? "")
        case "haptic":
            Haptics.play(body["p"] ?? 10)
        case "ist.add":
            let n = (body["n"] as? Int) ?? 1
            let s = IstStore.add(n)
            reloadWidgetsSoon()
            LiveCounter.shared.update(state: s, addSession: n)
            pip.update(state: s)
        case "ist.replace":
            let days = (body["days"] as? [String: Any] ?? [:]).compactMapValues { ($0 as? NSNumber)?.intValue }
            let total = (body["total"] as? NSNumber)?.intValue ?? days.values.reduce(0, +)
            IstStore.update { $0.days = days; $0.total = total }
            reloadWidgetsSoon()
        case "ist.meta":
            IstStore.update { s in
                if let g = body["goal"] as? Int, g > 0 { s.goal = g }
                if let f = body["formShort"] as? String { s.formShort = f }
                if let f = body["formText"] as? String { s.formText = f }
                if let p = body["palette"], let d = try? JSONSerialization.data(withJSONObject: p),
                   let pal = try? JSONDecoder().decode(WirdPalette.self, from: d) { s.palette = pal }
            }
            reloadWidgetsSoon()
            LiveCounter.shared.update(state: IstStore.load(), addSession: 0)
            pip.update(state: IstStore.load())
        case "settings":
            if let rem = body["rem"] as? [String: Any] {
                Reminders.saveFlags(rem.compactMapValues { $0 as? Bool })
                Reminders.reschedule()
            }
        case "kahf.done":
            Reminders.cancelFridayKahf()
        case "theme":
            darkUI = (body["dark"] as? Bool) ?? false
            setNeedsStatusBarAppearanceUpdate()
            view.window?.overrideUserInterfaceStyle = darkUI ? .dark : .light
        case "wake":
            UIApplication.shared.isIdleTimerDisabled = (body["on"] as? Bool) ?? false
        case "copy":
            UIPasteboard.general.string = body["text"] as? String
            js("wirdNative.toast('نُسخت الآية')")
        case "share":
            share(items: [body["text"] as? String ?? ""])
        case "backup.export":
            exportBackup(json: body["json"] as? String ?? "{}")
        case "backup.import":
            importBackup()
        case "loc.refresh":
            LocationService.shared.start(force: true)
        case "pip.start":
            pip.start(state: IstStore.load())
        case "pip.stop":
            pip.stop()
        case "live.start":
            LiveCounter.shared.start(state: IstStore.load()) { [weak self] ok, msg in
                self?.sendEnv()
                if let msg { self?.js("wirdNative.toast(\(self?.jsonString(msg) ?? "''"))") }
                _ = ok
            }
        case "live.stop":
            LiveCounter.shared.stop { [weak self] in self?.sendEnv() }
        default: break
        }
    }

    private func logJSError(_ m: String) {
        NSLog("[wird js] %@", m)
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let f = dir.appendingPathComponent("js-errors.log")
        let line = (m + "\n").data(using: .utf8) ?? Data()
        if let h = try? FileHandle(forWritingTo: f) { h.seekToEndOfFile(); h.write(line); try? h.close() }
        else { try? line.write(to: f) }
    }

    // MARK: share / backup
    private func share(items: [Any], sourceFile: URL? = nil) {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = view
        vc.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 40, width: 1, height: 1)
        present(vc, animated: true)
    }

    private func exportBackup(json: String) {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wird-backup-\(f.string(from: Date())).json")
        do {
            try json.data(using: .utf8)?.write(to: url, options: .atomic)
            share(items: [url])
        } catch {
            js("wirdNative.toast('تعذّر حفظ النسخة')")
        }
    }

    private func importBackup() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .plainText, .data], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            js("wirdNative.toast('تعذّرت قراءة الملف')"); return
        }
        js("wirdNative.restore(\(jsonString(text)))")
    }
}

/// Avoids a retain cycle between WKUserContentController and the controller.
final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(ucc, didReceive: message)
    }
}

/// Serves the bundled interface from Web/ under wird://app/ so storage and fonts behave like a normal site.
final class WebSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "wird"
    private let root = Bundle.main.resourceURL!.appendingPathComponent("Web", isDirectory: true)

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { task.didFailWithError(URLError(.badURL)); return }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let file = root.appendingPathComponent(String(path.dropFirst()))
        guard file.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path),
              let data = try? Data(contentsOf: file) else {
            let r = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: [:])!
            task.didReceive(r); task.didReceive(Data()); task.didFinish(); return
        }
        let mime: String
        switch file.pathExtension.lowercased() {
        case "html": mime = "text/html; charset=utf-8"
        case "js": mime = "text/javascript; charset=utf-8"
        case "css": mime = "text/css; charset=utf-8"
        case "json": mime = "application/json"
        case "woff2": mime = "font/woff2"
        case "woff": mime = "font/woff"
        case "ttf": mime = "font/ttf"
        case "png": mime = "image/png"
        case "svg": mime = "image/svg+xml"
        default: mime = "application/octet-stream"
        }
        let headers = ["Content-Type": mime, "Content-Length": "\(data.count)", "Access-Control-Allow-Origin": "*", "Cache-Control": "no-cache"]
        let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        task.didReceive(resp)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
