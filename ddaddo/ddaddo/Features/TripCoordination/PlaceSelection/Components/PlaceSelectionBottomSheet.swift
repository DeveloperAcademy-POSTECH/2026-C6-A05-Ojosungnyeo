//
//  PlaceSelectionBottomSheet.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct PlaceSelectionBottomSheet: View {
    let isExpanded: Bool
    let searchButtonTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 80, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, DDSpacing.large)

            avatarGroup
                .padding(.top, isExpanded ? DDSpacing.large : 40)

            if isExpanded {
                Text("아직 추가한 장소가 없따...")
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.top, DDSpacing.large)

                Text("도쿄에서 꼭 가고 싶은 장소를\n8개까지 추가해 보세요.")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineSpacing(0)
                    .padding(.top, DDSpacing.medium)

                Spacer(minLength: DDSpacing.large)

                DDCTAButton(title: "장소 검색하기", action: searchButtonTapped)
                    .padding(.bottom, 45)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? 322 : 156)
        .background(DDColor.surfaceDefault)
        .clipShape(
            .rect(
                topLeadingRadius: 40,
                topTrailingRadius: 40
            )
        )
    }

    private var avatarGroup: some View {
        HStack(spacing: DDSpacing.xSmall) {
            DDMiniHeadAvatar(character: .tae, size: 40)
            DDMiniHeadAvatar(character: .header, size: 40)
            DDMiniHeadAvatar(character: .grae, size: 40)
            DDMiniHeadAvatar(character: .juni, size: 40)
        }
    }
}
