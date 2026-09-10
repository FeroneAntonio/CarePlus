import SwiftUI

struct SignUpStep3WelcomeView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let onStart: () -> Void

    init(
        title: String = "Welcome!",
        message: String = "Every memory matters.",
        buttonTitle: String = "Start",
        onStart: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.onStart = onStart
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(Color.accentColor)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: onStart) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground)).ignoresSafeArea()
    }
}

struct SignUpStep3WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpStep3WelcomeView {
            // Preview action
        }
    }
}
