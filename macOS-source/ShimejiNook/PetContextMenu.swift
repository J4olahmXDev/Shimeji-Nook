import Cocoa

/// A complete menu panel avoids native popup clipping beside a small nonactivating pet window.
final class PetContextMenu {
    var onAccessibilityChange: (([NSView]) -> Void)?
    private var main: MenuPanel?
    private var submenu: MenuPanel?
    private var submenuTitle: String?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var onClose: (() -> Void)?
    private let rowHeight: CGFloat = 24
    private let inset: CGFloat = 6

    func show(_ menu: NSMenu, at point: NSPoint, onClose: @escaping () -> Void) {
        close()
        self.onClose = onClose
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        guard let screen else { close(); return }
        let bounds = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let panel = makePanel(menu, width: 200, isSubmenu: false)
        panel.title = "\(menu.title) — เมนู"
        panel.setFrameOrigin(NSPoint(x: min(max(point.x, bounds.minX), bounds.maxX - panel.frame.width),
                                     y: min(max(point.y - panel.frame.height, bounds.minY), bounds.maxY - panel.frame.height)))
        main = panel
        panel.orderFrontRegardless()
        announceAccessibility()
        writeDebugState()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown && event.keyCode == 53 { self.close(); return nil }
            if event.type != .keyDown && !self.contains(NSEvent.mouseLocation) { self.close() }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }
    private func contains(_ point: NSPoint) -> Bool {
        [main, submenu].compactMap { $0 }.contains { $0.isVisible && $0.frame.contains(point) }
    }
    private func makePanel(_ menu: NSMenu, width: CGFloat, isSubmenu: Bool) -> MenuPanel {
        let height = inset * 2 + menu.items.reduce(CGFloat.zero) { $0 + ($1.isSeparatorItem ? 9 : rowHeight) }
        let panel = MenuPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + (isSubmenu ? 2 : 1))
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 11
        background.layer?.masksToBounds = true
        background.setAccessibilityElement(true)
        background.setAccessibilityRole(.menu)
        background.setAccessibilityLabel(menu.title)
        panel.contentView = background
        var top = height - inset
        for item in menu.items {
            if item.isSeparatorItem {
                top -= 9
                let line = NSBox(frame: NSRect(x: 12, y: top + 4, width: width - 24, height: 1))
                line.boxType = .separator
                background.addSubview(line)
                continue
            }
            top -= rowHeight
            let row = MenuButton(frame: NSRect(x: inset, y: top, width: width - inset * 2, height: rowHeight), item: item)
            row.onHover = { [weak self, weak panel, weak row] in
                guard let self, let panel, let row else { return }
                if let child = item.submenu { self.open(child, beside: panel, row: row) }
                else if !isSubmenu { self.hideSubmenu() }
            }
            row.onPress = { [weak self, weak panel, weak row] in
                guard let self else { return }
                if let child = item.submenu, let panel, let row { self.open(child, beside: panel, row: row); return }
                let action = item.action
                let target = item.target
                self.close()
                if let action { NSApp.sendAction(action, to: target, from: item) }
            }
            background.addSubview(row)
        }
        return panel
    }
    private func open(_ menu: NSMenu, beside parent: MenuPanel, row: MenuButton) {
        if submenuTitle == menu.title, submenu != nil { return }
        hideSubmenu()
        let font = NSFont.menuFont(ofSize: 13)
        let labelWidth = menu.items.map { ($0.title as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        let panel = makePanel(menu, width: max(150, ceil(labelWidth + 52)), isSubmenu: true)
        panel.title = menu.title
        submenuTitle = menu.title
        let point = parent.convertPoint(toScreen: NSPoint(x: parent.frame.width, y: row.frame.maxY))
        let bounds = (parent.screen ?? NSScreen.main)?.visibleFrame.insetBy(dx: 8, dy: 8) ?? parent.frame
        let x = parent.frame.maxX + panel.frame.width <= bounds.maxX ? parent.frame.maxX + 2 : parent.frame.minX - panel.frame.width - 2
        panel.setFrameOrigin(NSPoint(x: min(max(x, bounds.minX), bounds.maxX - panel.frame.width),
                                     y: min(max(point.y - panel.frame.height, bounds.minY), bounds.maxY - panel.frame.height)))
        submenu = panel
        panel.orderFrontRegardless()
        announceAccessibility()
        writeDebugState()
    }
    private func announceAccessibility() {
        onAccessibilityChange?([main, submenu].compactMap { $0?.contentView })
    }
    private func writeDebugState() {
        #if DEBUG
        let windows = [main, submenu].compactMap { $0 }.map { panel in
            ["id": panel.windowNumber, "title": panel.title, "frame": NSStringFromRect(panel.frame), "visible": panel.isVisible] as [String: Any]
        }
        for (index, panel) in [main, submenu].enumerated() {
            guard let view = panel?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "/tmp/ThungNgern-menu-\(index).png"))
            }
        }
        if let data = try? JSONSerialization.data(withJSONObject: windows, options: .prettyPrinted) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/ThungNgern-menu-debug.json"))
        }
        #endif
    }
    private func hideSubmenu() { submenu?.orderOut(nil); submenu = nil; submenuTitle = nil; announceAccessibility() }
    func close() {
        hideSubmenu()
        main?.orderOut(nil); main = nil; announceAccessibility()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil; globalMonitor = nil
        let callback = onClose; onClose = nil
        callback?()
    }
    deinit { close() }
}

private final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class MenuButton: NSButton {
    var onPress: (() -> Void)?
    var onHover: (() -> Void)?
    private var hovered = false
    private let hasSubmenu: Bool
    private let destructive: Bool
    private let checked: Bool
    private var hoverArea: NSTrackingArea?
    init(frame: NSRect, item: NSMenuItem) {
        hasSubmenu = item.submenu != nil
        destructive = item.title == "Quit"
        checked = item.state == .on
        super.init(frame: frame)
        title = item.title
        isBordered = false
        target = self
        action = #selector(pressed)
        setAccessibilityLabel(title)
        setAccessibilityRole(.menuItem)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func pressed() { onPress?() }
    override func updateTrackingAreas() {
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area); hoverArea = area
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true; onHover?() }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        if hovered {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 1), xRadius: 5, yRadius: 5).fill()
        }
        let font = NSFont.menuFont(ofSize: 13)
        let color: NSColor = hovered ? .white : (destructive ? .systemRed : .labelColor)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let height = (title as NSString).size(withAttributes: attributes).height
        (title as NSString).draw(at: NSPoint(x: 10, y: (bounds.height - height) / 2), withAttributes: attributes)
        if checked { ("✓" as NSString).draw(at: NSPoint(x: bounds.width - 23, y: (bounds.height - height) / 2), withAttributes: attributes) }
        if hasSubmenu { ("›" as NSString).draw(at: NSPoint(x: bounds.width - 18, y: (bounds.height - height) / 2), withAttributes: attributes) }
    }
}
