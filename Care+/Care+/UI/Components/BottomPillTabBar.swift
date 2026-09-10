import SwiftUI

enum BottomTab: Int, CaseIterable {
    case home = 0, tasks, diary, games, contacts
}

struct BottomPillTabBar: View {
    @Binding var selected: BottomTab
    @Environment(\.colorScheme) private var scheme

    // ✅ Altezza fissa coerente con le altre schermate
    private let barHeight: CGFloat = 64

    var body: some View {
        HStack(spacing: 16) {

            // ✅ HUB ALL’ESTREMA SINISTRA
            tab(.home, "Hub", "house.fill")

            tab(.tasks, "Tasks", "checklist")
            tab(.diary, "Diary", "book")
            tab(.games, "Games", "gamecontroller.fill")
            tab(.contacts, "Contacts", "person.2.fill")
        }
        .frame(height: barHeight)                 // ✅ altezza fissa
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(AppTheme.surface)
                .frame(height: barHeight)         // ✅ capsule stessa altezza
                .overlay(
                    Capsule()
                        .fill(
                            scheme == .dark
                            ? AppTheme.stroke
                            : Color.clear
                        )
                        .frame(height: barHeight)
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    AppTheme.stroke,
                    lineWidth: 1
                )
                .frame(height: barHeight)
        )
        .shadow(
            color: AppTheme.shadow,
            radius: 14,
            x: 0,
            y: 8
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selected)
    }

    private func tab(_ tab: BottomTab, _ title: String, _ system: String) -> some View {
        let isOn = (selected == tab)

        return Button {
            selected = tab
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isOn {
                        Circle()
                            .fill(AppTheme.primary.opacity(scheme == .dark ? 0.18 : 0.14))
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.primary.opacity(0.30), lineWidth: 1)
                            )
                            .frame(width: 32, height: 32)
                    }

                    Image(systemName: system)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            isOn
                            ? AppTheme.primary
                            : (scheme == .dark
                               ? AppTheme.textSecondary
                               : AppTheme.primary.opacity(0.45))
                        )
                }
                .frame(height: 32)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(
                        isOn
                        ? AppTheme.textPrimary
                        : (scheme == .dark ? AppTheme.textSecondary : AppTheme.primary.opacity(0.45))
                    )
            }
            .frame(maxWidth: .infinity)     // ✅ allineamento uniforme
            .padding(.vertical, 6)
        }
        .contentShape(Rectangle())
        .accessibilityLabel(title)
        .buttonStyle(.plain)
    }
}

