//
//  PlaceGroupResultView.swift
//  ddaddo
//

import SwiftUI

struct PlaceGroupResultView: View {
    private let groups: [PlaceGroupResult] = [
        PlaceGroupResult(
            title: "도쿄역 쇼핑 코스",
            placeCount: 4,
            members: [
                PlaceGroupResultMember(name: "나", character: .tae),
                PlaceGroupResultMember(name: "헤더", character: .header)
            ],
            time: "22일 10:00 ~ 14:00",
            places: "TK 빈티지샵, HABARI 외 2곳"
        ),
        PlaceGroupResult(
            title: "치이카와 뮤지엄 코스",
            placeCount: 3,
            members: [
                PlaceGroupResultMember(name: "주니", character: .grae),
                PlaceGroupResultMember(name: "그레", character: .juni)
            ],
            time: "22일 10:00 ~ 14:00",
            places: "치이카와 뮤지엄, CH 굿즈샵 외 1곳"
        )
    ]

    var body: some View {
        VStack(spacing: DDSpacing.zero) {
            tripNavigation
            resultHeading

            ScrollView {
                LazyVStack(spacing: DDSpacing.medium) {
                    resultMap

                    ForEach(groups) { group in
                        resultCard(group)
                    }
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, DDSpacing.large)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: DDSpacing.zero) {
            HStack(spacing: DDSpacing.small) {
                DDCTAButton(title: "공유하기", style: .secondary, action: {})
                DDCTAButton(title: "다음으로", action: {})
            }
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
                    .ddTypography(.labelEmphasis14)
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

    private var resultHeading: some View {
        VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
            HStack(spacing: 2) {
                Text("조정 결과따")
                    .ddTypography(.title24)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 23, weight: .semibold))
            }
            .foregroundStyle(DDColor.textPrimary)

            Text("조정 결과를 바로 확인하세요.")
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textSecondary)
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 84, maxHeight: 84, alignment: .topLeading)
    }

    private var resultMap: some View {
        Image("DDPlaceGroupingResultMap")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 191)
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DDColor.borderSubtle, lineWidth: 1)
            }
            .accessibilityLabel("그룹별 위치가 표시된 지도")
    }

    private func resultCard(_ group: PlaceGroupResult) -> some View {
        VStack(alignment: .leading, spacing: DDSpacing.zero) {
            HStack(alignment: .top, spacing: DDSpacing.small) {
                VStack(alignment: .leading, spacing: DDSpacing.zero) {
                    Text(group.title)
                        .ddTypography(.bodyEmphasis16)
                        .foregroundStyle(DDColor.textPrimary)

                    Text("방문 장소 \(group.placeCount)곳")
                        .ddTypography(.label14)
                        .foregroundStyle(DDColor.textSecondary)
                }

                Spacer(minLength: DDSpacing.small)

                HStack(alignment: .top, spacing: DDSpacing.small) {
                    ForEach(group.members) { member in
                        resultMember(member)
                    }
                }
            }
            .frame(height: 78, alignment: .top)

            Rectangle()
                .fill(DDColor.surfaceControl)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: DDSpacing.zero) {
                Text(group.time)
                Text(group.places)
            }
            .ddTypography(.label14)
            .foregroundStyle(DDColor.textPrimary)
            .padding(.top, DDSpacing.small)
        }
        .padding(.horizontal, DDSpacing.xLarge)
        .padding(.top, DDSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 162, maxHeight: 162, alignment: .topLeading)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }

    private func resultMember(_ member: PlaceGroupResultMember) -> some View {
        VStack(spacing: DDSpacing.xSmall) {
            DDMiniHeadAvatar(character: member.character, size: 40)

            Text(member.name)
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textPrimary)
        }
    }
}

private struct PlaceGroupResult: Identifiable {
    let id = UUID()
    let title: String
    let placeCount: Int
    let members: [PlaceGroupResultMember]
    let time: String
    let places: String
}

private struct PlaceGroupResultMember: Identifiable {
    let id = UUID()
    let name: String
    let character: DDMiniHeadAvatar.Character
}

#Preview("조정 결과") {
    PlaceGroupResultView()
}
