//
//  LoadingView.swift
//  ddaddo
//

import SwiftUI

struct LoadingView: View {
    var message: String = "분석 중..."

    var body: some View {
        ZStack {
            Color(red: 15 / 255, green: 15 / 255, blue: 15 / 255)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Image("DDLoadingMascots")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 99, height: 129)
                    .accessibilityHidden(true)

                Text(message)
                    .ddTypography(.heading20)
                    .foregroundStyle(.white)
                    .frame(width: 346, height: 24)
                    .multilineTextAlignment(.center)
            }
            .offset(y: 2)
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

#Preview {
    LoadingView()
}
