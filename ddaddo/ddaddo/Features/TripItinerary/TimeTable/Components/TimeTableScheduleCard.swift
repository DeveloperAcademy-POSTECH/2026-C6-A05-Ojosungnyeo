//
//  TimeTableScheduleCard.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import SwiftUI

struct TimeTableScheduleCard: View {
    let schedule: TimeTableSchedule
    let course: TimeTableCourse
    let dayOfMonth: Int
    let tripMembers: [TripMember]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: DDSpacing.small) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(course.title)
                            .ddTypography(.bodyEmphasis16)
                            .foregroundStyle(DDColor.textPrimary)
                            .lineLimit(1)

                        Text("방문 장소 \(course.placeCount)곳")
                            .ddTypography(.label14)
                            .foregroundStyle(DDColor.textSecondary)
                    }

                    Spacer(minLength: 0)

                    if course.kind(among: tripMembers) == .separate {
                        memberAvatars
                    }
                }

                Spacer(minLength: DDSpacing.xSmall)

                Text(schedule.timing.displayText(
                    dayOfMonth: dayOfMonth,
                    durationMinutes: course.durationMinutes
                ))
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textPrimary)

                Text(course.placesSummary)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DDSpacing.xLarge)
            .padding(.vertical, DDSpacing.large)
            .frame(maxWidth: .infinity, minHeight: 126, maxHeight: 126, alignment: .leading)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DDColor.textTertiary, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var memberAvatars: some View {
        HStack(spacing: -12) {
            ForEach(course.members, id: \.self) { member in
                DDMiniHeadAvatar(character: member.timeTableAvatarCharacter, size: 40)
            }
        }
    }
}

private extension TripMember {
    var timeTableAvatarCharacter: DDMiniHeadAvatar.Character {
        switch self {
        case .tae: .tae
        case .header: .header
        case .grae: .grae
        case .juni: .juni
        }
    }
}
