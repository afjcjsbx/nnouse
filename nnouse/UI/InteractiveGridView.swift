import AppKit

final class InteractiveGridView: NSGridView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = deepestHit(in: self, point: point) {
            return hit
        }
        return super.hitTest(point)
    }

    private func deepestHit(in view: NSView, point: NSPoint) -> NSView? {
        for subview in view.subviews.reversed() {
            let localPoint = subview.convert(point, from: view)
            if let hit = deepestHit(in: subview, point: localPoint) {
                return hit
            }
        }

        guard !view.isHidden, view.bounds.contains(point) else { return nil }
        return view
    }
}
