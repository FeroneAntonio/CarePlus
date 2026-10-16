import SwiftUI

struct EducationOnboardingCompactView: View {
    @Bindable var state: AppState

    private let topics: [(icon: String, title: String, text: String)] = [
        ("brain.head.profile", "What is dementia?",
         "A group of symptoms that affect memory, thinking and social abilities. Alzheimer's is its most common cause."),
        ("person.2.fill", "Made for two",
         "Care+ connects a patient and a caregiver, so daily care is shared instead of carried alone."),
        ("pills.fill", "Tasks & medication",
         "Plan the day, track doses and the home medicine cabinet, with gentle reminders."),
        ("book.closed.fill", "Daily diary",
         "Keep moments with text, photos, video or voice, and look back at them together."),
        ("phone.fill", "People close by",
         "Call loved ones in one tap, hear their recorded voice, and reach an SOS contact fast."),
        ("puzzlepiece.fill", "Memory games",
         "Short games built around familiar faces, with progress the caregiver can follow."),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Image("logonome")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 72)
                        .accessibilityHidden(true)
                    Text("Welcome to Care+")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("A calm, shared space for people living with Alzheimer's and those who care for them.")
                        .font(.body)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(spacing: 12) {
                    ForEach(topics, id: \.title) { topic in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: topic.icon)
                                .font(.title3)
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(topic.title)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(topic.text)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }

                Text("Care+ supports daily life. It is not a medical device and does not replace your doctor.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button { state.setEducationSeen() } label: {
                Text("Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(AppTheme.primary, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}
