//
//  RouteMemberProfile.swift
//  ddaddo
//

import SwiftUI

struct RouteMemberProfile: View {
    static let height: CGFloat = 63

    let member: TripMember
    let name: String
    let isCurrentUser: Bool
    let isEmphasized: Bool

    var body: some View {
        VStack(spacing: DDSpacing.xSmall) {
            DDMiniHeadAvatar(character: member.routeAvatarCharacter, size: 37)
                .opacity(isEmphasized ? 1 : 0.35)
                .padding(3)
                .overlay {
                    if isCurrentUser {
                        Circle()
                            .stroke(DDColor.actionPrimary, lineWidth: 2)
                    }
                }

            Text(name)
                .ddTypography(.caption12)
                .foregroundStyle(DDColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
                .frame(height: 16)
                .opacity(isEmphasized ? 1 : 0.35)
        }
        .frame(width: 80, height: Self.height)
    }
}

#Preview("루트 프로필") {
    HStack(spacing: DDSpacing.xSmall) {
        RouteMemberProfile(member: .tae, name: "나", isCurrentUser: true, isEmphasized: true)
        RouteMemberProfile(member: .header, name: "별사탕", isCurrentUser: false, isEmphasized: true)
        RouteMemberProfile(member: .grae, name: "우주여행가나다라마바", isCurrentUser: false, isEmphasized: true)
        RouteMemberProfile(member: .juni, name: "밤하늘", isCurrentUser: false, isEmphasized: false)
    }
    .padding(DDSpacing.large)
    .background(DDColor.surfaceDefault)
    .preferredColorScheme(.dark)
}
