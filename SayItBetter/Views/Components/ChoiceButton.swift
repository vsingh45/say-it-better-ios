import SwiftUI

/// A tappable answer option that turns green or red once the question is answered.
/// Shared by the Quiz tab and the Feed's quiz and meeting posts.
struct ChoiceButton: View {
    enum Status {
        /// Not answered yet: tappable.
        case idle
        /// The right answer, shown after answering.
        case correct
        /// The option the user picked, and it was wrong.
        case wrong
        /// Another option, faded after answering.
        case dimmed

        init(isAnswer: Bool, isPicked: Bool, answered: Bool) {
            if !answered {
                self = .idle
            } else if isAnswer {
                self = .correct
            } else if isPicked {
                self = .wrong
            } else {
                self = .dimmed
            }
        }
    }

    let title: String
    var font: Font = Theme.serif(.headline, weight: .medium)
    let status: Status
    let action: () -> Void

    private var tint: Color? {
        switch status {
        case .correct: .green
        case .wrong: .red
        case .idle, .dimmed: nil
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(font)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if status == .correct {
                    Image(systemName: "checkmark.circle.fill")
                } else if status == .wrong {
                    Image(systemName: "xmark.circle.fill")
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .foregroundStyle(tint ?? .primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.map { $0.opacity(0.15) } ?? Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint ?? Theme.hairline, lineWidth: tint == nil ? 0.5 : 1.5)
            )
            .opacity(status == .dimmed ? 0.55 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(status != .idle)
    }
}
