import CoreGraphics

/// How far the big screen is zoomed in and moved. The picture is scaled around the middle of the view,
/// then moved by `offset` (in view points).
struct UnoZoomState: Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero

    static let identity = UnoZoomState()

    /// True once it's zoomed in at all.
    var isZoomed: Bool { scale > 1.001 }
}

/// The big screen's zoom and pan math, kept free of views so it can be tested.
/// `box` is the view the picture sits in, `content` is the picture's size inside it at 1x (already fitted).
enum UnoZoomMath {
    static let minScale: CGFloat = 1
    static let maxScale: CGFloat = 4
    /// Where a double tap zooms to.
    static let doubleTapScale: CGFloat = 2.5

    /// Keeps a zoom between 1x and 4x. Anything that isn't a real number is 1x.
    static func clampScale(_ scale: CGFloat) -> CGFloat {
        guard scale.isFinite else { return minScale }
        return min(max(scale, minScale), maxScale)
    }

    /// The furthest the picture may move each way at `scale` without an edge coming inside the view.
    static func maxOffset(scale: CGFloat, content: CGSize, box: CGSize) -> CGSize {
        let s = clampScale(scale)
        return CGSize(
            width: max(0, (content.width * s - box.width) / 2),
            height: max(0, (content.height * s - box.height) / 2)
        )
    }

    /// Keeps the picture from leaving the view: while it's smaller than the view on a side it stays centered
    /// on that side, and while it's bigger its edges can't come inside the view.
    static func clampOffset(_ offset: CGSize, scale: CGFloat, content: CGSize, box: CGSize) -> CGSize {
        let limit = maxOffset(scale: scale, content: content, box: box)
        let x = offset.width.isFinite ? offset.width : 0
        let y = offset.height.isFinite ? offset.height : 0
        return CGSize(
            width: min(max(x, -limit.width), limit.width),
            height: min(max(y, -limit.height), limit.height)
        )
    }

    /// The same zoom, with the scale and move kept in bounds.
    static func clamp(_ state: UnoZoomState, content: CGSize, box: CGSize) -> UnoZoomState {
        let scale = clampScale(state.scale)
        return UnoZoomState(scale: scale, offset: clampOffset(state.offset, scale: scale, content: content, box: box))
    }

    /// Zooms to `scale` keeping the spot under `point` (a point in the view) where it is, as far as the edges allow.
    static func zoom(_ state: UnoZoomState, to scale: CGFloat, around point: CGPoint, content: CGSize, box: CGSize) -> UnoZoomState {
        let old = clampScale(state.scale)
        let new = clampScale(scale)
        let center = CGPoint(x: box.width / 2, y: box.height / 2)
        // The spot under the finger, measured from the middle of the unzoomed picture.
        let spotX = (point.x - center.x - state.offset.width) / old
        let spotY = (point.y - center.y - state.offset.height) / old
        let offset = CGSize(
            width: point.x - center.x - spotX * new,
            height: point.y - center.y - spotY * new
        )
        return UnoZoomState(scale: new, offset: clampOffset(offset, scale: new, content: content, box: box))
    }

    /// A double tap: back to 1x when zoomed in, otherwise 2.5x around the tapped spot.
    static func doubleTap(_ state: UnoZoomState, at point: CGPoint, content: CGSize, box: CGSize) -> UnoZoomState {
        if state.isZoomed { return .identity }
        return zoom(state, to: doubleTapScale, around: point, content: content, box: box)
    }

    /// Moves the picture by a drag, from where it was when the drag began. Does nothing at 1x.
    static func pan(_ start: UnoZoomState, by translation: CGSize, content: CGSize, box: CGSize) -> UnoZoomState {
        guard start.isZoomed else { return UnoZoomState(scale: clampScale(start.scale), offset: .zero) }
        let moved = CGSize(width: start.offset.width + translation.width, height: start.offset.height + translation.height)
        return UnoZoomState(scale: start.scale, offset: clampOffset(moved, scale: start.scale, content: content, box: box))
    }
}
