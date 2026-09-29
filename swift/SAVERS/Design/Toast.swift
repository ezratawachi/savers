import SwiftUI

/// A short line at the bottom that goes away by itself: "Copia importada".
@Observable
final class Toast {
    private(set) var message: String?
    @ObservationIgnored private var hide: Task<Void, Never>?

    func show(_ text: String) {
        message = text
        hide?.cancel()
        hide = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            message = nil
        }
    }
}
