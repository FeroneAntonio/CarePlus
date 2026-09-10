import SwiftUI

struct MainTabView: View {
    @Bindable var state: AppState
    @State private var selectedTab: AppTab = .home
    @State private var tabBarHeight: CGFloat = 0

    /// ✅ memorizza l’ultima tab visitata che NON è chat
    @State private var lastNonChatTab: AppTab = .home

    private func mapToBottom(_ tab: AppTab) -> BottomTab {
        switch tab {
        case .home: return .home
        case .tasks: return .tasks
        case .diary: return .diary
        case .games: return .games
        case .contacts: return .contacts
        case .chat: return .home
        }
    }

    private func mapFromBottom(_ tab: BottomTab) -> AppTab {
        switch tab {
        case .home: return .home
        case .tasks: return .tasks
        case .diary: return .diary
        case .games: return .games
        case .contacts: return .contacts
        }
    }

    private func goToNextTab() {
        let order: [AppTab] = [.tasks, .diary, .games, .contacts, .home]
        guard let idx = order.firstIndex(of: selectedTab) else { return }
        let next = order[(idx + 1) % order.count]
        withAnimation(.easeInOut(duration: 0.25)) { selectedTab = next }
    }

    private func goToPreviousTab() {
        let order: [AppTab] = [.tasks, .diary, .games, .contacts, .home]
        guard let idx = order.firstIndex(of: selectedTab) else { return }
        let prev = order[(idx - 1 + order.count) % order.count]
        withAnimation(.easeInOut(duration: 0.25)) { selectedTab = prev }
    }

    var body: some View {
        let isChatActive: Bool = (selectedTab == .chat)

        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeDesignView(state: state, selectedTab: $selectedTab)

                case .tasks:
                    TasksTabView(state: state)

                case .diary:
                    DiaryView(state: state)

                case .games:
                    GamesView(state: state)

                case .chat:
                    ChatView(
                        state: state,
                        selectedTab: $selectedTab,
                        lastNonChatTab: lastNonChatTab
                    )

                case .contacts:
                    ContactsDesignView(state: state)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture().onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > 90, abs(dx) > abs(dy) * 1.5 else { return }
                    if dx < 0 { goToNextTab() } else { goToPreviousTab() }
                }
            )

            if !isChatActive {
                BottomPillTabBar(selected: Binding(
                    get: { mapToBottom(selectedTab) },
                    set: { selectedTab = mapFromBottom($0) }
                ))
                .measureTabBarHeight()
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .onPreferenceChange(TabBarHeightPreferenceKey.self) { h in tabBarHeight = h }
                .frame(height: max(48, tabBarHeight))
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.25), value: isChatActive)
                .accessibilityHidden(false)
            }
        }
        // ✅ aggiorna lastNonChatTab ogni volta che cambi tab (tranne chat)
        .onChange(of: selectedTab) { _, newValue in
            if newValue != .chat {
                lastNonChatTab = newValue
            }
        }
    }
}
