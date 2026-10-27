//
//  PlaceGroupAdjustmentView.swift
//  ddaddo
//

import SwiftUI

struct PlaceGroupAdjustmentView: View {
    var showsFriendPicker = false

    private let groups: [PlaceGroup] = [
        PlaceGroup(
            title: "도쿄역 쇼핑 코스",
            placeCount: 4,
            members: [
                GroupMember(name: "나", character: .tae),
                GroupMember(name: "헤더", character: .header)
            ]
        ),
        PlaceGroup(
            title: "치이카와 뮤지엄 코스",
            placeCount: 3,
            members: [
                GroupMember(name: "주니", character: .grae),
                GroupMember(name: "그레", character: .juni)
            ]
        )
    ]

    var body: some View {
        ZStack {
            screenContent

            if showsFriendPicker {
                friendPickerOverlay
            }
        }
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var screenContent: some View {
        VStack(spacing: DDSpacing.zero) {
            tripNavigation
            groupHeading

            ScrollView {
                LazyVStack(spacing: DDSpacing.large) {
                    ForEach(groups) { group in
                        groupCard(group)
                    }
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, DDSpacing.large)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: DDSpacing.zero) {
            DDCTAButton(title: "다음으로", action: {})
                .padding(.horizontal, DDSpacing.large)
                .padding(.top, 9)
                .padding(.bottom, 11)
                .background(DDColor.surfaceDefault)
        }
    }

    private var tripNavigation: some View {
        ZStack(alignment: .top) {
            VStack(spacing: DDSpacing.zero) {
                Text("도쿄 여행")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textPrimary)

                Text("11월 22일 ~ 25일")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
            }

            HStack {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 25, weight: .regular))
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(.rect)
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 24, weight: .regular))
                        .frame(width: 44, height: 44, alignment: .trailing)
                        .contentShape(.rect)
                }
            }
            .foregroundStyle(DDColor.textPrimary)
            .padding(.horizontal, DDSpacing.large)
        }
        .frame(height: 51, alignment: .top)
    }

    private var groupHeading: some View {
        HStack(spacing: DDSpacing.xSmall) {
            Text("그룹을 조정하게따")
                .font(
                    .custom(
                        "Pretendard-SemiBold",
                        size: 24,
                        relativeTo: .title2
                    )
                )

            Image(systemName: "bolt.fill")
                .font(.system(size: 23, weight: .semibold))

            Spacer(minLength: DDSpacing.zero)
        }
        .foregroundStyle(DDColor.textPrimary)
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 80, alignment: .top)
    }

    private func groupCard(_ group: PlaceGroup) -> some View {
        VStack(alignment: .leading, spacing: DDSpacing.zero) {
            Text(group.title)
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)

            Text("방문 장소 \(group.placeCount)곳")
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textSecondary)

            HStack(alignment: .top, spacing: DDSpacing.small) {
                ForEach(group.members) { member in
                    memberView(member)
                }

                addFriendButton
            }
            .padding(.top, DDSpacing.small)
        }
        .padding(.horizontal, DDSpacing.xLarge)
        .padding(.top, DDSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 153, maxHeight: 153, alignment: .topLeading)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }

    private func memberView(_ member: GroupMember) -> some View {
        VStack(spacing: DDSpacing.xSmall) {
            DDMiniHeadAvatar(character: member.character, size: 40)

            Text(member.name)
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textPrimary)
        }
    }

    private var addFriendButton: some View {
        Button(action: {}) {
            ZStack {
                Circle()
                    .fill(DDColor.surfaceDefault)

                Circle()
                    .stroke(
                        DDColor.borderDefault,
                        style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                    )

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(DDColor.textPrimary)
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }

    private var friendPickerOverlay: some View {
        ZStack {
            Color(red: 68 / 255, green: 68 / 255, blue: 68 / 255)
                .opacity(0.5)
                .ignoresSafeArea()

            friendPickerDialog
        }
    }

    private var friendPickerDialog: some View {
        VStack(alignment: .leading, spacing: DDSpacing.zero) {
            VStack(alignment: .leading, spacing: 3) {
                Text("함께할 친구 추가")
                    .ddTypography(.heading20)
                    .foregroundStyle(DDColor.textPrimary)

                Text("여행 그룹에 초대할 친구를 선택하세요.")
                    .font(
                        .custom(
                            "Pretendard-Regular",
                            size: 13,
                            relativeTo: .footnote
                        )
                    )
                    .foregroundStyle(DDColor.textSecondary)
            }
            .padding(.horizontal, DDSpacing.small)
            .frame(height: 52, alignment: .topLeading)

            VStack(spacing: DDSpacing.small) {
                friendSelectionRow(name: "그레")
                friendSelectionRow(name: "주니")
            }
            .padding(.top, 26)

            HStack(spacing: 14) {
                dialogButton(title: "취소", style: .secondary)
                dialogButton(title: "친구 추가", style: .primary)
            }
            .padding(.top, DDSpacing.xxLarge)
        }
        .padding(.horizontal, DDSpacing.large)
        .padding(.top, DDSpacing.large)
        .padding(.bottom, 20)
        .frame(width: 354, height: 310, alignment: .top)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderSubtle, lineWidth: 1)
        }
    }

    private func friendSelectionRow(name: String) -> some View {
        HStack(spacing: DDSpacing.small) {
            Text(name)
                .font(
                    .custom(
                        "Pretendard-Regular",
                        size: 15,
                        relativeTo: .subheadline
                    )
                )
                .foregroundStyle(DDColor.textPrimary)

            Spacer()

            ZStack {
                Circle()
                    .fill(DDColor.actionPrimary)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DDColor.textOnPrimary)
            }
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 48)
        .background(DDColor.surfaceControl)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }

    private enum DialogButtonStyle: Equatable {
        case primary
        case secondary
    }

    private func dialogButton(
        title: String,
        style: DialogButtonStyle
    ) -> some View {
        Button(action: {}) {
            Text(title)
                .font(
                    .custom(
                        "Pretendard-SemiBold",
                        size: 15,
                        relativeTo: .subheadline
                    )
                )
                .foregroundStyle(
                    style == .primary ? DDColor.textOnPrimary : DDColor.textPrimary
                )
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    style == .primary ? DDColor.actionPrimary : DDColor.actionSecondary
                )
                .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct PlaceGroup: Identifiable {
    let id = UUID()
    let title: String
    let placeCount: Int
    let members: [GroupMember]
}

private struct GroupMember: Identifiable {
    let id = UUID()
    let name: String
    let character: DDMiniHeadAvatar.Character
}

#Preview("그룹 조정") {
    PlaceGroupAdjustmentView()
}

#Preview("함께할 친구 선택 팝업") {
    PlaceGroupAdjustmentView(showsFriendPicker: true)
}
