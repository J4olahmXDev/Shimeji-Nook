import Cocoa
import CoreGraphics

struct TrackedWindow {
    let id: CGWindowID
    let owner: String
    let bounds: CGRect // AppKit global points, bottom-left origin, including secondary displays.
}

enum WindowTracker {
    static func climbingX(_ window: TrackedWindow, side: CGFloat, petWidth: CGFloat, screen: CGRect) -> CGFloat {
        let wall = side < 0 ? window.bounds.minX : window.bounds.maxX
        return min(max(wall - petWidth / 2, screen.minX), screen.maxX - petWidth)
    }
    static func sideVisible(_ window: TrackedWindow, side: CGFloat, at y: CGFloat, in windows: [TrackedWindow]) -> Bool {
        let point = CGPoint(x: side < 0 ? window.bounds.minX - 1 : window.bounds.maxX + 1,
                            y: min(max(y, window.bounds.minY + 1), window.bounds.maxY - 1))
        for other in windows {
            if other.id == window.id { return true }
            if other.bounds.contains(point) { return false }
        }
        return false
    }
    static func sideNear(origin: CGPoint, petSize: CGSize, in windows: [TrackedWindow],
                         screen: CGRect, tolerance: CGFloat = 32) -> (window: TrackedWindow, side: CGFloat)? {
        let center = CGPoint(x: origin.x + petSize.width / 2, y: origin.y + petSize.height / 2)
        var result: (window: TrackedWindow, side: CGFloat)?
        var distance = tolerance + 1
        for window in windows {
            guard center.y >= window.bounds.minY, center.y <= window.bounds.maxY,
                  max(window.bounds.minY, screen.minY) <= min(window.bounds.maxY, screen.maxY - petSize.height) else { continue }
            for side: CGFloat in [-1, 1] {
                let x = climbingX(window, side: side, petWidth: petSize.width, screen: screen) + petSize.width / 2
                let gap = abs(center.x - x)
                if gap <= tolerance && gap < distance && sideVisible(window, side: side, at: center.y, in: windows) {
                    result = (window, side); distance = gap
                }
            }
        }
        return result
    }

    /// A dropped pet can attach slightly above or below an exposed top edge.
    static func perchNear(origin: CGPoint, petSize: CGSize, in windows: [TrackedWindow],
                          screens: [CGRect], tolerance: CGFloat = 72) -> TrackedWindow? {
        let center = origin.x + petSize.width / 2
        return windows.filter { window in
            center >= window.bounds.minX + 12 && center <= window.bounds.maxX - 12
                && abs(origin.y - window.bounds.maxY) <= tolerance
                && edgeVisible(window, at: center, in: windows)
                && screens.contains { screen in
                    screen.contains(CGPoint(x: center, y: window.bounds.maxY + petSize.height))
                }
        }.min { abs(origin.y - $0.bounds.maxY) < abs(origin.y - $1.bounds.maxY) }
    }
    static func visibleWindows() -> [TrackedWindow] {
        guard let primary = NSScreen.screens.first,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { d in
            guard let pid = d[kCGWindowOwnerPID as String] as? Int32, pid != getpid(),
                  (d[kCGWindowLayer as String] as? Int) == 0,
                  (d[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let id = d[kCGWindowNumber as String] as? UInt32,
                  let owner = d[kCGWindowOwnerName as String] as? String,
                  let b = d[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let w = b["Width"], let h = b["Height"], w > 160, h > 80 else { return nil }
            return TrackedWindow(id: id, owner: owner, bounds: CGRect(x: x, y: primary.frame.maxY-y-h, width: w, height: h))
        }
    }
    /// Hide edge segments covered by a window earlier in the front-to-back CG window list.
    static func edgeVisible(_ window: TrackedWindow, at x: CGFloat, in windows: [TrackedWindow]) -> Bool {
        for other in windows {
            if other.id == window.id { return true }
            if other.bounds.contains(CGPoint(x: x, y: window.bounds.maxY+1)) { return false }
        }
        return false
    }
}
