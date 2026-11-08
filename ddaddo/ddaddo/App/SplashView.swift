//
//  SplashView.swift
//  ddaddo
//
//  Created by sun on 11/8/26.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                Color(red: 0.06, green: 0.06, blue: 0.06)

                Image("splash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(proxy.size.width * 0.6, 250))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SplashView()
}
