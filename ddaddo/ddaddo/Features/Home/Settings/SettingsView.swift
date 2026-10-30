//
//  SettingsView.swift
//  ddaddo
//
//  Created by sun on 10/31/26.
//

import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    let store: StoreOf<SettingsFeature>
    @FocusState private var nicknameFocused: Bool

    var body: some View {
        ZStack {
            Group {
                switch store.screen {
                case .settings: settings
                case .nickname: nicknameEdit
                case .account: accountManagement
                case .withdrawal: withdrawalGuide
                case .complete: withdrawalComplete
                }
            }

            if store.isLogoutAlertPresented {
                confirmationScrim
                DDConfirmationAlert(
                    title: "로그아웃할까요?",
                    message: "로그아웃하면 로그인 화면으로 이동해요.",
                    cancelTitle: "취소",
                    confirmTitle: "로그아웃",
                    onCancel: { store.send(.logoutAlertDismissed) },
                    onConfirm: { store.send(.logoutConfirmed) }
                )
            } else if store.isWithdrawalAlertPresented {
                confirmationScrim
                DDConfirmationAlert(
                    title: "정말 탈퇴할까요?",
                    message: "탈퇴 후에는 이 계정으로 로그인할 수 없어요.",
                    cancelTitle: "돌아가기",
                    confirmTitle: "탈퇴하기",
                    confirmColor: DDColor.statusError,
                    onCancel: { store.send(.withdrawalAlertDismissed) },
                    onConfirm: { store.send(.withdrawalConfirmed) }
                )
            }
        }
        .background(DDColor.surfaceDefault.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task { store.send(.onAppear) }
        .alert("요청을 완료하지 못했어요", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.send(.errorDismissed) } })) {
            Button("확인") { store.send(.errorDismissed) }
        } message: { Text(store.errorMessage ?? "") }
    }

    private var confirmationScrim: some View {
        Color.black
            .opacity(0.62)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }

    private var settings: some View {
        VStack(spacing: 0) {
            header("닉네임 변경")
            card {
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(store.nickname.isEmpty ? "지구인" : store.nickname).ddTypography(.bodyEmphasis16)
                        Text("Apple 계정으로 로그인").ddTypography(.caption12).foregroundStyle(DDColor.textSecondary)
                    }
                    Spacer()
                    Button("닉네임 변경") { store.send(.nicknameEditTapped) }
                        .ddTypography(.captionEmphasis12)
                        .foregroundStyle(DDColor.textOnPrimary)
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(DDColor.actionPrimary).clipShape(.capsule)
                }
            }
            .padding(.top, 36)

            sectionTitle("앱 설정")
                .padding(.top, 24)
                .padding(.bottom, 4)
            card {
                HStack {
                    rowText("알림 설정", "여행 초대와 일정 소식을 받아요")
                    Spacer()
                    DDToggle(
                        isOn: Binding(
                            get: { store.isNotificationEnabled },
                            set: { store.send(.notificationToggled($0)) }
                        ),
                        accessibilityLabel: "알림 설정"
                    )
                }
            }

            sectionTitle("계정")
                .padding(.top, 32)
                .padding(.bottom, 4)
            Button { store.send(.accountManagementTapped) } label: {
                card { HStack { rowText("계정 관리", "로그인과 회원 탈퇴를 관리해요"); Spacer(); Image(systemName: "chevron.right") } }
            }.buttonStyle(.plain)
            Spacer()
        }.padding(.horizontal, 24)
    }

    private var nicknameEdit: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("닉네임 변경")
            VStack(alignment: .leading, spacing: 12) {
                Text("계정").ddTypography(.labelEmphasis14).foregroundStyle(DDColor.actionPrimary)
                Text("어떻게 불러드릴까따?").ddTypography(.title24).foregroundStyle(DDColor.textPrimary)
                Text("친구들에게 표시되는 이름을 바꿔요.").ddTypography(.label14).foregroundStyle(DDColor.textSecondary)
            }.padding(.top, 22)
            Text("닉네임").ddTypography(.label14).foregroundStyle(DDColor.textTertiary).padding(.top, 48)
            HStack {
                TextField("닉네임", text: Binding(get: { store.nicknameDraft }, set: { store.send(.nicknameChanged($0)) }))
                    .ddTypography(.bodyEmphasis16).focused($nicknameFocused)
                Text("\(store.nicknameDraft.count)/10").ddTypography(.caption12).foregroundStyle(DDColor.textTertiary)
            }
            .padding(.horizontal, 16).frame(height: 56).background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(store.nicknameError == nil ? DDColor.actionPrimary : DDColor.statusError) }
            Text(store.nicknameError ?? "2~10자로 입력해 주세요.")
                .ddTypography(.caption12).foregroundStyle(store.nicknameError == nil ? DDColor.textSecondary : DDColor.statusError).padding(.top, 12)
            Spacer()
            DDCTAButton(title: store.isSavingNickname ? "저장 중..." : "저장하기", isEnabled: nicknameSaveEnabled) { store.send(.saveNicknameTapped) }
                .padding(.bottom, 11)
        }.padding(.horizontal, 24)
    }

    private var accountManagement: some View {
        VStack(spacing: 0) {
            header("계정 관리")
            sectionTitle("로그인 정보")
                .padding(.top, 42)
                .padding(.bottom, 4)
            card { rowText("Apple로 로그인", "현재 연결된 계정") }
            sectionTitle("계정 작업")
                .padding(.top, 32)
                .padding(.bottom, 4)
            VStack(spacing: 0) {
                accountAction("로그아웃", "로그아웃 후 로그인 화면으로 이동해요", color: DDColor.textPrimary) { store.send(.logoutTapped) }
                Divider().overlay(DDColor.borderDefault)
                accountAction("회원 탈퇴", "계정 이용을 종료하고 정보를 정리해요", color: DDColor.statusError) { store.send(.withdrawalTapped) }
            }.padding(.horizontal, 16).background(DDColor.surfaceElevated).clipShape(.rect(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(DDColor.borderDefault) }
            Spacer()
        }.padding(.horizontal, 24)
    }

    private var withdrawalGuide: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("회원 탈퇴")
            Text("탈퇴 전에 확인해주세요")
                .ddTypography(.heading20)
                .tracking(0)
                .frame(height: 30, alignment: .topLeading)
                .padding(.top, 23)
            Text("계정 이용이 종료되며, 저장한 정보에 다시 접근할 수 없어요.")
                .ddTypography(.label14)
                .tracking(0)
                .foregroundStyle(DDColor.textSecondary)
                .frame(height: 42, alignment: .topLeading)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 0) {
                checklist("프로필과 계정 정보")
                Divider()
                    .overlay(DDColor.borderDefault)
                    .padding(.top, 11)
                checklist("저장한 여행 정보")
                    .padding(.top, 16)
                Divider()
                    .overlay(DDColor.borderDefault)
                    .padding(.top, 11)
                checklist("진행 중인 여행 참여 상태")
                    .padding(.top, 16)
                Text("탈퇴 후에는 계정을 복구하기 어려울 수 있어요.")
                    .ddTypography(.caption12)
                    .tracking(0)
                    .foregroundStyle(DDColor.textSecondary)
                    .padding(.leading, 2)
                    .padding(.top, 27)
            }
            .padding(.top, 24)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(DDColor.borderDefault) }
            .padding(.top, 21)
            Button { store.send(.withdrawalAcknowledgementToggled) } label: {
                HStack(spacing: 12) {
                    withdrawalCheckbox
                    Text("탈퇴 안내를 확인했어요")
                        .ddTypography(.label14)
                        .tracking(0)
                        .foregroundStyle(DDColor.textPrimary)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 28)
            Spacer()
            DDCTAButton(title: store.isWithdrawing ? "탈퇴 처리 중..." : "탈퇴 진행", isEnabled: store.hasAcknowledgedWithdrawal && !store.isWithdrawing) { store.send(.withdrawalProceedTapped) }
            Button("취소") { store.send(.withdrawalCancelTapped) }.ddTypography(.labelEmphasis14).foregroundStyle(DDColor.textSecondary).frame(maxWidth: .infinity).padding(.vertical, 12)
        }.padding(.horizontal, 24)
    }

    private var withdrawalComplete: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("DDWithdrawalCompleteMascot").resizable().scaledToFit().frame(width: 144, height: 114)
            Text("탈퇴가 완료됐어요").ddTypography(.title24).padding(.top, 0)
            Text("함께해주셔서 고마워요.").ddTypography(.body16).foregroundStyle(DDColor.textSecondary).padding(.top, 10)
            Spacer()
            DDCTAButton(title: "처음 화면으로") { store.send(.returnToLoginTapped) }.padding(.bottom, 11)
        }.padding(.horizontal, 16)
    }

    private func header(_ title: String) -> some View {
        Button { store.send(.backButtonTapped) } label: {
            HStack(spacing: 10) { Image(systemName: "chevron.left"); Text(title).ddTypography(.title24); Spacer() }
                .foregroundStyle(DDColor.textPrimary).frame(height: 61)
        }.buttonStyle(.plain)
    }
    private func sectionTitle(_ title: String) -> some View { Text(title).ddTypography(.labelEmphasis14).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4) }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View { content().padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 74, alignment: .leading).background(DDColor.surfaceElevated).clipShape(.rect(cornerRadius: 18)).overlay { RoundedRectangle(cornerRadius: 18).stroke(DDColor.borderDefault) } }
    private func rowText(_ title: String, _ subtitle: String) -> some View { VStack(alignment: .leading, spacing: 4) { Text(title).ddTypography(.bodyEmphasis16); Text(subtitle).ddTypography(.caption12).foregroundStyle(DDColor.textSecondary) } }
    private func accountAction(_ title: String, _ subtitle: String, color: Color, action: @escaping () -> Void) -> some View { Button(action: action) { HStack { rowText(title, subtitle).foregroundStyle(color); Spacer(); Image(systemName: "chevron.right").foregroundStyle(DDColor.textPrimary) }.frame(height: 76) }.buttonStyle(.plain) }
    private var withdrawalCheckbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(store.hasAcknowledgedWithdrawal ? DDColor.actionPrimary : DDColor.surfaceElevated)
            RoundedRectangle(cornerRadius: 5)
                .stroke(store.hasAcknowledgedWithdrawal ? DDColor.actionPrimary : DDColor.borderDefault)
            if store.hasAcknowledgedWithdrawal {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DDColor.surfaceDefault)
            }
        }
        .frame(width: 22, height: 22)
    }
    private func checklist(_ text: String) -> some View { Text("•  \(text)").ddTypography(.body16).tracking(0).frame(height: 24) }
    private var nicknameSaveEnabled: Bool { let value = store.nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines); return (2...10).contains(value.count) && value != store.nickname && !store.isSavingNickname }
}
