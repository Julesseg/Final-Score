import SwiftUI
import UIKit

struct ColumnReorderGesture: UIViewRepresentable {
    let onChanged: (CGSize?) -> Void
    let onEnded: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(gesture: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isAccessibilityElement = false
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle))
        hold.minimumPressDuration = 0.35
        hold.delegate = context.coordinator
        view.addGestureRecognizer(hold)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.gesture = self
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.restoreScrolling()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var gesture: ColumnReorderGesture
        private var start = CGPoint.zero
        private var lastPoint = CGPoint.zero
        private var startOffset: CGFloat = 0
        private weak var sourceView: UIView?
        private weak var scrollView: UIScrollView?
        private var scrollingWasEnabled = true
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval?

        init(gesture: ColumnReorderGesture) {
            self.gesture = gesture
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer is UIPanGestureRecognizer
        }

        @objc func handle(_ hold: UILongPressGestureRecognizer) {
            let point = hold.location(in: hold.view?.window)
            lastPoint = point
            switch hold.state {
            case .began:
                start = point
                sourceView = hold.view
                var ancestor = hold.view?.superview
                while let view = ancestor {
                    if let scroll = view as? UIScrollView {
                        scrollView = scroll
                        startOffset = scroll.contentOffset.x
                        scrollingWasEnabled = scroll.isScrollEnabled
                        scroll.isScrollEnabled = false
                        break
                    }
                    ancestor = view.superview
                }
                gesture.onChanged(.zero)
                let link = CADisplayLink(target: self, selector: #selector(scrollAtEdge))
                displayLink = link
                link.add(to: .main, forMode: .common)
            case .changed:
                gesture.onChanged(translation(at: point))
            case .ended:
                let translation = translation(at: point)
                restoreScrolling()
                gesture.onEnded(translation)
            case .cancelled, .failed:
                restoreScrolling()
                gesture.onChanged(nil)
            default:
                break
            }
        }

        private func translation(at point: CGPoint) -> CGSize {
            CGSize(
                width: point.x - start.x + (scrollView?.contentOffset.x ?? startOffset) - startOffset,
                height: point.y - start.y
            )
        }

        @objc private func scrollAtEdge(_ link: CADisplayLink) {
            let elapsed = min(link.timestamp - (lastTimestamp ?? link.timestamp - link.duration), 1 / 15)
            lastTimestamp = link.timestamp
            guard let scrollView, let window = sourceView?.window,
                  abs(lastPoint.y - start.y) < 44
            else { return }
            let viewport = scrollView.convert(scrollView.bounds, to: window)
                .intersection(window.bounds.inset(by: window.safeAreaInsets))
            guard !viewport.isNull, viewport.width > 0 else { return }
            let edgeWidth: CGFloat = min(56, viewport.width / 3)
            let left = max(0, min(1, (edgeWidth - (lastPoint.x - viewport.minX)) / edgeWidth))
            let right = max(0, min(1, (edgeWidth - (viewport.maxX - lastPoint.x)) / edgeWidth))
            let distance = (right - left) * 320 * CGFloat(max(elapsed, 0))
            guard distance != 0 else { return }
            let minimum = -scrollView.adjustedContentInset.left
            let maximum = max(minimum, scrollView.contentSize.width - scrollView.bounds.width + scrollView.adjustedContentInset.right)
            let offset = min(maximum, max(minimum, scrollView.contentOffset.x + distance))
            guard offset != scrollView.contentOffset.x else { return }
            scrollView.setContentOffset(CGPoint(x: offset, y: scrollView.contentOffset.y), animated: false)
            gesture.onChanged(translation(at: lastPoint))
        }

        func restoreScrolling() {
            displayLink?.invalidate()
            displayLink = nil
            lastTimestamp = nil
            scrollView?.isScrollEnabled = scrollingWasEnabled
            scrollView = nil
            sourceView = nil
        }
    }
}
