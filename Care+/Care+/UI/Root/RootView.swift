import SwiftUI

struct RootView: View {
    @Bindable var state: AppState

    var body: some View {
        Group {
            if state.currentUser == nil && !state.isGuest {
                AuthLandingView(state: state)

            } else if !state.isGuest && state.userRole == nil {
                NavigationStack {
                    RoleChoiceView()
                }
                .environment(state)

            } else if state.needsSetupWizard {
                NavigationStack {
                    SetupWizardView()
                }
                .environment(state)

            } else if !state.hasSeenEducation {
                EducationOnboardingCompactView(state: state)

            } else if !state.hasCompletedOnboarding {
                OnboardingPermissionsView(state: state)

            } else {
                MainTabView(state: state)
            }
        }
    }
}
