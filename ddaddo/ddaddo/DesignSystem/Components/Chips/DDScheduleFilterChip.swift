//
//  DDScheduleFilterChip.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct DDScheduleFilterChip: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .ddTypography(.label14)
                .foregroundStyle(
                    isSelected ? DDColor.textOnPrimary : DDColor.textSecondary
                )
                .padding(.horizontal, 18)
                .frame(minHeight: 34)
                .background(
                    isSelected ? DDColor.surfaceSelected : DDColor.surfaceControl
                )
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
