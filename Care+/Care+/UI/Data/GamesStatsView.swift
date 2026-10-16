//
//  GamesStatsView.swift
//  Care+
//

import SwiftUI
import Charts

struct GamesStatsView: View {
    @Bindable var state: AppState
    @State private var selectedDay: Date = .now

    private var daySessions: [GameSessionResult] {
        state.gameSessions(on: selectedDay, type: .guessWho)
    }

    private var monthlyAgg: (sessions: Int, totalAttempts: Int, avgTimeSec: Double, avgScore: Double) {
        state.gameMonthlyAggregateLastNDays(days: 30, now: .now, type: .guessWho)
    }

    private var scoreChart: [(dayStart: Date, avgScore: Double, sessions: Int)] {
        state.guessWhoAvgScorePerDayLastNDays(days: 14, now: .now)
    }

    private var attemptsChart: [(dayStart: Date, attempts: Int)] {
        state.guessWhoAttemptsPerDayLastNDays(days: 14, now: .now)
    }

    /// Fixed 14-day window so both charts line up even when some days have no sessions.
    private var chartDays: ClosedRange<Date> {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) ?? .now
        return (cal.date(byAdding: .day, value: -14, to: tomorrow) ?? .now)...tomorrow
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                summaryTiles

                CardDark {
                    sectionTitle("Score trend", icon: "chart.line.uptrend.xyaxis", subtitle: "Average correct answers per day · last 14 days")

                    Chart(scoreChart.filter { $0.sessions > 0 }, id: \.dayStart) { p in
                        AreaMark(
                            x: .value("Day", p.dayStart, unit: .day),
                            y: .value("Score", p.avgScore)
                        )
                        .foregroundStyle(AppTheme.primary.opacity(0.15))
                        LineMark(
                            x: .value("Day", p.dayStart, unit: .day),
                            y: .value("Score", p.avgScore)
                        )
                        .foregroundStyle(AppTheme.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        PointMark(
                            x: .value("Day", p.dayStart, unit: .day),
                            y: .value("Score", p.avgScore)
                        )
                        .foregroundStyle(AppTheme.primary)
                    }
                    .chartYScale(domain: 0...1)
                    .chartXScale(domain: chartDays)
                    .chartYAxis {
                        AxisMarks(values: [0, 0.5, 1]) { v in
                            AxisGridLine()
                            AxisValueLabel { Text("\(Int((v.as(Double.self) ?? 0) * 100))%") }
                        }
                    }
                    .frame(height: 180)
                }

                CardDark {
                    sectionTitle("Attempts", icon: "hand.tap.fill", subtitle: "Total attempts per day · last 14 days")

                    Chart(attemptsChart, id: \.dayStart) { p in
                        BarMark(
                            x: .value("Day", p.dayStart, unit: .day),
                            y: .value("Attempts", p.attempts)
                        )
                        .foregroundStyle(AppTheme.primary.gradient)
                        .cornerRadius(4)
                    }
                    .chartXScale(domain: chartDays)
                    .frame(height: 160)
                }

                CardDark {
                    sectionTitle("Sessions by day", icon: "calendar", subtitle: nil)

                    DatePicker("Day", selection: $selectedDay, displayedComponents: .date)
                        .foregroundStyle(AppTheme.textPrimary)

                    if daySessions.isEmpty {
                        Text("No sessions on this day.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach(daySessions) { s in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.finishedAt.formatted(.dateTime.hour().minute()))
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("\(s.durationSeconds)s · \(s.totalAttempts) attempts")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                Text("\(s.correctCount)/\(s.totalRounds)")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.primary)
                            }
                            .padding(12)
                            .background(AppTheme.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Memory progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryTiles: some View {
        HStack(spacing: 12) {
            statTile(value: "\(monthlyAgg.sessions)", label: "Sessions\n30 days")
            statTile(value: String(format: "%.0f%%", monthlyAgg.avgScore * 100), label: "Average\nscore")
            statTile(value: String(format: "%.0fs", monthlyAgg.avgTimeSec), label: "Average\ntime")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.primary)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.stroke, lineWidth: 1))
    }

    private func sectionTitle(_ title: String, icon: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(AppTheme.primary)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}
