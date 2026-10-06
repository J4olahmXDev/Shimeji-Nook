import Cocoa

final class CompanionPanel: NSPanel {
    var onMouseDown: (() -> Void)?
    var onMouseDragged: (() -> Void)?
    var onMouseUp: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = false
        animationBehavior = .none
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown: onMouseDown?()
        case .leftMouseDragged: onMouseDragged?()
        case .leftMouseUp: onMouseUp?()
        case .rightMouseDown: onRightClick?(event)
        default: super.sendEvent(event)
        }
    }
}

struct SpriteFrame {
    let image: NSImage
    let bitmap: NSBitmapImageRep
    let bottomPadding: CGFloat
}

/// A manifest of folder names is the only asset-specific contract. Rendering and physics use points.
final class SpriteLibrary {
    let folders = ["idle": "01_idle", "walk": "02_walk", "run": "03_run", "jump": "04_jump",
                   "fall": "05_fall", "sit": "06_sit", "sleep": "08_sleep", "drag": "18_interactions",
                   "climb": "09_climb_hang", "wave": "10_wave", "happy": "14_happy", "talk": "19_talk"]
    private(set) var animations: [String: [SpriteFrame]] = [:]
    // Version 2 walk/run sprites face LEFT before any transform.
    // Define the native direction of each replacement animation here.
    private struct Manifest: Decodable {
        struct Animation: Decodable {
            let fps: Double
            let loop: Bool?
            let playbackOrder: [Int]?
            let renderScale: Double?
            let horizontalPivot: Double?
        }
        let canvas: [Double]
        let pivot: [Double]
        let nativeFacing: [String: Double]
        let animations: [String: Animation]
    }
    private var manifest: Manifest?
    private var bottomPadding: CGFloat = 0
    private var nativeFacing: [String: CGFloat] = ["walk": -1, "run": -1]
    func frameDuration(for state: String) -> Double {
        let fps = manifest?.animations[folders[state] ?? ""]?.fps
            ?? manifest?.animations[folders["idle"] ?? ""]?.fps ?? 8
        return 1 / max(1, fps)
    }
    func renderScale(for state: String) -> CGFloat {
        CGFloat(manifest?.animations[folders[state] ?? ""]?.renderScale ?? 1)
    }
    func horizontalPivot(for state: String) -> CGFloat {
        CGFloat(manifest?.animations[folders[state] ?? ""]?.horizontalPivot ?? 0.5)
    }
    func shouldMirror(state: String, movementDirection: CGFloat) -> Bool {
        guard let native = nativeFacing[state] else { return false }
        return native * movementDirection < 0
    }
    struct Model {
        let id: String
        let displayName: String
        let assetsURL: URL
        let quotes: [String]
    }
    private struct ModelMetadata: Decodable {
        struct Speech: Decodable { let quotes: [String] }
        let id: String
        let displayName: String
        let assetsDirectory: String
        let speech: Speech
    }
    private(set) var models: [Model] = []
    private(set) var selectedModelID = "thungngern"
    private(set) var modelName = "ถุงเงิน"
    private(set) var quotes: [String] = []
    private static let originalQuotes = [
        "ถุงอยู่กับซัวว์นะ 💙", "ถุงเป็นกำลังใจให้นะ",
        "ค่อย ๆ ทำทีละนิดก็ได้นะ ถุงรอได้",
        "พักหายใจสักนิดนะ แล้วเราค่อยไปต่อด้วยกัน",
        "วันนี้ซัวว์ทำได้ดีแล้วนะ", "เหนื่อยก็พักได้ ถุงอยู่ตรงนี้เสมอ",
        "ไม่ต้องเก่งทุกวันก็ได้ แค่พยายามก็พอแล้ว",
        "ดื่มน้ำสักหน่อยไหม ถุงเป็นห่วงนะ"
    ]
    func isLooping(state: String) -> Bool {
        manifest?.animations[folders[state] ?? ""]?.loop ?? true
    }
    init() {
        guard let assets = Bundle.main.resourceURL?.appendingPathComponent("Assets") else { return }
        models = [Model(id: "thungngern", displayName: "ถุงเงิน", assetsURL: assets, quotes: Self.originalQuotes)]
        let packs = assets.appendingPathComponent("Models")
        let directories = (try? FileManager.default.contentsOfDirectory(at: packs, includingPropertiesForKeys: nil)) ?? []
        for directory in directories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let data = try? Data(contentsOf: directory.appendingPathComponent("model.json")),
                  let metadata = try? JSONDecoder().decode(ModelMetadata.self, from: data),
                  !metadata.id.isEmpty, !metadata.speech.quotes.isEmpty,
                  !models.contains(where: { $0.id == metadata.id }) else { continue }
            models.append(Model(id: metadata.id, displayName: metadata.displayName,
                                assetsURL: directory.appendingPathComponent(metadata.assetsDirectory),
                                quotes: metadata.speech.quotes))
        }
        let selected = UserDefaults.standard.string(forKey: "SelectedModelID") ?? "thungngern"
        if !loadModel(id: selected) { _ = loadModel(id: "thungngern") }
    }
    @discardableResult func loadModel(id: String) -> Bool {
        guard let model = models.first(where: { $0.id == id }) else { return false }
        let newManifest = (try? Data(contentsOf: model.assetsURL.appendingPathComponent("manifest.json")))
            .flatMap { try? JSONDecoder().decode(Manifest.self, from: $0) }
        var padding: CGFloat = 0
        if let decoded = newManifest, decoded.canvas.count == 2, decoded.pivot.count == 2, decoded.canvas[1] > 0 {
            padding = CGFloat((decoded.canvas[1] - decoded.pivot[1]) / decoded.canvas[1])
        }
        var loaded: [String: [SpriteFrame]] = [:]
        for (state, folder) in folders {
            let directory = model.assetsURL.appendingPathComponent(folder)
            let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            loaded[state] = urls.filter { $0.pathExtension.lowercased() == "png" }.sorted { $0.path < $1.path }
                .compactMap { Self.load($0, bottomPadding: padding) }
        }
        for (state, folder) in folders {
            if let order = newManifest?.animations[folder]?.playbackOrder,
               let frames = loaded[state], !order.isEmpty,
               order.allSatisfy({ frames.indices.contains($0) }) {
                loaded[state] = order.map { frames[$0] }
            }
        }
        guard let idle = loaded["idle"], !idle.isEmpty else {
            NSLog("[ThungNgern] model %@ rejected: no idle images", id); return false
        }
        for state in folders.keys where loaded[state]?.isEmpty != false { loaded[state] = idle }
        manifest = newManifest
        bottomPadding = padding
        nativeFacing = newManifest?.nativeFacing.mapValues { CGFloat($0) } ?? ["walk": -1, "run": -1, "climb": -1]
        animations = loaded
        selectedModelID = model.id
        modelName = model.displayName
        quotes = model.quotes
        NSLog("[ThungNgern] selected model %@; %d animation states", model.id, loaded.count)
        return true
    }
    static func load(_ url: URL, bottomPadding: CGFloat) -> SpriteFrame? {
        guard let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        // Version 2 artwork has real alpha and a fixed canvas. Never remove pale
        // colors or trim each pose independently: that damages details and changes scale.
        return SpriteFrame(image: NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)),
                           bitmap: NSBitmapImageRep(cgImage: cg), bottomPadding: bottomPadding)
    }

}

final class SpriteView: NSView {
    var renderScale: CGFloat = 1 { didSet { needsDisplay = true } }
    var horizontalPivot: CGFloat = 0.5 { didSet { needsDisplay = true } }
    var sprite: SpriteFrame? { didSet { needsDisplay = true } }
    var mirrored = false { didSet { needsDisplay = true } }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    var spriteRect: NSRect {
        guard let sprite else { return .zero }
        let size = sprite.image.size
        let scale = min(bounds.width / size.width, bounds.height / size.height) * renderScale
        return NSRect(x: bounds.midX - size.width * scale * horizontalPivot, y: -size.height*scale*sprite.bottomPadding, width: size.width*scale, height: size.height*scale)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        guard let sprite else { NSGraphicsContext.restoreGraphicsState(); return }
        if mirrored {
            let transform = AffineTransform(translationByX: bounds.width, byY: 0)
            var t = transform; t.scale(x: -1, y: 1); (t as NSAffineTransform).concat()
        }
        sprite.image.draw(in: spriteRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }
    func containsOpaquePixel(_ point: NSPoint) -> Bool {
        guard let sprite else { return false }
        var p = point
        if mirrored { p.x = bounds.width-p.x }
        let rect = spriteRect
        guard rect.contains(p) else { return false }
        let x = min(sprite.bitmap.pixelsWide-1, Int((p.x-rect.minX)/rect.width*CGFloat(sprite.bitmap.pixelsWide)))
        let y = min(sprite.bitmap.pixelsHigh-1, Int((1-(p.y-rect.minY)/rect.height)*CGFloat(sprite.bitmap.pixelsHigh)))
        return (sprite.bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.12
    }
}

/// A separate nonactivating, click-through bubble follows the pet in global points.
final class SpeechBubblePanel: NSPanel {
    private let bubble = SpeechBubbleView(frame: NSRect(x: 0, y: 0, width: 250, height: 96))
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 250, height: 96), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        contentView = bubble
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    func show(_ text: String) {
        bubble.configure(text)
        bubble.tailX = bubble.bounds.midX
        setContentSize(bubble.frame.size)
        orderFrontRegardless()
        #if DEBUG
        // Render this app's own view for visual regression inspection, without
        // capturing the desktop or any other application's content.
        bubble.displayIfNeeded()
        if let bitmap = bubble.bitmapImageRepForCachingDisplay(in: bubble.bounds) {
            bubble.cacheDisplay(in: bubble.bounds, to: bitmap)
            if let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "/tmp/ThungNgern-speech.png"), options: .atomic)
            }
        }
        #endif
    }
    func follow(_ pet: NSRect, on screen: NSRect) {
        let above = pet.maxY + 4 + frame.height <= screen.maxY
        bubble.pointsDown = above
        let x = min(max(pet.midX - frame.width / 2, screen.minX + 6), screen.maxX - frame.width - 6)
        let proposedY = above ? pet.maxY + 4 : pet.minY - frame.height - 4
        let y = min(max(proposedY, screen.minY + 6), screen.maxY - frame.height - 6)
        bubble.tailX = min(max(pet.midX - x, 22), frame.width - 22)
        setFrameOrigin(NSPoint(x: x, y: y))
    }
    #if DEBUG
    func validateQuotes(_ quotes: [String]) {
        let directory = URL(fileURLWithPath: "/tmp/ThungNgern-quote-validation", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var results: [[String: Any]] = []
        for (index, text) in quotes.enumerated() {
            bubble.configure(text)
            setContentSize(bubble.frame.size)
            bubble.tailX = bubble.bounds.midX
            let fits = bubble.allTextFits
            assert(fits, "Speech bubble clips quote: \(text)")
            if let bitmap = bubble.bitmapImageRepForCachingDisplay(in: bubble.bounds) {
                bubble.cacheDisplay(in: bubble.bounds, to: bitmap)
                if let png = bitmap.representation(using: .png, properties: [:]) {
                    try? png.write(to: directory.appendingPathComponent(String(format: "quote_%02d.png", index + 1)))
                }
            }
            results.append(["text": text, "width": frame.width, "height": frame.height, "allTextFits": fits])
        }
        if let data = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted]) {
            try? data.write(to: directory.appendingPathComponent("validation.json"))
        }
    }
    #endif
}

private final class SpeechBubbleView: NSView {
    private let textView = NSTextView(frame: .zero)
    var pointsDown = true { didSet { needsDisplay = true; layoutLabel() } }
    var tailX: CGFloat = 125 { didSet { needsDisplay = true } }
    override var isOpaque: Bool { false }
    override init(frame: NSRect) {
        super.init(frame: frame)
        textView.font = .systemFont(ofSize: 14, weight: .medium)
        textView.textColor = NSColor(calibratedRed: 0.23, green: 0.18, blue: 0.24, alpha: 1)
        textView.alignment = .center
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        addSubview(textView)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        layoutLabel()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    var allTextFits: Bool {
        guard let container = textView.textContainer, let layout = textView.layoutManager else { return false }
        layout.ensureLayout(for: container)
        return layout.usedRect(for: container).maxY <= textView.bounds.height
            && layout.glyphRange(for: container).length == layout.numberOfGlyphs
    }
    func configure(_ text: String) {
        textView.string = text
        guard let container = textView.textContainer, let layout = textView.layoutManager else { return }
        // TextKit lays out the actual Thai fallback glyphs and wrapping. Use this
        // same container for measuring and drawing, so no last line is truncated.
        container.containerSize = NSSize(width: 190, height: CGFloat.greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        let initial = layout.usedRect(for: container)
        let textWidth = min(190, max(60, ceil(initial.width) + 2))
        container.containerSize = NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        let actual = layout.usedRect(for: container)
        setFrameSize(NSSize(width: textWidth + 24, height: ceil(actual.height) + 32))
        setAccessibilityLabel(text)
        layoutLabel()
        needsDisplay = true
    }
    private func layoutLabel() {
        textView.frame = NSRect(x: 12, y: pointsDown ? 17 : 7, width: bounds.width - 24, height: bounds.height - 24)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); bounds.fill(using: .copy)
        let body = NSRect(x: 1, y: pointsDown ? 11 : 1, width: bounds.width - 2, height: bounds.height - 12)
        let fill = NSColor(calibratedRed: 1, green: 0.96, blue: 0.92, alpha: 0.98)
        let outline = NSColor(calibratedRed: 0.73, green: 0.53, blue: 0.57, alpha: 1)
        let rounded = NSBezierPath(roundedRect: body, xRadius: 12, yRadius: 12)
        fill.setFill(); rounded.fill(); outline.setStroke(); rounded.lineWidth = 1; rounded.stroke()
        let tail = NSBezierPath()
        let edge = pointsDown ? body.minY : body.maxY
        tail.move(to: NSPoint(x: tailX - 9, y: edge))
        tail.line(to: NSPoint(x: tailX, y: pointsDown ? 1 : bounds.maxY - 1))
        tail.line(to: NSPoint(x: tailX + 9, y: edge))
        tail.close(); fill.setFill(); tail.fill()
        outline.setStroke(); tail.lineWidth = 1; tail.stroke()
        fill.setStroke()
        let seam = NSBezierPath(); seam.move(to: NSPoint(x: tailX - 8, y: edge)); seam.line(to: NSPoint(x: tailX + 8, y: edge))
        seam.lineWidth = 2; seam.stroke()
    }
}
