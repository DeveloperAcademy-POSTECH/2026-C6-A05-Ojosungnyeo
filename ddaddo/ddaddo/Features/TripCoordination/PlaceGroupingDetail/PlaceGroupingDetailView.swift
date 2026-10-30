//
//  PlaceGroupingDetailView.swift
//  ddaddo
//

import ComposableArchitecture
import SwiftUI

struct PlaceGroupingDetailView: View {
    let store: StoreOf<PlaceGroupingDetailFeature>
    var initiallyRevealedPlaceID: String?

    var body: some View {
        VStack(spacing: DDSpacing.zero) {
            tripNavigation
            groupHeading
            memberHeading
            memberList
            placeHeading
            placeList
        }
        .safeAreaInset(edge: .bottom, spacing: DDSpacing.zero) {
            DDCTAButton(title: "다음으로") {
                store.send(.nextButtonTapped)
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
                        .font(.system(size: 25, weight: .regular))
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(.rect)
                }

                Spacer()

                Button {
                    store.send(.menuButtonTapped)
                } label: {
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
            Text(store.groupTitle)
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
        .frame(height: 48, alignment: .top)
    }

    private var memberHeading: some View {
        Text("함께하는 친구")
            .ddTypography(.body16)
            .foregroundStyle(DDColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DDSpacing.large)
            .frame(height: 26, alignment: .top)
    }

    private var memberList: some View {
        HStack(spacing: 5) {
            ForEach(store.members) { member in
                DDMiniHeadAvatar(character: member.character, size: 40)
            }

            Spacer(minLength: DDSpacing.zero)
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(height: 79, alignment: .top)
    }

    private var placeHeading: some View {
        Text("꼭 방문하고 싶은 장소")
            .ddTypography(.body16)
            .foregroundStyle(DDColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DDSpacing.large)
            .frame(height: 26, alignment: .top)
    }

    private var placeList: some View {
        ScrollView {
            LazyVStack(spacing: 15) {
                ForEach(store.places) { place in
                    PlaceSwipeRow(
                        place: place,
                        isInitiallyRevealed: place.id == initiallyRevealedPlaceID,
                        onEdit: { store.send(.editPlaceTapped(place.id)) },
                        onDelete: { store.send(.deletePlaceTapped(place.id)) }
                    )
                }
            }
            .padding(.bottom, DDSpacing.large)
        }
        .padding(.top, DDSpacing.xSmall)
        .scrollIndicators(.hidden)
    }
}

private struct PlaceSwipeRow: View {
    private let actionWidth: CGFloat = 196
    private let revealOffset: CGFloat = 208

    let place: PlaceGroupingDetailFeature.Place
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var horizontalOffset: CGFloat
    @State private var settledOffset: CGFloat

    init(
        place: PlaceGroupingDetailFeature.Place,
        isInitiallyRevealed: Bool,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.place = place
        self.onEdit = onEdit
        self.onDelete = onDelete

        let initialOffset: CGFloat = isInitiallyRevealed ? -208 : 0
        _horizontalOffset = State(initialValue: initialOffset)
        _settledOffset = State(initialValue: initialOffset)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            actionButtons
                .padding(.trailing, DDSpacing.large)

            placeCard
                .padding(.horizontal, DDSpacing.large)
                .offset(x: horizontalOffset)
                .gesture(swipeGesture)
        }
        .frame(height: 93)
        .clipped()
    }

    private var placeCard: some View {
        HStack(alignment: .top, spacing: 17) {
            Image(place.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 15))

            VStack(alignment: .leading, spacing: DDSpacing.zero) {
                Text(place.title)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .lineLimit(1)

                Text(place.address)
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, DDSpacing.xSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 93, maxHeight: 93)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.borderDefault, lineWidth: 1)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            swipeActionButton(systemName: "pencil", action: onEdit)
            swipeActionButton(systemName: "trash", action: onDelete)
        }
        .frame(width: actionWidth)
    }

    private func swipeActionButton(
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 25, weight: .regular))
                .foregroundStyle(DDColor.textSecondary)
                .frame(width: 93, height: 93)
                .background(DDColor.actionSecondary)
                .clipShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                horizontalOffset = min(
                    0,
                    max(-revealOffset, settledOffset + value.translation.width)
                )
            }
            .onEnded { value in
                let predictedOffset = settledOffset + value.predictedEndTranslation.width
                let shouldReveal = predictedOffset < -(revealOffset / 2)
                let destination = shouldReveal ? -revealOffset : 0

                withAnimation(.snappy(duration: 0.25)) {
                    horizontalOffset = destination
                    settledOffset = destination
                }
            }
    }
}

#Preview("Place grouping") {
    PlaceGroupingDetailView(
        store: Store(initialState: PlaceGroupingDetailFeature.State()) {
            PlaceGroupingDetailFeature()
        }
    )
}

#Preview("Place grouping - swipe actions") {
    PlaceGroupingDetailView(
        store: Store(initialState: PlaceGroupingDetailFeature.State()) {
            PlaceGroupingDetailFeature()
        },
        initiallyRevealedPlaceID: "tokyo-station-shopping"
    )
}
