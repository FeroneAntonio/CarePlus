//
//  GuessWhoFinishView.swift
//  Care+
//

import SwiftUI

struct GuessWhoFinishView: View {
    let session: GameSessionResult
    let onRetry: () -> Void
    let onClose: () -> Void

    private var message: String {
        switch Double(session.correctCount) / Double(max(session.totalRounds, 1)) {
        case 0.8...: return "Wonderful memory today!"
        case 0.5..<0.8: return "Well done, keep it up."
        default: return "Every game is good practice."
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "star.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(AppTheme.warning)

            VStack(spacing: 6) {
                Text("\(session.correctCount) of \(session.totalRounds)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(message)
                    .font(.title3)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            HStack(spacing: 8) {
                ForEach(session.roundResults, id: \.roundIndex) { round in
                    Image(systemName: round.isCorrect ? "checkmark.circle.fill" : "arrow.uturn.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(round.isCorrect ? AppTheme.success : AppTheme.warning)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(session.correctCount) correct out of \(session.totalRounds)")

            Text("\(session.durationSeconds) seconds · \(session.totalAttempts) attempts")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onRetry) {
                    Text("Play again")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(AppTheme.primary, in: Capsule())
                        .foregroundStyle(.white)
                }
                Button("Close", action: onClose)
                    .font(.headline)
                    .frame(minHeight: 44)
                    .foregroundStyle(AppTheme.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
    }
}
