import SwiftUI
import UIKit

/// UNICO AppTheme: all colors used in Views should come from here.
///
/// Provides adaptive tokens for both light and dark modes.
/// Maps to existing AppColors for light mode and custom palette for dark mode.
/// Also exposes compatibility aliases for legacy code.
public enum AppTheme {
    // MARK: - Palette Definition
    
    private struct Palette {
        let background: Color
        let surface: Color
        let surface2: Color
        let stroke: Color
        let shadow: Color
        let textPrimary: Color
        let textSecondary: Color
        let primary: Color
        let primaryMuted: Color
        let warning: Color
        let success: Color
        let danger: Color
        let secondary: Color
        let disabled: Color
    }
    
    // MARK: - Helper
    
    private static func hex(_ hex: Int, alpha: Double = 1) -> Color {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue).opacity(alpha)
    }
    
    // MARK: - Light Palette
    
    private static var light: Palette {
        let warningColor = Color(red: 246/255, green: 200/255, blue: 102/255) // warm yellow
        let successColor = Color(red: 96/255, green: 187/255, blue: 120/255)  // green suited for light
        let dangerColor = Color(red: 210/255, green: 92/255, blue: 92/255)     // red suited for light
        
        let textSecondaryColor = AppColors.textSecondary
        let disabledColor = textSecondaryColor.opacity(0.6)
        
        return Palette(
            background: AppColors.background,
            surface: AppColors.surface,
            surface2: AppColors.surface.opacity(0.85),
            stroke: Color.black.opacity(0.12),
            shadow: Color.black.opacity(0.10),
            textPrimary: AppColors.textPrimary,
            textSecondary: textSecondaryColor,
            primary: AppColors.primary,
            primaryMuted: AppColors.primary.opacity(0.65),
            warning: warningColor,
            success: successColor,
            danger: dangerColor,
            secondary: AppColors.secondary,
            disabled: disabledColor
        )
    }
    
    // MARK: - Dark Palette
    
    private static var dark: Palette {
        let background = hex(0x0A1C1A)
        let surface = hex(0x0F2A27)
        let surface2 = hex(0x133430)
        let primary = hex(0x1FA39A)
        let primaryMuted = hex(0x1FA39A, alpha: 0.65)
        let warning = hex(0xE8C774)
        let success = hex(0x68C08D)
        let danger = hex(0xD26E6E)
        let textPrimary = hex(0xFFFFFF, alpha: 0.94)
        let textSecondary = hex(0xFFFFFF, alpha: 0.70)
        let stroke = hex(0xFFFFFF, alpha: 0.10)
        let shadow = Color.black.opacity(0.50)
        
        let secondary = primaryMuted
        let disabled = textSecondary.opacity(0.6)
        
        return Palette(
            background: background,
            surface: surface,
            surface2: surface2,
            stroke: stroke,
            shadow: shadow,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            primary: primary,
            primaryMuted: primaryMuted,
            warning: warning,
            success: success,
            danger: danger,
            secondary: secondary,
            disabled: disabled
        )
    }
    
    // MARK: - Dynamic Resolution

    /// Resolves the token per trait collection, so colors follow light/dark changes
    /// even when a view is not re-rendered (sheets, cached cells, UIKit bridges).
    private static func dynamic(_ token: KeyPath<Palette, Color>) -> Color {
        Color(uiColor: UIColor { trait in
            UIColor(trait.userInterfaceStyle == .dark ? dark[keyPath: token] : light[keyPath: token])
        })
    }

    // MARK: - Public Tokens

    public static var background: Color { dynamic(\.background) }
    public static var surface: Color { dynamic(\.surface) }
    public static var surface2: Color { dynamic(\.surface2) }
    public static var stroke: Color { dynamic(\.stroke) }
    public static var shadow: Color { dynamic(\.shadow) }
    public static var textPrimary: Color { dynamic(\.textPrimary) }
    public static var textSecondary: Color { dynamic(\.textSecondary) }
    public static var primary: Color { dynamic(\.primary) }
    public static var primaryMuted: Color { dynamic(\.primaryMuted) }
    public static var warning: Color { dynamic(\.warning) }
    public static var success: Color { dynamic(\.success) }
    public static var danger: Color { dynamic(\.danger) }
    public static var secondary: Color { dynamic(\.secondary) }
    public static var disabled: Color { dynamic(\.disabled) }
}
