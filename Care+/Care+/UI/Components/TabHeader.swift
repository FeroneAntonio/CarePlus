import SwiftUI

/// Shared top bar for the main tabs: account · title · (chat) · menu.
struct TabHeader<ExtraMenu: View>: View {
    @Bindable var state: AppState
    let title: String
    var onChat: (() -> Void)?
    @ViewBuilder var extraMenu: ExtraMenu

    @State private var showAccount = false
    @State private var showSettings = false
    @State private var showMenu = false

    init(state: AppState, title: String, onChat: (() -> Void)? = nil, @ViewBuilder extraMenu: () -> ExtraMenu) {
        self.state = state
        self.title = title
        self.onChat = onChat
        self.extraMenu = extraMenu()
    }

    var body: some View {
        ZStack {
            HStack(spacing: 4) {
                iconButton("person.crop.circle", label: "Account") { showAccount = true }
                Spacer()
                if let onChat {
                    iconButton("bubble.left.and.bubble.right.fill", label: "Open care chat", action: onChat)
                }
                iconButton("ellipsis", label: "Menu") { showMenu = true }
            }

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .accessibilityAddTraits(.isHeader)
        }
        .confirmationDialog("Menu", isPresented: $showMenu, titleVisibility: .visible) {
            Button("Settings") { showSettings = true }
            extraMenu
        }
        .sheet(isPresented: $showAccount) { AccountView(state: state) }
        .sheet(isPresented: $showSettings) { SettingsView(state: state) }
    }

    private func iconButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension TabHeader where ExtraMenu == EmptyView {
    init(state: AppState, title: String, onChat: (() -> Void)? = nil) {
        self.init(state: state, title: title, onChat: onChat) { EmptyView() }
    }
}
