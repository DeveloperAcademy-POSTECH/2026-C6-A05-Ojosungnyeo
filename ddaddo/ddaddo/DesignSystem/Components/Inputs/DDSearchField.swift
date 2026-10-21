//
//  DDSearchField.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct DDSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: DDSpacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DDColor.iconDefault)

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .foregroundStyle(DDColor.textSecondary)
            )
            .ddTypography(.body16)
            .foregroundStyle(DDColor.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 41)
        .background(DDColor.surfaceElevated)
        .clipShape(.capsule)
        .overlay {
            Capsule()
                .stroke(DDColor.borderSubtle, lineWidth: 1)
        }
    }
}

#Preview {
    DDSearchField(
        placeholder: "도시/지역 이름 (예: 도쿄)",
        text: .constant("")
    )
    .padding()
    .background(DDColor.surfaceDefault)
}
