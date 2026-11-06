//
//  SelectedPlaceBottomSheet.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI
import UIKit

struct SelectedPlaceBottomSheet: View {
    let place: PlaceDetails
    let isLoading: Bool
    let canAdd: Bool
    let isAlreadyAdded: Bool
    let fallbackImageName: String?
    let bottomSafeAreaInset: CGFloat
    let closeButtonTapped: () -> Void
    let addButtonTapped: () -> Void

    @State private var isCopyToastPresented = false

    init(
        place: PlaceDetails,
        isLoading: Bool,
        canAdd: Bool,
        isAlreadyAdded: Bool,
        fallbackImageName: String?,
        bottomSafeAreaInset: CGFloat = 34,
        closeButtonTapped: @escaping () -> Void,
        addButtonTapped: @escaping () -> Void
    ) {
        self.place = place
        self.isLoading = isLoading
        self.canAdd = canAdd
        self.isAlreadyAdded = isAlreadyAdded
        self.fallbackImageName = fallbackImageName
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.closeButtonTapped = closeButtonTapped
        self.addButtonTapped = addButtonTapped
    }

    var body: some View {
        ZStack(alignment: .top) {
            DDColor.surfaceDefault

            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 142, height: 4)
                .padding(.top, 19)

            HStack {
                Button(action: closeButtonTapped) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(DDColor.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(DDColor.surfaceElevated)
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("장소 상세 닫기")

                Spacer(minLength: DDSpacing.small)

                Button(isAlreadyAdded ? "추가됨" : "추가하기", action: addButtonTapped)
                    .font(.custom("Pretendard-Bold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(canAdd ? DDColor.textOnPrimary : DDColor.textTertiary)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(canAdd ? DDColor.actionPrimary : DDColor.surfaceControl)
                    .clipShape(.capsule)
                    .disabled(!canAdd)
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .ddTypography(.heading18)
                        .foregroundStyle(DDColor.textPrimary)
                        .lineLimit(1)

                    ratingView
                }
                .frame(height: 52, alignment: .top)

                Text(place.category)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(height: 20, alignment: .topLeading)

                Button {
                    UIPasteboard.general.string = place.address
                    withAnimation(.easeOut(duration: 0.2)) {
                        isCopyToastPresented = true
                    }
                } label: {
                    HStack(alignment: .bottom, spacing: DDSpacing.xSmall) {
                        Text(place.address)
                            .ddTypography(.label14)
                            .foregroundStyle(DDColor.textTertiary)
                            .underline()
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Image(systemName: "document.on.document")
                            .font(.system(size: 14))
                            .foregroundStyle(DDColor.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("주소 복사")
                .accessibilityHint("클립보드에 장소 주소를 복사합니다")
                .frame(height: 50, alignment: .topLeading)

                photoStrip
                    .padding(.top, DDSpacing.small)
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, 60)

            if isLoading {
                ProgressView()
                    .tint(DDColor.actionPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 355 + bottomSafeAreaInset)
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40
            )
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
        .overlay(alignment: .bottom) {
            if isCopyToastPresented {
                Text("주소가 복사되었어요")
                    .font(.custom("Pretendard-Regular", size: 15))
                    .foregroundStyle(
                        Color(
                            red: 123 / 255,
                            green: 123 / 255,
                            blue: 123 / 255
                        )
                    )
                    .frame(width: 240, height: 34)
                    .background(
                        Color(
                            red: 37 / 255,
                            green: 37 / 255,
                            blue: 37 / 255
                        )
                    )
                    .clipShape(.capsule)
                    .overlay {
                        Capsule()
                            .stroke(
                                Color(
                                    red: 72 / 255,
                                    green: 72 / 255,
                                    blue: 72 / 255
                                ),
                                lineWidth: 1.25
                            )
                    }
                    .padding(.bottom, max(12, bottomSafeAreaInset - 5))
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .ddFillBottomSheetToScreenEdge()
        .task(id: isCopyToastPresented) {
            guard isCopyToastPresented else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                isCopyToastPresented = false
            }
        }
    }

    private var ratingView: some View {
        HStack(spacing: DDSpacing.xSmall) {
            Text(place.rating > 0 ? place.rating.formatted(.number.precision(.fractionLength(1))) : "-")

            HStack(spacing: 1) {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: Double(value) <= place.rating ? "star.fill" : "star")
                }
            }

            Text("(\(place.ratingCount))")
        }
        .font(.system(size: 14))
        .foregroundStyle(DDColor.textSecondary)
        .frame(height: 20)
    }

    @ViewBuilder
    private var photoStrip: some View {
        if place.photoData.isEmpty {
            if let fallbackImageName,
               let image = UIImage(named: fallbackImageName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 205, height: 154)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 20))
            } else {
                ZStack {
                    DDColor.surfaceElevated

                    Image("DDEarth")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 78, height: 72)
                }
                    .frame(width: 205, height: 154)
                    .clipShape(.rect(cornerRadius: 20))
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DDSpacing.medium) {
                    ForEach(Array(place.photoData.enumerated()), id: \.offset) { _, data in
                        if let image = UIImage(data: data) {
                            Rectangle()
                                .foregroundStyle(.clear)
                                .frame(width: 205, height: 154)
                                .background {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 205, height: 154)
                                        .clipped()
                                }
                                .clipShape(.rect(cornerRadius: 20))
                        }
                    }
                }
            }
            .frame(height: 154)
        }
    }
}
