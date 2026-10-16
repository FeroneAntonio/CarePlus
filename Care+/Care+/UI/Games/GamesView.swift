//
//  GamesView.swift
//  Care+
//

import SwiftUI

struct GamesView: View {
    @Bindable var state: AppState
    @State private var showStats = false

    private let dailyGoal = 3
    private let upcoming = [("game_attention", "Attention"), ("game_logic", "Logic"), ("game_difference", "What Difference?")]

    private var gamesDoneToday: Int { min(dailyGoal, state.gameSessions(on: .now).count) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    TabHeader(state: state, title: "Games")
                    todayCard
                    gamesCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showStats) {
                NavigationStack {
                    GamesStatsView(state: state)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showStats = false }
                            }
                        }
                }
            }
        }
    }

    private var todayCard: some View {
        CardDark {
            Label("Today's activities", systemImage: "puzzlepiece.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.primary)

            Text(gamesDoneToday == 0
                 ? "Play \(dailyGoal) short memory games today"
                 : "Great! \(gamesDoneToday) of \(dailyGoal) memory games done")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            ProgressView(value: Double(gamesDoneToday), total: Double(dailyGoal))
                .tint(AppTheme.primary)

            Button { showStats = true } label: {
                Label("See progress", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppTheme.primary, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var gamesCard: some View {
        CardDark {
            Label("Train your memory", systemImage: "gamecontroller.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.primary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                NavigationLink {
                    GuessWhoGameView(state: state)
                } label: {
                    tile("game_memory")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play Memory: guess who")

                ForEach(upcoming, id: \.0) { image, title in
                    tile(image)
                        .overlay {
                            Text("Coming soon")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.45), in: Capsule())
                        }
                        .saturation(0.4)
                        .accessibilityElement()
                        .accessibilityLabel("\(title), coming soon")
                }
            }
        }
    }

    private func tile(_ image: String) -> some View {
        Image(image)
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
