import SwiftUI

struct AuthGateView: View {
    @Bindable var state: AppState
    @State private var isBootstrapping = true

    var body: some View {
        Group {
            if isBootstrapping {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading session...")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background.ignoresSafeArea())
            } else {
                // After bootstrapping, let RootView decide the routing.
                RootView(state: state)
            }
        }
        .task {
            state.load()
            await state.loadSupabaseSession()
            isBootstrapping = false
        }
    }
}
