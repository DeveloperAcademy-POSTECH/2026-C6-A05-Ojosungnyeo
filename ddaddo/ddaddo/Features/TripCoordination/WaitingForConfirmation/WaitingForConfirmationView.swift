//
//  WaitingForConfirmationView.swift
//  ddaddo
//
//  Created by sun on 11/1/26.
//

import ComposableArchitecture
import SwiftUI

struct WaitingForConfirmationView: View {
    let store: StoreOf<WaitingForConfirmationFeature>

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            confirmationGuide
            confirmationStatus
            Spacer(minLength: 0)
            bottomAction
        }
        .padding(.horizontal, DDSpacing.large)
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            await store.send(.onAppear).finish()
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }

    private var navigationBar: some View {
        ZStack {
            VStack(spacing: 0) {
                Text(store.tripTitle)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textPrimary)

                Text(store.tripDates)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
            }

            HStack {
                Button {
                    store.send(.backButtonTapped)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(DDColor.textPrimary)
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
        .frame(height: 51, alignment: .top)
    }

    private var confirmationGuide: some View {
        VStack(alignment: .leading, spacing: DDSpacing.small) {
            HStack(spacing: 2) {
                Text("친구 확정 기다리게따")
                    .ddTypography(.title24)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .semibold))
            }
            .foregroundStyle(DDColor.textPrimary)

            VStack(alignment: .leading, spacing: 0) {
                Text("내 그룹 조정은 확정되었어요.")
                Text("모든 친구가 확정하면 조정 결과를 확인할 수 있어요.")
            }
            .ddTypography(.label14)
            .foregroundStyle(Color(red: 96 / 255, green: 96 / 255, blue: 96 / 255))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var confirmationStatus: some View {
        VStack(spacing: 20) {
            HStack {
                Text("그룹 확정 현황")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)

                Spacer(minLength: 0)

                Text("\(store.confirmedCount)/\(store.members.count)명 확정")
                    .ddTypography(.labelEmphasis14)
                    .foregroundStyle(DDColor.actionPrimary)
            }

            HStack(alignment: .top, spacing: 6) {
                ForEach(store.members) { member in
                    memberStatus(member)
                }
            }
        }
        .padding(.horizontal, 19)
        .padding(.top, 19)
        .frame(height: 192, alignment: .top)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255), lineWidth: 1)
        }
        .padding(.top, 44)
    }

    private func memberStatus(_ member: WaitingForConfirmationFeature.Member) -> some View {
        VStack(spacing: 0) {
            DDMiniHeadAvatar(character: member.avatar, size: 50)

            Text(member.name)
                .ddTypography(.label14)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.top, 10)

            Text(member.isConfirmed ? "확정 완료" : "확정 대기")
                .ddTypography(.caption12)
                .foregroundStyle(
                    member.isConfirmed
                        ? DDColor.actionPrimary
                        : Color(red: 96 / 255, green: 96 / 255, blue: 96 / 255)
                )
                .padding(.top, 6)
        }
        .frame(width: 78)
    }

    private var bottomAction: some View {
        VStack(spacing: DDSpacing.small) {
            Text("모두 확정하면 조정 결과를 확인할 수 있어요.")
                .ddTypography(.eyebrow13)
                .foregroundStyle(Color(red: 96 / 255, green: 96 / 255, blue: 96 / 255))
                .frame(maxWidth: .infinity)

            Button {
                guard store.haveAllMembersConfirmed else { return }
                store.send(.completionButtonTapped)
            } label: {
                Text(
                    store.haveAllMembersConfirmed
                        ? "친구들의 확정 완료"
                        : "친구들의 확정 대기 중"
                )
                .ddTypography(.heading20)
                .foregroundStyle(
                    store.haveAllMembersConfirmed
                        ? DDColor.textOnPrimary
                        : DDColor.textPrimary
                )
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(
                    store.haveAllMembersConfirmed
                        ? DDColor.actionPrimary
                        : Color(red: 68 / 255, green: 68 / 255, blue: 68 / 255)
                )
                .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!store.haveAllMembersConfirmed)
        }
        .padding(.bottom, 11)
    }
}

#Preview {
    WaitingForConfirmationView(
        store: Store(initialState: WaitingForConfirmationFeature.State()) {
            WaitingForConfirmationFeature()
        }
    )
}
