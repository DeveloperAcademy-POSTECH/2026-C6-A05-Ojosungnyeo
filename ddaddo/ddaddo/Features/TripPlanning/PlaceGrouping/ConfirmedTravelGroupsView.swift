//
//  ConfirmedTravelGroupsView.swift
//  ddaddo
//

import SwiftUI

struct ConfirmedTravelGroupsView: View {
    var showsExpandedCourse = false

    private let courses: [ConfirmedTravelCourse] = [
        ConfirmedTravelCourse(
            title: "도쿄역 쇼핑 코스",
            placeCount: 4,
            members: [
                ConfirmedTravelMember(name: "나", character: .tae),
                ConfirmedTravelMember(name: "헤더", character: .header)
            ],
            time: "22일 10:00 ~ 14:00",
            places: "TK 빈티지샵, HABARI 외 2곳"
        ),
        ConfirmedTravelCourse(title: "치이카와 뮤지엄 코스", placeCount: 3),
        ConfirmedTravelCourse(title: "어쩌구 코스", placeCount: 2),
        ConfirmedTravelCourse(title: "어쩌구 코스", placeCount: 2)
    ]

    var body: some View {
        VStack(spacing: DDSpacing.zero) {
            tripNavigation
            confirmationHeading

            ScrollView {
                LazyVStack(spacing: DDSpacing.medium) {
                    ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                        courseCard(
                            course,
                            isExpanded: showsExpandedCourse && index == 0
                        )
                    }
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, DDSpacing.large)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: DDSpacing.zero) {
            DDCTAButton(title: "전체 일정에 담기", action: {})
                .padding(.horizontal, DDSpacing.large)
                .padding(.top, 9)
                .padding(.bottom, 11)
                .background(DDColor.surfaceDefault)
        }
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
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
            }
            .foregroundStyle(DDColor.textPrimary)
            .padding(.horizontal, DDSpacing.large)
        }
        .frame(height: 51, alignment: .top)
    }

    private var confirmationHeading: some View {
        VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
            HStack(spacing: DDSpacing.small) {
                Text("여행 그룹이 확정돼따")
                    .ddTypography(.title24)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 23, weight: .semibold))
            }
            .foregroundStyle(DDColor.textPrimary)

            Text("모든 친구들의 취향을 반영하여\n도쿄 여행 일정이 생성되었어요.")
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textSecondary)
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 93, maxHeight: 93, alignment: .topLeading)
    }

    private func courseCard(
        _ course: ConfirmedTravelCourse,
        isExpanded: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DDSpacing.zero) {
            courseSummary(course, isExpanded: isExpanded)

            if isExpanded {
                expandedCourseDetails(course)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, DDSpacing.large)
        .frame(
            maxWidth: .infinity,
            minHeight: isExpanded ? 218 : 76,
            maxHeight: isExpanded ? 218 : 76,
            alignment: .topLeading
        )
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: DDRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: DDRadius.medium)
                .stroke(DDColor.borderDefault, lineWidth: 0.5)
        }
    }

    private func courseSummary(
        _ course: ConfirmedTravelCourse,
        isExpanded: Bool
    ) -> some View {
        HStack(spacing: DDSpacing.small) {
            VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
                Text(course.title)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)

                Text("방문 장소 \(course.placeCount)곳")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
            }

            Spacer(minLength: DDSpacing.small)

            Image(isExpanded ? "DDCourseDisclosureUp" : "DDCourseDisclosureDown")
                .frame(width: 24, height: 24)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .frame(height: 44, alignment: .top)
    }

    private func expandedCourseDetails(_ course: ConfirmedTravelCourse) -> some View {
        VStack(alignment: .leading, spacing: DDSpacing.small) {
            HStack(alignment: .top, spacing: DDSpacing.small) {
                ForEach(course.members) { member in
                    VStack(spacing: DDSpacing.xSmall) {
                        DDMiniHeadAvatar(character: member.character, size: 40)

                        Text(member.name)
                            .ddTypography(.label14)
                            .foregroundStyle(DDColor.textPrimary)
                    }
                }
            }
            .frame(height: 64, alignment: .top)

            Rectangle()
                .fill(DDColor.surfaceControl)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: DDSpacing.zero) {
                Text(course.time)
                Text(course.places)
            }
            .ddTypography(.label14)
            .foregroundStyle(DDColor.textPrimary)
        }
        .frame(height: 142, alignment: .topLeading)
    }
}

private struct ConfirmedTravelCourse: Identifiable {
    let id = UUID()
    let title: String
    let placeCount: Int
    var members: [ConfirmedTravelMember] = []
    var time = ""
    var places = ""
}

private struct ConfirmedTravelMember: Identifiable {
    let id = UUID()
    let name: String
    let character: DDMiniHeadAvatar.Character
}

#Preview("확정 그룹 목록") {
    ConfirmedTravelGroupsView()
}

#Preview("확정 그룹 목록 - 펼침") {
    ConfirmedTravelGroupsView(showsExpandedCourse: true)
}
