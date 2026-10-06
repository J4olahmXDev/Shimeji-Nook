import Cocoa

final class CompanionController: NSObject, NSMenuDelegate {
    private let size = NSSize(width: 160, height: 145 * 4 / 3)
    private lazy var panel = CompanionPanel(contentRect: NSRect(origin: .zero, size: size))
    private lazy var view = SpriteView(frame: NSRect(origin: .zero, size: size))
    private let library = SpriteLibrary()
    private var timer: Timer?
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var animationTime = 0.0
    private var trackingTime = 0.0
    private var decisionTime = 0.0
    private var state = "idle"
    private var frameIndex = 0
    private var direction: CGFloat = 1
    private var velocityY: CGFloat = 0
    // AppKit may snap panel origins to pixels. Preserve fractional physics positions
    // between ticks so small positive steps cannot be rounded away every frame.
    private var position = NSPoint.zero
    private var wandering = true
    private var paused = false
    private var sleeping = false
    private var grounded = false
    private var running = false
    private var resting = false
    private var directedWalk = false
    private var journeyTime = 0.0
    private var gesture: String?
    private var gestureTime = 0.0
    private struct Climb {
        var window: TrackedWindow
        let side: CGFloat
        var hangTime = 0.0
    }
    private var climbing: Climb?
    private var dragStart: NSPoint?
    private var windowStart: NSPoint?
    private var support: TrackedWindow?
    private var windows: [TrackedWindow] = []
    private var menuOpen = false
    private let petMenu = PetContextMenu()
    private var diagnosticTime = 0.0
    private var diagnosticSamples: [[String: Any]] = []
    private lazy var speech = SpeechBubblePanel()
    private var speechUntil = 0.0
    private var currentQuote = ""
    private var quoteBag: [String] = []
    private var quotes: [String] { library.quotes }


    override init() {
        super.init()
        panel.contentView = view
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.image)
        view.setAccessibilityLabel("\(library.modelName) desktop companion")
        panel.onMouseDown = { [weak self] in self?.beginDrag() }
        panel.onMouseDragged = { [weak self] in self?.drag() }
        panel.onMouseUp = { [weak self] in self?.endDrag() }
        petMenu.onAccessibilityChange = { [weak self] children in
            guard let self else { return }
            self.view.setAccessibilityChildren(children)
            for child in children { child.setAccessibilityParent(self.view) }
            NSAccessibility.post(element: self.view, notification: .layoutChanged)
        }
        panel.onRightClick = { [weak self] event in
            guard let self else { return }
            self.petMenu.show(self.makeMenu(), at: self.panel.convertPoint(toScreen: event.locationInWindow)) { [weak self] in
                self?.menuOpen = false
            }
            self.menuOpen = true
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        setState("idle")
        #if DEBUG
        speech.validateQuotes(quotes)
        #endif
    }
    deinit { timer?.invalidate(); NotificationCenter.default.removeObserver(self) }

    func start() {
        home()
        timer = Timer(timeInterval: 1.0/60, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }
    private func setPosition(_ point: NSPoint) {
        position = point
        panel.setFrameOrigin(point)
        if speechUntil > 0, let screen = screen() { speech.follow(panel.frame, on: screen.visibleFrame) }
    }
    private func screen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(panel.frame.origin.applying(CGAffineTransform(translationX: size.width/2, y: size.height/2))) }
            ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first
    }
    private func setState(_ next: String) {
        if state != next { state = next; frameIndex = 0; animationTime = 0 }
        let frames = library.animations[state] ?? library.animations["idle"] ?? []
        view.renderScale = library.renderScale(for: state)
        view.horizontalPivot = library.horizontalPivot(for: state)
        if !frames.isEmpty {
            let index = library.isLooping(state: state) ? frameIndex % frames.count : min(frameIndex, frames.count - 1)
            view.sprite = frames[index]
        }
        view.mirrored = library.shouldMirror(state: state, movementDirection: direction)
    }
    @objc private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now-lastTime, 0.04)
        lastTime = now
        if speechUntil > 0 && now >= speechUntil {
            speech.orderOut(nil); speechUntil = 0
        }
        let mouse = NSEvent.mouseLocation
        let local = NSPoint(x: mouse.x-panel.frame.minX, y: mouse.y-panel.frame.minY)
        panel.ignoresMouseEvents = dragStart == nil && !menuOpen && !view.containsOpaquePixel(local)
        #if DEBUG
        diagnosticTime += dt
        if diagnosticTime >= 0.1 {
            diagnosticTime = 0
            diagnosticSamples.append(["pid": getpid(),
                "appInstanceCount": NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.suanaph.ThungNgern").count,
                "time": now, "x": panel.frame.minX, "y": panel.frame.minY,
                "modelID": library.selectedModelID, "panelWidth": panel.frame.width, "panelHeight": panel.frame.height,
                "spriteWidth": view.spriteRect.width, "spriteHeight": view.spriteRect.height,
                "state": state, "frameIndex": frameIndex, "quote": currentQuote, "speechVisible": speechUntil > 0,
                "directedWalk": directedWalk, "climbing": climbing != nil,
                "speechX": speech.frame.minX, "speechY": speech.frame.minY,
                "direction": direction, "mirrored": view.mirrored, "menuOpen": menuOpen, "physicsX": position.x, "paused": paused, "grounded": grounded, "support": support?.id ?? 0,
                "ignoresMouse": panel.ignoresMouseEvents, "visible": panel.isVisible,
                "focus": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "",
                "screenCount": NSScreen.screens.count, "scale": panel.backingScaleFactor])
            if diagnosticSamples.count > 600 { diagnosticSamples.removeFirst() }
            if let data = try? JSONSerialization.data(withJSONObject: diagnosticSamples) {
                try? data.write(to: URL(fileURLWithPath: "/tmp/ThungNgern-diagnostics.json"), options: .atomic)
            }
        }
        #endif
        trackingTime += dt
        if trackingTime >= 0.10 {
            trackingTime = 0
            windows = WindowTracker.visibleWindows()
            if var climb = climbing {
                if let updated = windows.first(where: { $0.id == climb.window.id }),
                   WindowTracker.sideVisible(updated, side: climb.side, at: position.y + size.height / 2, in: windows) {
                    let delta = NSPoint(x: updated.bounds.minX - climb.window.bounds.minX,
                                        y: updated.bounds.minY - climb.window.bounds.minY)
                    climb.window = updated; climbing = climb
                    setPosition(NSPoint(x: position.x + delta.x, y: position.y + delta.y))
                } else {
                    climbing = nil; grounded = false; velocityY = 0
                    NSLog("[ThungNgern] climbing window disappeared or side covered; falling")
                }
            }
            if let old = support {
                if let updated = windows.first(where: { $0.id == old.id }) {
                    let delta = CGPoint(x: updated.bounds.minX-old.bounds.minX, y: updated.bounds.maxY-old.bounds.maxY)
                    setPosition(NSPoint(x: position.x+delta.x, y: position.y+delta.y))
                    support = updated
                    if !NSScreen.screens.contains(where: { $0.visibleFrame.contains(CGPoint(x: panel.frame.midX, y: panel.frame.maxY)) }) {
                        support = nil; grounded = false; velocityY = 0
                        if let destination = screen() { setPosition(NSPoint(x: panel.frame.minX, y: destination.visibleFrame.maxY-size.height)) }
                    }
                } else { support = nil; grounded = false }
            }
        }
        guard !paused, !menuOpen else { return }
        animationTime += dt
        let frameDuration = library.frameDuration(for: state)
        while animationTime >= frameDuration {
            animationTime -= frameDuration
            frameIndex += 1
        }
        if dragStart != nil { setState("drag"); return }
        guard let screen = screen() else { return }
        if var climb = climbing {
            let ceiling = min(climb.window.bounds.maxY, screen.visibleFrame.maxY - size.height)
            var next = position
            next.x = WindowTracker.climbingX(climb.window, side: climb.side, petWidth: size.width, screen: screen.visibleFrame)
            next.y = min(ceiling, next.y + 32 * dt)
            if next.y >= ceiling { climb.hangTime += dt }
            climbing = climb
            setPosition(next)
            if climb.hangTime >= 1.2 && ceiling >= climb.window.bounds.maxY {
                let targetX = climb.side < 0 ? climb.window.bounds.minX + 12 - size.width / 2
                    : climb.window.bounds.maxX - 12 - size.width / 2
                attach(to: climb.window, x: min(max(targetX, screen.visibleFrame.minX), screen.visibleFrame.maxX - size.width), stay: true)
                direction = -climb.side; gesture = "happy"; gestureTime = 2.4
                setState("happy")
                NSLog("[ThungNgern] climb complete; perched on %@ window %u", climb.window.owner, climb.window.id)
            } else { setState("climb") }
            return
        }
        if gestureTime > 0 { gestureTime = max(0, gestureTime - dt) }
        var origin = position
        let floor = screen.visibleFrame.minY
        if let edge = support {
            let center = origin.x+size.width/2
            if center < edge.bounds.minX || center > edge.bounds.maxX || !WindowTracker.edgeVisible(edge, at: center, in: windows) {
                support = nil; grounded = false
            }
        } else if origin.y > floor+1 { grounded = false }
        else if grounded { origin.y = floor }
        decisionTime += dt
        if directedWalk {
            journeyTime += dt
            running = journeyTime.truncatingRemainder(dividingBy: 10) >= 7
        }
        if decisionTime > 5 && wandering && grounded && !sleeping && !directedWalk {
            decisionTime = 0
            running = Int.random(in: 0..<5) == 0
            resting = Int.random(in: 0..<4) == 0
            if Int.random(in: 0..<6) == 0 { gesture = ["wave", "happy", "idle"].randomElement(); gestureTime = 2.4 }
            if Int.random(in: 0..<4) == 0 { direction *= -1 }
        }
        if wandering && !sleeping && !resting && gestureTime == 0 && speechUntil == 0 {
            origin.x += direction * (running ? 70 : 24) * dt
            // Wander back along a perch rather than unintentionally walking off it.
            if let edge = support, grounded {
                let minX = edge.bounds.minX + 12 - size.width / 2
                let maxX = edge.bounds.maxX - 12 - size.width / 2
                if origin.x < minX || origin.x > maxX {
                    direction *= -1
                    origin.x = min(max(origin.x, minX), maxX)
                    finishDirectedWalk()
                }
            }
        }
        // A continuous display seam may be crossed; only reflect at the outside desktop boundary.
        let leading = CGPoint(x: origin.x+(direction > 0 ? size.width : 0), y: origin.y+size.height/2)
        if !NSScreen.screens.contains(where: { $0.frame.contains(leading) }) {
            direction *= -1
            origin.x = min(max(origin.x, screen.visibleFrame.minX), screen.visibleFrame.maxX-size.width)
            finishDirectedWalk()
        }
        if !grounded {
            let previousY = origin.y
            velocityY -= 1050*dt
            origin.y += velocityY*dt
            if velocityY <= 0 {
                let center = origin.x+size.width/2
                let crossed = windows.filter {
                    center >= $0.bounds.minX && center <= $0.bounds.maxX && previousY >= $0.bounds.maxY-1 && origin.y <= $0.bounds.maxY
                        && $0.bounds.maxY >= floor && $0.bounds.maxY+size.height <= screen.frame.maxY
                        && WindowTracker.edgeVisible($0, at: center, in: windows)
                }.max { $0.bounds.maxY < $1.bounds.maxY }
                if let edge = crossed {
                    origin.y = edge.bounds.maxY; support = edge; grounded = true; velocityY = 0
                    NSLog("[ThungNgern] landed on window %u", edge.id)
                }
                else if origin.y <= floor { origin.y = floor; grounded = true; velocityY = 0; support = nil }
            }
        }
        if origin.y+size.height > screen.frame.maxY && velocityY > 0 { velocityY = 0 }
        setPosition(origin)
        setState(!grounded ? (velocityY > 0 ? "jump" : "fall") : sleeping ? "sleep" : speechUntil > 0 ? "talk" : gestureTime > 0 ? (gesture ?? "idle") : resting ? "sit" : wandering ? (running ? "run" : "walk") : "idle")
    }
    private func beginDrag() {
        cancelDirectedMotion()
        dragStart = NSEvent.mouseLocation
        windowStart = position
        support = nil; grounded = false; sleeping = false; velocityY = 0
        panel.ignoresMouseEvents = false
        NSLog("[ThungNgern] drag began")
    }
    private func drag() {
        guard let start = dragStart, let origin = windowStart else { return }
        let mouse = NSEvent.mouseLocation
        setPosition(NSPoint(x: origin.x+mouse.x-start.x, y: origin.y+mouse.y-start.y))
    }
    private func endDrag() {
        dragStart = nil; windowStart = nil; velocityY = 0
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) { home() }
        else {
            windows = WindowTracker.visibleWindows()
            if let edge = WindowTracker.perchNear(origin: position, petSize: size, in: windows,
                                                  screens: NSScreen.screens.map(\.visibleFrame)) {
                attach(to: edge, x: position.x, stay: true)
                NSLog("[ThungNgern] drag snapped to %@ window %u", edge.owner, edge.id)
            } else {
                support = nil; grounded = false
                if let screen = screen() {
                    if let side = WindowTracker.sideNear(origin: position, petSize: size, in: windows, screen: screen.visibleFrame) {
                        _ = beginClimb(side: side.side, target: side.window)
                    }
                }
            }
        }
        NSLog("[ThungNgern] drag ended at %@", NSStringFromPoint(panel.frame.origin))
    }
    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: library.modelName)
        menu.delegate = self
        func add(_ title: String, _ action: Selector, to destination: NSMenu) {
            let item = destination.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = self
        }
        let emotes = NSMenu(title: "Emotes")
        for (title, action) in [("Wave", #selector(wave)), ("Happy", #selector(happy)),
                                ("Jump", #selector(jump)), (sleeping ? "Wake Up" : "Sleep", #selector(sleep)),
                                ("Sit", #selector(sit)), ("Run", #selector(run))] {
            add(title, action, to: emotes)
        }
        let emoteItem = menu.addItem(withTitle: "Emotes", action: nil, keyEquivalent: "")
        emoteItem.submenu = emotes
        let models = NSMenu(title: "Change Model")
        for model in library.models {
            let item = models.addItem(withTitle: model.displayName, action: #selector(changeModel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = model.id
            item.state = model.id == library.selectedModelID ? .on : .off
        }
        let modelItem = menu.addItem(withTitle: "Change Model", action: nil, keyEquivalent: "")
        modelItem.submenu = models
        add("Say", #selector(sayQuote), to: menu)
        menu.addItem(.separator())
        add(paused ? "Resume" : "Pause", #selector(togglePause), to: menu)
        add(wandering ? "Stop Wandering" : "Start Wandering", #selector(toggleWander), to: menu)
        menu.addItem(.separator())
        let move = NSMenu(title: "Move")
        for (title, action) in [("Walk Left", #selector(walkLeft)), ("Walk Right", #selector(walkRight)),
                                ("Climb Window Left Side", #selector(climbLeft)), ("Climb Window Right Side", #selector(climbRight)),
                                ("Visit a Window", #selector(visit)), ("Bring Me Home", #selector(home))] {
            add(title, action, to: move)
        }
        let moveItem = menu.addItem(withTitle: "Move", action: nil, keyEquivalent: "")
        moveItem.submenu = move
        menu.addItem(.separator())
        add("Quit", #selector(quit), to: menu)
        menu.items.last?.attributedTitle = NSAttributedString(string: "Quit", attributes: [
            .foregroundColor: NSColor.systemRed, .font: NSFont.menuFont(ofSize: 0)
        ])
        // Fit the longest label without forcing the oversized menu/font used previously.
        let font = NSFont.menuFont(ofSize: 0)
        let labelWidth = menu.items.map { ($0.title as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        menu.minimumWidth = ceil(labelWidth + 50)
        return menu
    }
    #if DEBUG
    @objc private func testLeftBoundary() {
        home(); if let screen = screen() { setPosition(NSPoint(x: screen.frame.minX + 8, y: screen.visibleFrame.minY)) }
        walkLeft()
    }
    @objc private func testClimbFinish() {
        if beginClimb(side: 1), let climb = climbing { setPosition(NSPoint(x: position.x, y: climb.window.bounds.maxY - 24)) }
    }
    @objc private func testDrop() {
        windows = WindowTracker.visibleWindows()
        guard let target = windows.first(where: { w in
            NSScreen.screens.contains { $0.visibleFrame.contains(CGPoint(x: w.bounds.midX, y: w.bounds.maxY + size.height)) }
                && WindowTracker.edgeVisible(w, at: w.bounds.midX, in: windows)
        }) else { return }
        beginDrag()
        setPosition(NSPoint(x: target.bounds.midX - size.width / 2, y: target.bounds.maxY - 30))
        endDrag()
    }
    #endif
    func menuWillOpen(_ menu: NSMenu) {
        menuOpen = true
        refreshMenuTitles(menu)
    }
    private func refreshMenuTitles(_ menu: NSMenu) {
        for item in menu.items {
            if item.action == #selector(togglePause) { item.title = paused ? "Resume" : "Pause" }
            if item.action == #selector(toggleWander) { item.title = wandering ? "Stop Wandering" : "Start Wandering" }
            if item.action == #selector(sleep) { item.title = sleeping ? "Wake Up" : "Sleep" }
            if item.action == #selector(changeModel(_:)), let id = item.representedObject as? String {
                item.state = id == library.selectedModelID ? .on : .off
            }
            if let submenu = item.submenu { refreshMenuTitles(submenu) }
        }
    }
    func menuDidClose(_ menu: NSMenu) { menuOpen = false }
    private func cancelDirectedMotion() {
        directedWalk = false; climbing = nil; gestureTime = 0; gesture = nil
    }
    private func finishDirectedWalk() {
        guard directedWalk else { return }
        directedWalk = false; running = false; decisionTime = 0
        gesture = "wave"; gestureTime = 2
        NSLog("[ThungNgern] directed walk reached edge; wandering resumed")
    }
    private func walk(toward side: CGFloat) {
        cancelDirectedMotion()
        direction = side; directedWalk = true; journeyTime = 0; decisionTime = 0
        wandering = true; sleeping = false; resting = false; running = false; paused = false
        setState(grounded ? "walk" : "fall")
        NSLog("[ThungNgern] walk command %.0f", side)
    }
    @objc private func walkLeft() { walk(toward: -1) }
    @objc private func walkRight() { walk(toward: 1) }
    @objc private func climbLeft() { _ = beginClimb(side: -1) }
    @objc private func climbRight() { _ = beginClimb(side: 1) }
    @discardableResult private func beginClimb(side: CGFloat, target: TrackedWindow? = nil) -> Bool {
        windows = WindowTracker.visibleWindows()
        guard let screen = screen(),
              let window = target ?? windows.filter({
                  WindowTracker.sideVisible($0, side: side, at: min(max(position.y + size.height / 2, $0.bounds.minY + 1), $0.bounds.maxY - 1), in: windows)
                      && $0.bounds.intersects(screen.frame)
                      && max($0.bounds.minY, screen.visibleFrame.minY) <= min($0.bounds.maxY, screen.visibleFrame.maxY - size.height)
              }).min(by: {
                  let a = side < 0 ? $0.bounds.minX : $0.bounds.maxX
                  let b = side < 0 ? $1.bounds.minX : $1.bounds.maxX
                  return abs(a - position.x - size.width / 2) < abs(b - position.x - size.width / 2)
              }) else { return false }
        cancelDirectedMotion()
        climbing = Climb(window: window, side: side)
        direction = -side; support = nil; grounded = false; velocityY = 0
        sleeping = false; resting = false; running = false; paused = false; wandering = false
        setPosition(NSPoint(x: WindowTracker.climbingX(window, side: side, petWidth: size.width, screen: screen.visibleFrame),
                            y: min(max(position.y, max(window.bounds.minY, screen.visibleFrame.minY)), min(window.bounds.maxY, screen.visibleFrame.maxY - size.height))))
        setState("climb")
        NSLog("[ThungNgern] climbing %@ window %u side %.0f", window.owner, window.id, side)
        return true
    }
    private func emote(_ next: String) {
        if climbing != nil { climbing = nil; grounded = false }
        directedWalk = false; sleeping = false; resting = false; paused = false
        gesture = next; gestureTime = 2.4; decisionTime = 0
        if grounded { setState(next) }
    }
    @objc private func wave() { emote("wave") }
    @objc private func happy() { emote("happy") }
    @objc private func togglePause() { paused.toggle(); NSLog("[ThungNgern] paused=%d", paused) }
    @objc private func toggleWander() { cancelDirectedMotion(); wandering.toggle(); sleeping = false; resting = false }
    @objc private func jump() { cancelDirectedMotion(); paused = false; sleeping = false; resting = false; support = nil; grounded = false; velocityY = 480; NSLog("[ThungNgern] jump") }
    @objc private func sleep() { cancelDirectedMotion(); sleeping.toggle(); wandering = false; resting = false; paused = false }
    @objc private func sit() { cancelDirectedMotion(); sleeping = false; wandering = false; resting = true; paused = false }
    @objc private func run() { cancelDirectedMotion(); wandering = true; sleeping = false; resting = false; running = true; paused = false; decisionTime = -3 }
    @objc private func changeModel(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, library.loadModel(id: id) else { return }
        UserDefaults.standard.set(id, forKey: "SelectedModelID")
        speech.orderOut(nil); speechUntil = 0; currentQuote = ""; quoteBag.removeAll()
        state = ""; frameIndex = 0; animationTime = 0
        view.setAccessibilityLabel("\(library.modelName) desktop companion")
        setState("idle")
        #if DEBUG
        speech.validateQuotes(quotes)
        #endif
    }
    @objc private func sayQuote() {
        if quoteBag.isEmpty {
            quoteBag = quotes.shuffled()
            if quoteBag.count > 1 && quoteBag.first == currentQuote { quoteBag.swapAt(0, 1) }
        }
        guard !quoteBag.isEmpty else { return }
        currentQuote = quoteBag.removeFirst()
        speechUntil = ProcessInfo.processInfo.systemUptime + 8
        speech.show(currentQuote)
        if let screen = screen() { speech.follow(panel.frame, on: screen.visibleFrame) }
        NSLog("[ThungNgern] quote: %@", currentQuote)
    }
    private func attach(to edge: TrackedWindow, x: CGFloat, stay: Bool) {
        cancelDirectedMotion()
        paused = false; sleeping = false; resting = false; running = false
        velocityY = 0; grounded = true; support = edge
        if stay { wandering = false }
        setPosition(NSPoint(x: x, y: edge.bounds.maxY))
        setState(wandering ? "walk" : "idle")
        panel.orderFrontRegardless()
    }
    @objc private func visit() {
        windows = WindowTracker.visibleWindows()
        guard let target = windows.first(where: { w in
            NSScreen.screens.contains { $0.visibleFrame.contains(CGPoint(x: w.bounds.midX, y: w.bounds.maxY+size.height)) }
                && WindowTracker.edgeVisible(w, at: w.bounds.midX, in: windows)
        }) else { NSLog("[ThungNgern] no exposed window edge with space above; bring a window down from the top of the screen"); return }
        attach(to: target, x: target.bounds.midX-size.width/2, stay: true)
        NSLog("[ThungNgern] visiting %@ window %u", target.owner, target.id)
    }
    @objc func home() {
        cancelDirectedMotion()
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        support = nil; grounded = true; velocityY = 0; sleeping = false; resting = false; paused = false
        setPosition(NSPoint(x: screen.visibleFrame.midX-size.width/2, y: screen.visibleFrame.minY))
        panel.orderFrontRegardless()
        setState("idle")
        NSLog("[ThungNgern] home visible=%d frame=%@ scale=%.1f", panel.isVisible, NSStringFromRect(panel.frame), screen.backingScaleFactor)
    }
    @objc private func screensChanged() { home() }
    @objc private func quit() { NSApp.terminate(nil) }
}
