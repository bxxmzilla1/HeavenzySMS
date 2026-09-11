import SwiftUI
import UIKit

/// Resign the first responder (dismiss the keyboard) from anywhere.
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// Installs a single tap gesture on the key window that dismisses the keyboard when
/// the user taps anywhere outside a text field. `cancelsTouchesInView = false` keeps
/// buttons, pickers and text fields fully tappable.
final class KeyboardDismissInstaller: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissInstaller()

    func install() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return }
            if window.gestureRecognizers?.contains(where: { $0.name == "kbDismissTap" }) == true { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
            tap.name = "kbDismissTap"
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
        }
    }

    @objc private func dismissKeyboard() {
        hideKeyboard()
    }

    // Let the tap coexist with scrolling, buttons, pickers, etc.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    // Only dismiss when the tap is NOT on a text field / control. This keeps the
    // field's own tap, double-tap and long-press (select / paste) gestures intact.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let v = view {
            if v is UITextField || v is UITextView || v is UIControl { return false }
            // The editing-interaction / selection views that back UITextField also
            // report as UITextInput-conforming; skip those too.
            if v is UITextInput { return false }
            view = v.superview
        }
        return true
    }
}
