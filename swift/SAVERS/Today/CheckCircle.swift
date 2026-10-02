import SwiftUI

/// The circle that marks a letter: its initial while pending, a check on amber when done.
struct CheckCircle: View {
    let letter: Letter
    let done: Bool
    let isNow: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(done ? Color.done : Color.clear)
                    .stroke(done ? Color.done : isNow ? Color.sky : Color.line, lineWidth: 1.5)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.onDone)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                } else {
                    Text(letter.initial)
                        .font(.display(17, relativeTo: .body, weight: .bold))
                        .foregroundStyle(isNow ? Color.sky : Color.muted)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .frame(width: 36, height: 36)
            .frame(width: 44, height: 44)
            .contentShape(.circle)
        }
        .buttonStyle(PressScale(scale: 0.9))
        .accessibilityLabel("Check off \(letter.name)")
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}
