import Cocoa

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    // There is no nib/storyboard in this project: retain and install the delegate explicitly.
    static func main() {
        #if DEBUG
        freopen("/tmp/ThungNgern-runtime.log", "a", stderr)
        #endif
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
    private var companion: CompanionController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opening a new build replaces older copies, even from a different path.
        // LSUIElement apps can otherwise run side by side with the same bundle ID.
        let current = NSRunningApplication.current
        let identifier = Bundle.main.bundleIdentifier ?? "local.suanaph.ThungNgern"
        let legacyDefaults = UserDefaults.standard.persistentDomain(forName: "local.suanaph.ThungNgern")
        if UserDefaults.standard.string(forKey: "SelectedModelID") == nil,
           let selected = legacyDefaults?["SelectedModelID"] as? String {
            UserDefaults.standard.set(selected, forKey: "SelectedModelID")
        }
        let previousInstances = [identifier, "local.suanaph.ThungNgern"].flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        }
        for other in previousInstances
            where other.processIdentifier != current.processIdentifier
                && (other.launchDate ?? .distantPast) <= (current.launchDate ?? Date()) {
            other.hide()
            other.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if !other.isTerminated { other.forceTerminate() }
            }
        }
        NSApp.setActivationPolicy(.accessory)
        let controller = CompanionController()
        companion = controller
        controller.start()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🐾"
        item.button?.toolTip = "ถุงเงิน — ThungNgern"
        item.menu = controller.makeMenu()
        statusItem = item
        NSLog("[ThungNgern] started: %@", Bundle.main.bundlePath)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
