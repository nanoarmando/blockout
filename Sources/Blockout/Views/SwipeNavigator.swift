import AppKit
import SwiftUI

/// Steps the calendar range once per horizontal two-finger trackpad swipe over its area. Scroll events are
/// observed through a local monitor and always passed on, so vertical scrolling below keeps working.
struct SwipeNavigator: NSViewRepresentable {
    let onStep: (Int) -> Void

    func makeNSView(context: Context) -> SwipeView {
        let view = SwipeView()
        view.onStep = onStep
        return view
    }

    func updateNSView(_ view: SwipeView, context: Context) {
        view.onStep = onStep
    }

    static func dismantleNSView(_ view: SwipeView, coordinator: ()) {
        view.removeMonitor()
    }

    final class SwipeView: NSView {
        var onStep: ((Int) -> Void)?
        private var monitor: Any?
        private var accumulated: CGFloat = 0
        private var gestureHandled = true
        private static let threshold: CGFloat = 40

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func handle(_ event: NSEvent) {
            guard event.window === window, event.hasPreciseScrollingDeltas, event.momentumPhase.isEmpty,
                  bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
            if event.phase.contains(.began) {
                accumulated = 0
                gestureHandled = false
            }
            guard !gestureHandled, abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return }
            accumulated += event.scrollingDeltaX
            guard abs(accumulated) > Self.threshold else { return }
            gestureHandled = true
            // Natural scrolling is already applied: content moving left (negative delta) goes forward
            onStep?(accumulated < 0 ? 1 : -1)
        }
    }
}
