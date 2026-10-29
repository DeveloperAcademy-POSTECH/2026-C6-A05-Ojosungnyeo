//
//  InviteCodeModal.swift
//  ddaddo
//
//  Created by sun on 10/30/26.
//

import SwiftUI

struct InviteCodeModal: View {
    @Binding var code: String
    let cancelAction: () -> Void
    let joinAction: () -> Void

    @FocusState private var isCodeFieldFocused: Bool

    private var isJoinEnabled: Bool {
        code.count == 6
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text("초대 코드를 입력하세요")
                    .font(.custom("Pretendard-SemiBold", size: 17, relativeTo: .headline))
                    .foregroundStyle(DDColor.textPrimary)

                Text("친구로부터 전달받은\n6자리 숫자를 입력해 주세요.")
                    .font(.custom("Pretendard-Regular", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color(red: 204 / 255, green: 204 / 255, blue: 204 / 255))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                codeFields
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)

            separator

            HStack(spacing: 0) {
                actionButton(
                    title: "취소",
                    foregroundColor: Color(
                        red: 204 / 255,
                        green: 204 / 255,
                        blue: 204 / 255
                    ),
                    action: cancelAction
                )

                Rectangle()
                    .fill(Color(red: 72 / 255, green: 72 / 255, blue: 72 / 255))
                    .frame(width: 0.5, height: 48)

                actionButton(
                    title: "참여하기",
                    foregroundColor: isJoinEnabled
                        ? DDColor.surfaceSelected
                        : Color(red: 119 / 255, green: 119 / 255, blue: 119 / 255),
                    action: joinAction
                )
                .disabled(!isJoinEnabled)
            }
            .frame(height: 48)
        }
        .frame(width: 286)
        .background(Color(red: 37 / 255, green: 37 / 255, blue: 37 / 255))
        .clipShape(.rect(cornerRadius: 14))
        .onAppear {
            isCodeFieldFocused = true
        }
    }

    private var codeFields: some View {
        HStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { index in
                let digit = digit(at: index)
                let isActive = code.count < 6 && index == code.count

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 25 / 255, green: 25 / 255, blue: 25 / 255))

                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isActive
                                ? DDColor.surfaceSelected
                                : Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255),
                            lineWidth: 1
                        )

                    if let digit {
                        Text(String(digit))
                            .ddTypography(.heading20)
                            .foregroundStyle(DDColor.textPrimary)
                    } else if isActive {
                        Rectangle()
                            .fill(DDColor.surfaceSelected)
                            .frame(width: 1, height: 22)
                    }
                }
                .frame(width: 36, height: 44)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isCodeFieldFocused = true
        }
        .overlay {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isCodeFieldFocused)
                .opacity(0.001)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color(red: 72 / 255, green: 72 / 255, blue: 72 / 255))
            .frame(height: 0.5)
    }

    private func digit(at index: Int) -> Character? {
        guard index < code.count else { return nil }
        return code[code.index(code.startIndex, offsetBy: index)]
    }

    private func actionButton(
        title: String,
        foregroundColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Pretendard-SemiBold", size: 17, relativeTo: .headline))
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        InviteCodeModal(
            code: .constant("123"),
            cancelAction: {},
            joinAction: {}
        )
    }
    .preferredColorScheme(.dark)
}
