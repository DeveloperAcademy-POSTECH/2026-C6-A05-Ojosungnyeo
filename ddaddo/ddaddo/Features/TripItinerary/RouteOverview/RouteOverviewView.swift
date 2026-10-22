//
//  RouteOverviewView.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import ComposableArchitecture
import SwiftUI

struct RouteOverviewView: View {
    let store: StoreOf<RouteOverviewFeature>

    var body: some View {
        ZStack {
            routeMap

            VStack(spacing: 0) {
                tripNavigation
                Spacer(minLength: 0)
                placeCarousel
            }
        }
        .preferredColorScheme(.dark)
    }

    private var routeMap: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Image(store.selectedPlace.routeType.mapImageName)
                    .resizable()
                    .frame(
                        width: proxy.size.height * store.selectedPlace.routeType.mapAspectRatio,
                        height: proxy.size.height
                    )
                    .offset(
                        x: proxy.size.height
                            * store.selectedPlace.routeType.mapLeadingOffsetRatio
                    )
                    .id(store.selectedPlace.routeType.mapImageName)
                    .transition(.opacity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .clipped()
            .animation(.easeInOut(duration: 0.25), value: store.selectedPlaceID)
        }
        .ignoresSafeArea()
    }

    private var tripNavigation: some View {
        ZStack {
            Button {
                store.send(.backButtonTapped)
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                Text("도쿄 여행")
                    .ddTypography(.labelEmphasis14)
                    .foregroundStyle(DDColor.textPrimary)

                Text("11월 22일 ~ 25일")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.textSecondary)
            }
        }
        .padding(.horizontal, DDSpacing.small)
        .frame(height: 51)
    }

    private var placeCarousel: some View {
        VStack(spacing: DDSpacing.small) {
            pageIndicator

            ScrollView(.horizontal) {
                LazyHStack(spacing: DDSpacing.small) {
                    ForEach(store.places) { place in
                        RoutePlaceCard(place: place) {
                            store.send(.addressCopyButtonTapped(place.address))
                        }
                        .containerRelativeFrame(.horizontal, count: 1, spacing: DDSpacing.small)
                        .id(place.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, DDSpacing.xxLarge, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(
                id: Binding(
                    get: { store.selectedPlaceID },
                    set: { store.send(.placeChanged($0)) }
                )
            )
            .frame(height: 126)
        }
        .padding(.bottom, DDSpacing.small)
    }

    private var pageIndicator: some View {
        HStack(spacing: DDSpacing.small) {
            ForEach(store.places) { place in
                Circle()
                    .fill(
                        place.id == store.selectedPlaceID
                            ? DDColor.textPrimary
                            : DDColor.textTertiary
                    )
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black)
        .clipShape(.capsule)
    }
}

#Preview {
    RouteOverviewView(
        store: Store(initialState: RouteOverviewFeature.State()) {
            RouteOverviewFeature()
        }
    )
}
