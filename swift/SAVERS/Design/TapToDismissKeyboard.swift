import SwiftUI

/// A tap anywhere outside a text field closes the keyboard, and the tap still reaches what's under it: a
/// button works on the first touch, and tapping another field moves the keyboard there.
/// SwiftUI has no way to tell a tap on a field from a tap elsewhere, so this watches the window once for all.
struct TapToDismissKeyboard: UIViewRepresentable {
    func makeUIView(context: Context) -> Watcher { Watcher() }
    func updateUIView(_ uiView: Watcher, context: Context) {}

    final class Watcher: UIView, UIGestureRecognizerDelegate {
        private weak var watched: UIWindow?
        private lazy var tap: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
            tap.cancelsTouchesInView = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            return tap
        }()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, window !== watched else { return }
            watched?.removeGestureRecognizer(tap)
            window.addGestureRecognizer(tap)
            watched = window
        }

        @objc private func dismiss() {
            watched?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let v = view {
                if v is UITextView || v is UITextField { return false }
                view = v.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
