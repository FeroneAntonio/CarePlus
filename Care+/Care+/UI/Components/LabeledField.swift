//
//  LabeledField.swift
//  Care+
//

import SwiftUI
import UIKit

struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            ZStack(alignment: .leading) {
                // Placeholder
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }

                Group {
                    if isSecure {
                        SecureField("", text: $text)
                            .focused($isFocused)
                    } else {
                        TextField("", text: $text)
                            .focused($isFocused)
                    }
                }
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .foregroundStyle(AppTheme.textPrimary)
                .tint(AppTheme.primary)
            }
            .background(AppTheme.surface.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? AppTheme.primary : AppTheme.secondary.opacity(0.32), lineWidth: 1)
            )
        }
    }
}
