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

            VStack(spacing: 14) {
                Image("DDLoadingMascots")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 192, height: 128)
                    .clipped()
                    .accessibilityHidden(true)

                Text(message)
                    .ddTypography(.heading20)
                    .foregroundStyle(.white)
                    .frame(width: 346, height: 24)
                    .multilineTextAlignment(.center)
            }
            .offset(y: 8)
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

#Preview {
    LoadingView()
}
