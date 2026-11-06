//
//  DDMemberProfile.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct DDMemberProfile: View {
    let name: String
    let status: String
    let character: DDMiniHeadAvatar.Character

    var body: some View {
        VStack(spacing: DDSpacing.xSmall) {
            DDMiniHeadAvatar(character: character)

            Text(name)
                .ddTypography(.labelEmphasis14)
                .foregroundStyle(DDColor.textPrimary)

            Text(status)
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textSecondary)
        }
        .multilineTextAlignment(.center)
    }
}
