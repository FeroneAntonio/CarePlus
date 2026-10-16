//
//  Avatar.swift
//  Care+
//

import SwiftUI

struct Avatar: View {
    let photo: Data?

    var body: some View {
        Group {
            if let photo, let ui = UIImage(data: photo) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .imageScale(.large)
                    .foregroundStyle(AppTheme.primary.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 56, height: 56)
        .background(AppTheme.primary.opacity(0.12))
        .clipShape(Circle())
        .overlay(Circle().stroke(AppTheme.primary.opacity(0.25), lineWidth: 1))
        .overlay(
            Circle().fill(
                LinearGradient(
                    colors: [AppTheme.primary.opacity(0.08), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        )
        .clipped()
    }
}
