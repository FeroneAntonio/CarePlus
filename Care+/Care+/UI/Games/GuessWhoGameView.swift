//
//  GuessWhoGameView.swift
//  Care+
//
//  "Who is this?" — recognise familiar faces from the patient's own contacts.
//

import SwiftUI

struct GuessWhoGameView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    private let totalRounds = 5
    private let optionsCount = 4
    /// After this many wrong answers the right one is shown, so a round never becomes frustrating.
    private let maxAttempts = 2

    @State private var startedAt: Date?
    @State private var roundIndex = 0
    @State private var target: ContactItem?
    @State private var options: [ContactItem] = []
    @State private var wrongPicks: Set<UUID> = []
    @State private var revealed = false
    @State private var results: [GuessWhoRoundResult] = []
    @State private var finished: GameSessionResult?

    /// Contacts usable in the game: they need a name and a photo.
    private var eligible: [ContactItem] {
        state.contacts.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && $0.photoData != nil }
    }

    private var correctCount: Int { results.filter(\.isCorrect).count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if startedAt == nil {
                    introCard
                } else if let target {
                    roundView(target)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 120)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Who is this?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if startedAt != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(roundIndex + 1) of \(totalRounds)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .fullScreenCover(item: $finished) { session in
            GuessWhoFinishView(session: session, onRetry: start, onClose: { dismiss() })
        }
    }

    // MARK: - Views

    private var introCard: some View {
        CardDark {
            Image(systemName: "person.crop.square.on.square.angled.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.primary)
            Text("Recognise the people you love")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text("A photo appears: choose the right name. \(totalRounds) short rounds, no rush.")
                .foregroundStyle(AppTheme.textSecondary)

            if eligible.count < optionsCount {
                Label("Add a photo to at least \(optionsCount) contacts to play. You have \(eligible.count).",
                      systemImage: "info.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Button(action: start) {
                Text("Start")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(AppTheme.primary, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(eligible.count < optionsCount)
            .opacity(eligible.count < optionsCount ? 0.4 : 1)
        }
    }

    private func roundView(_ target: ContactItem) -> some View {
        VStack(spacing: 16) {
            ProgressView(value: Double(roundIndex), total: Double(totalRounds))
                .tint(AppTheme.primary)

            if let data = target.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityLabel("Photo of the person to recognise")
            }

            Text(feedback(for: target))
                .font(.headline)
                .foregroundStyle(revealed ? (wrongPicks.isEmpty ? AppTheme.success : AppTheme.primary) : AppTheme.textSecondary)
                .frame(minHeight: 24)
                .animation(.default, value: revealed)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(options) { option in
                    optionButton(option, target: target)
                }
            }
        }
    }

    private func optionButton(_ option: ContactItem, target: ContactItem) -> some View {
        let isAnswer = option.id == target.id
        let isWrong = wrongPicks.contains(option.id)
        let fill: Color = revealed && isAnswer ? AppTheme.success : isWrong ? AppTheme.danger.opacity(0.15) : AppTheme.surface

        return Button { choose(option, target: target) } label: {
            VStack(spacing: 2) {
                Text(option.name)
                    .font(.title3.weight(.semibold))
                if let relation = option.relation, !relation.isEmpty {
                    Text(relation).font(.caption)
                }
            }
            .foregroundStyle(revealed && isAnswer ? .white : AppTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.stroke))
        }
        .buttonStyle(.plain)
        .opacity(revealed && !isAnswer ? 0.5 : 1)
        .allowsHitTesting(!revealed && !isWrong)
    }

    private func feedback(for target: ContactItem) -> String {
        if revealed { return wrongPicks.isEmpty ? "Yes, it's \(target.name)!" : "This is \(target.name)." }
        return wrongPicks.isEmpty ? "Who is this?" : "Not quite, try again."
    }

    // MARK: - Game flow

    private func start() {
        finished = nil
        startedAt = .now
        roundIndex = 0
        results = []
        prepareRound()
    }

    private func prepareRound() {
        wrongPicks = []
        revealed = false
        let picked = eligible.shuffled().prefix(optionsCount)
        target = picked.first
        options = picked.shuffled()
    }

    private func choose(_ option: ContactItem, target: ContactItem) {
        if option.id == target.id {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            revealed = true
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            wrongPicks.insert(option.id)
            revealed = wrongPicks.count >= maxAttempts
        }
        guard revealed else { return }

        results.append(GuessWhoRoundResult(
            roundIndex: roundIndex,
            contactKey: target.uniqueKey,
            isCorrect: wrongPicks.isEmpty,
            attempts: wrongPicks.count + (option.id == target.id ? 1 : 0)
        ))

        Task {
            try? await Task.sleep(for: .seconds(1.4))
            nextRound()
        }
    }

    private func nextRound() {
        if roundIndex < totalRounds - 1 {
            withAnimation(.snappy) {
                roundIndex += 1
                prepareRound()
            }
            return
        }

        let start = startedAt ?? .now
        let session = GameSessionResult(
            type: .guessWho,
            startedAt: start,
            finishedAt: .now,
            durationSeconds: Int(Date.now.timeIntervalSince(start)),
            totalRounds: totalRounds,
            correctCount: correctCount,
            totalAttempts: results.map(\.attempts).reduce(0, +),
            roundResults: results
        )
        state.addGameResult(session)
        finished = session
    }
}
