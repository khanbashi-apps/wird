import UIKit
import AVKit
import AVFoundation
import CoreMedia

/// Floating counter window above other apps (Picture in Picture).
/// The window shows today's count; its play/pause button adds one istighfar.
final class PiPCounter: NSObject, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    private let host = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: 4))
    private let displayLayer = AVSampleBufferDisplayLayer()
    private var controller: AVPictureInPictureController?
    private var possibleObs: NSKeyValueObservation?
    private var refreshTimer: Timer?
    private var wantStart = false
    private var state = IstState()
    private let size = CGSize(width: 640, height: 360)

    var onAdd: (() -> Void)?
    var onStateChange: ((Bool) -> Void)?

    var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }
    var isActive: Bool { controller?.isPictureInPictureActive ?? false }

    func attach(to view: UIView) {
        guard isSupported else { return }
        host.alpha = 0.011
        host.isUserInteractionEnabled = false
        view.addSubview(host)
        displayLayer.frame = host.bounds
        displayLayer.videoGravity = .resizeAspect
        host.layer.addSublayer(displayLayer)
        var tb: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &tb)
        if let tb {
            CMTimebaseSetTime(tb, time: .zero)
            CMTimebaseSetRate(tb, rate: 1)
            displayLayer.controlTimebase = tb
        }
        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: displayLayer, playbackDelegate: self)
        let c = AVPictureInPictureController(contentSource: source)
        c.delegate = self
        c.requiresLinearPlayback = true
        c.canStartPictureInPictureAutomaticallyFromInline = false
        controller = c
        possibleObs = c.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] c, _ in
            guard let self, self.wantStart, c.isPictureInPicturePossible else { return }
            self.wantStart = false
            DispatchQueue.main.async { c.startPictureInPicture() }
        }
        render()
    }

    func start(state: IstState) {
        guard let controller else { return }
        self.state = state
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        render()
        if controller.isPictureInPicturePossible { controller.startPictureInPicture() } else { wantStart = true }
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.render() }
    }

    func stop() {
        wantStart = false
        controller?.stopPictureInPicture()
    }

    func update(state: IstState) {
        self.state = state
        render()
    }

    // MARK: drawing the window
    private func render() {
        guard isSupported, let buffer = makeSampleBuffer() else { return }
        if displayLayer.status == .failed { displayLayer.flush() }
        displayLayer.enqueue(buffer)
    }

    private func image() -> UIImage {
        let c = state.palette.dark
        let today = IstStore.today(state)
        let goal = max(1, state.goal)
        let r = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; f.opaque = true; return f }())
        return r.image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(hex: c.bg1).cgColor, UIColor(hex: c.bg2).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(g, start: CGPoint(x: size.width, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
            }
            let para = NSMutableParagraphStyle(); para.alignment = .center; para.baseWritingDirection = .rightToLeft
            let gold = UIColor(hex: c.bead), cream = UIColor(hex: c.tx)
            let num = ArabicNum.str(today) as NSString
            num.draw(in: CGRect(x: 0, y: 70, width: size.width, height: 150),
                     withAttributes: [.font: UIFont.systemFont(ofSize: 132, weight: .bold), .foregroundColor: gold, .paragraphStyle: para])
            (state.formShort as NSString).draw(in: CGRect(x: 20, y: 22, width: size.width - 40, height: 50),
                     withAttributes: [.font: UIFont.systemFont(ofSize: 34, weight: .semibold), .foregroundColor: cream, .paragraphStyle: para])
            let barW: CGFloat = 440, barX = (size.width - barW) / 2, barY: CGFloat = 258
            cg.setFillColor(cream.withAlphaComponent(0.18).cgColor)
            cg.addPath(UIBezierPath(roundedRect: CGRect(x: barX, y: barY, width: barW, height: 14), cornerRadius: 7).cgPath); cg.fillPath()
            let p = min(1, CGFloat(today) / CGFloat(goal))
            cg.setFillColor(gold.cgColor)
            cg.addPath(UIBezierPath(roundedRect: CGRect(x: barX + barW * (1 - p), y: barY, width: max(14, barW * p), height: 14), cornerRadius: 7).cgPath); cg.fillPath()
            ("اضغط زر التشغيل للعدّ · الهدف \(ArabicNum.str(goal))" as NSString).draw(in: CGRect(x: 20, y: 292, width: size.width - 40, height: 44),
                     withAttributes: [.font: UIFont.systemFont(ofSize: 26), .foregroundColor: cream.withAlphaComponent(0.75), .paragraphStyle: para])
        }
    }

    private func makeSampleBuffer() -> CMSampleBuffer? {
        guard let cgImage = image().cgImage else { return nil }
        var pb: CVPixelBuffer?
        let attrs: [CFString: Any] = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary]
        guard CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb) == kCVReturnSuccess, let pixel = pb else { return nil }
        CVPixelBufferLockBaseAddress(pixel, [])
        if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                               bytesPerRow: CVPixelBufferGetBytesPerRow(pixel), space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
            ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }
        CVPixelBufferUnlockBaseAddress(pixel, [])
        var fmt: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixel, formatDescriptionOut: &fmt)
        guard let fmt else { return nil }
        let now = displayLayer.controlTimebase.map { CMTimebaseGetTime($0) } ?? CMClockGetTime(CMClockGetHostTimeClock())
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 1), presentationTimeStamp: now, decodeTimeStamp: .invalid)
        var sb: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixel, formatDescription: fmt, sampleTiming: &timing, sampleBufferOut: &sb)
        if let sb, let arr = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true), CFArrayGetCount(arr) > 0 {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(arr, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(), Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return sb
    }

    // MARK: playback delegate — the play/pause button counts
    func pictureInPictureController(_ c: AVPictureInPictureController, setPlaying playing: Bool) {
        DispatchQueue.main.async {
            self.onAdd?()
            c.invalidatePlaybackState()
        }
    }
    func pictureInPictureControllerTimeRangeForPlayback(_ c: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    func pictureInPictureControllerIsPlaybackPaused(_ c: AVPictureInPictureController) -> Bool { false }
    func pictureInPictureController(_ c: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    func pictureInPictureController(_ c: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    // MARK: PiP delegate
    func pictureInPictureControllerDidStartPictureInPicture(_ c: AVPictureInPictureController) { onStateChange?(true) }
    func pictureInPictureControllerDidStopPictureInPicture(_ c: AVPictureInPictureController) {
        refreshTimer?.invalidate(); refreshTimer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        onStateChange?(false)
    }
    func pictureInPictureController(_ c: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        onStateChange?(false)
    }
}

extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        if h.count == 6 {
            self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        } else { self.init(white: 0.5, alpha: 1) }
    }
}
