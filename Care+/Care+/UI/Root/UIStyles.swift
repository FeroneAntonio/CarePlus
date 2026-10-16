import SwiftUI

struct AppCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

extension View {
    func appCardStyle() -> some View {
        modifier(AppCardStyle())
    }
}

struct AppSectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(AppTheme.textPrimary)
    }
}

extension View {
    func appSectionHeaderStyle() -> some View {
        modifier(AppSectionHeaderStyle())
    }
}

struct SectionHeader: View {
    let systemImage: String?
    let title: String
    let subtitle: String?
    
    init(systemImage: String? = nil, title: String, subtitle: String? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.primary)
                    .font(.headline)
                    .padding(.top, subtitle == nil ? 1 : 0) // aligns icon if no subtitle
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(.headline.weight(.semibold))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .foregroundStyle(AppTheme.textSecondary)
                        .font(.caption)
                }
            }
        }
        .appSectionHeaderStyle()
    }
}

struct AppPillButtonStyle: ButtonStyle {
    enum Role {
        case primary, warning
    }
    
    let role: Role
    let padding: EdgeInsets
    
    init(role: Role = .primary, padding: EdgeInsets? = nil) {
        self.role = role
        self.padding = padding ?? EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(role == .primary ? Color.white : Color.black.opacity(0.85))
            .padding(padding)
            .background(
                Capsule()
                    .fill(role == .primary ? AppTheme.primary : AppTheme.warning)
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

#if DEBUG
struct Styles_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            
            SectionHeader(systemImage: "star.fill", title: "Featured", subtitle: "Best of the month")
            
            SectionHeader(title: "No Icon Header")
            
            Button("Primary Button") {}
                .buttonStyle(AppPillButtonStyle(role: .primary))
            
            Button("Warning Button") {}
                .buttonStyle(AppPillButtonStyle(role: .warning))
            
            VStack {
                Text("Card Content")
                    .padding()
            }
            .appCardStyle()
            .padding()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
