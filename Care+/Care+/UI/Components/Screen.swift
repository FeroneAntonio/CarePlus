//
//  Screen.swift
//  Care+
//

import SwiftUI

struct Screen<Content: View>: View {
    @Environment(\.colorScheme) private var scheme

    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            // Background coerente sempre
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Spacer(minLength: 24)
                    content
                }
                .padding()
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 16)
            }
        }
        // toolbar coerente con lo schema corrente
        .toolbarColorScheme(scheme == .dark ? .dark : .light, for: .navigationBar)
        // evita che alcune view “vedano” un background diverso in stack/sheet
        .background(AppTheme.background.ignoresSafeArea())
    }
}
