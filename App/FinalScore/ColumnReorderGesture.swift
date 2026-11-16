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
        private weak var scrollView: UIScrollView?
        private var scrollingWasEnabled = true

        init(gesture: ColumnReorderGesture) {
            self.gesture = gesture
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer is UIPanGestureRecognizer
        }

        @objc func handle(_ hold: UILongPressGestureRecognizer) {
            let point = hold.location(in: hold.view?.window)
            let translation = CGSize(width: point.x - start.x, height: point.y - start.y)
            switch hold.state {
            case .began:
                start = point
                var ancestor = hold.view?.superview
                while let view = ancestor {
                    if let scroll = view as? UIScrollView {
                        scrollView = scroll
                        scrollingWasEnabled = scroll.isScrollEnabled
                        scroll.isScrollEnabled = false
                        break
                    }
                    ancestor = view.superview
                }
                gesture.onChanged(.zero)
            case .changed:
                gesture.onChanged(translation)
            case .ended:
                restoreScrolling()
                gesture.onEnded(translation)
            case .cancelled, .failed:
                restoreScrolling()
                gesture.onChanged(nil)
            default:
                break
            }
        }

        func restoreScrolling() {
            scrollView?.isScrollEnabled = scrollingWasEnabled
            scrollView = nil
        }
    }
}
