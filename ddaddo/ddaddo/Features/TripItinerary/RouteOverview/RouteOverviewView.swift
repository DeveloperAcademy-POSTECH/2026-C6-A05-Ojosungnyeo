//
//  RouteOverviewView.swift
//  ddaddo
//
//  Created by sun on 10/22/26.
//

import ComposableArchitecture
import SwiftUI

struct RouteOverviewView: View {
    private let tabBarCoveredHeight: CGFloat = 96
    let store: StoreOf<RouteOverviewFeature>
    var onBack: () -> Void = {
        // Preview and isolated usages can omit navigation handling.
    }
    @State private var isItineraryExpanded = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                routeMap

                VStack(spacing: 0) {
                    tripNavigation
                    dayPicker
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                itineraryPanel(
                    fullHeight: max(560, proxy.size.height - 143)
                )
            }
        }
        .onAppear {
            isItineraryExpanded = false
            store.send(.onAppear)
        }
        .preferredColorScheme(.dark)
    }

    private var routeMap: some View {
        RouteGoogleMapView(
            stops: store.visibleStops,
            selectedMembers: store.selectedMembers,
            selectedMemberOrder: store.selectedMemberOrder,
            currentMember: store.currentMember,
            memberOrder: store.memberOrder
        )
            .ignoresSafeArea()
    }

    private var tripNavigation: some View {
        ZStack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(DDColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())

            VStack(spacing: 0) {
                Text("3박 4일 도쿄 여행")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
            }
        }
        .padding(.horizontal, DDSpacing.small)
        .frame(height: 40)
    }

    private var dayPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DDSpacing.small) {
                ForEach(TripDay.allCases) { day in
                    Button {
                        store.send(.daySelected(day))
                    } label: {
                        Text(day.rawValue)
                            .ddTypography(.labelEmphasis14)
                            .foregroundStyle(DDColor.textPrimary)
                            .frame(width: 64, height: 40)
                            .background(day == store.selectedDay ? DDColor.surfaceControl : Color.clear)
                            .clipShape(.capsule)
                            .overlay {
                                Capsule()
                                    .stroke(
                                        day == store.selectedDay ? DDColor.actionPrimary : DDColor.borderDefault,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 17)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 8)
    }

    private func itineraryPanel(fullHeight _: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.textTertiary)
                .frame(width: 142, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

            memberFilter
                .padding(.top, 14)

            Text("여행 일정")
                .ddTypography(.bodyEmphasis16)
                .foregroundStyle(DDColor.textPrimary)
                .padding(.top, isItineraryExpanded ? 18 : 10)

            if isItineraryExpanded {
                itineraryList
                    .padding(.top, 12)
            }
        }
        .padding(.leading, 15)
        .padding(.trailing, DDSpacing.large)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(
            height: (isItineraryExpanded ? 413 : 139) + tabBarCoveredHeight,
            alignment: .top
        )
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
        .ddFillBottomSheetToScreenEdge()
        .offset(y: tabBarCoveredHeight)
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    if value.translation.height < -30 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isItineraryExpanded = true
                        }
                    } else if value.translation.height > 30 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isItineraryExpanded = false
                        }
                    }
                }
        )
    }

    private var memberFilter: some View {
        HStack(spacing: DDSpacing.xSmall) {
            ForEach(store.memberOrder) { member in
                Button {
                    store.send(.memberTapped(member))
                } label: {
                    DDMiniHeadAvatar(character: member.routeAvatarCharacter, size: 37)
                        .opacity(
                            store.selectedMembers.isEmpty || store.selectedMembers.contains(member)
                                ? 1
                                : 0.35
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(member.accessibilityName) 일정 보기")
                .accessibilityValue(store.selectedMembers.contains(member) ? "선택됨" : "선택 안 됨")
            }

        }
    }

    private var itineraryList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(store.visibleStopGroups.enumerated()), id: \.element.id) { index, group in
                    HStack(alignment: .top, spacing: 20) {
                        timelineMarker(
                            index: index,
                            isLast: index == store.visibleStopGroups.count - 1,
                            rowHeight: itineraryRowHeight(group)
                        )

                        itineraryCards(for: group)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func itineraryCards(for group: RouteStopGroup) -> some View {
        if group.stops.count == 1 {
            stopCard(group.stops[0])
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(group.stops) { stop in
                        stopCard(stop)
                            .frame(width: 200)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content.opacity(phase.isIdentity ? 1 : 0.82)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    private func stopCard(_ stop: RouteStop) -> some View {
        VStack(alignment: .leading, spacing: DDSpacing.xSmall) {
            Button {
                guard stop.placeNames.count > 1 else { return }
                store.send(.stopDisclosureTapped(stop.id))
            } label: {
                HStack(spacing: DDSpacing.xSmall) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(stop.name)
                                .ddTypography(.bodyEmphasis16)
                                .foregroundStyle(DDColor.textPrimary)
                                .lineLimit(1)

                            participantDots(for: stop)
                        }

                        if !stop.category.isEmpty {
                            Text(stop.category)
                                .ddTypography(.labelEmphasis14)
                                .foregroundStyle(DDColor.surfaceSelected)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: DDSpacing.small)

                    if stop.placeNames.count > 1 {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DDColor.textSecondary)
                            .rotationEffect(
                                store.expandedStopIDs.contains(stop.id)
                                    ? .degrees(180) : .zero
                            )
                    }
                }
                .padding(.horizontal, DDSpacing.xLarge)
                .frame(maxWidth: .infinity, minHeight: 71, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if stop.placeNames.count > 1,
               store.expandedStopIDs.contains(stop.id) {
                VStack(spacing: DDSpacing.small) {
                    ForEach(Array(stop.placeNames.enumerated()), id: \.offset) { index, placeName in
                        HStack(spacing: DDSpacing.medium) {
                            Text("\(index + 1)")
                                .ddTypography(.labelEmphasis14)
                                .foregroundStyle(DDColor.surfaceSelected)
                                .frame(width: 18)

                            Text(placeName)
                                .ddTypography(.bodyEmphasis16)
                                .foregroundStyle(DDColor.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, DDSpacing.large)
                        .frame(height: 44)
                        .background(DDColor.surfaceDefault)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, DDSpacing.large)
                .padding(.bottom, DDSpacing.large)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.textTertiary, lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: store.expandedStopIDs)
    }

    @ViewBuilder
    private func participantDots(for stop: RouteStop) -> some View {
        if store.selectedMembers.count != 1,
           !Set(store.memberOrder).isSubset(of: stop.members) {
            HStack(spacing: -5) {
                ForEach(members(for: stop)) { member in
                    Circle()
                        .fill(member.routeAccentColor)
                        .frame(width: 14, height: 14)
                }
            }
        }
    }

    private func timelineMarker(
        index: Int,
        isLast: Bool,
        rowHeight: CGFloat = 71
    ) -> some View {
        ZStack(alignment: .top) {
            if !isLast {
                Rectangle()
                    .fill(DDColor.textTertiary)
                    .frame(width: 5, height: rowHeight + DDSpacing.large)
                    .offset(y: 7)
            }

            ZStack {
                Circle()
                    .fill(DDColor.actionPrimary)
                    .frame(width: 15, height: 15)

                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.black)
            }
        }
        .frame(width: 15, height: rowHeight, alignment: .top)
    }

    private func itineraryRowHeight(_ group: RouteStopGroup) -> CGFloat {
        let heights = group.stops.map { stop -> CGFloat in
            guard stop.placeNames.count > 1,
                  store.expandedStopIDs.contains(stop.id)
            else { return 71 }
            let rows = CGFloat(stop.placeNames.count) * 44
            let spacing = CGFloat(max(stop.placeNames.count - 1, 0)) * DDSpacing.small
            return 71 + rows + spacing + DDSpacing.large
        }
        return heights.max() ?? 71
    }

    private func members(for stop: RouteStop) -> [TripMember] {
        store.memberOrder.filter { member in
            stop.members.contains(member)
                && (store.selectedMembers.isEmpty || store.selectedMembers.contains(member))
        }
    }
}

extension TripMember {
    var accessibilityName: String {
        switch self {
        case .tae: "테이"
        case .header: "헤더"
        case .grae: "그레"
        case .juni: "주니"
        }
    }

    var routeAvatarCharacter: DDMiniHeadAvatar.Character {
        switch self {
        case .tae: .tae
        case .header: .header
        case .grae: .grae
        case .juni: .juni
        }
    }

    var routeAccentColor: Color {
        switch self {
        case .tae: Color(red: 217 / 255.0, green: 149 / 255.0, blue: 126 / 255.0)
        case .header: Color(red: 152 / 255.0, green: 156 / 255.0, blue: 209 / 255.0)
        case .grae: Color(red: 102 / 255.0, green: 181 / 255.0, blue: 173 / 255.0)
        case .juni: Color(red: 197 / 255.0, green: 144 / 255.0, blue: 167 / 255.0)
        }
    }

    var routePolylineColor: Color {
        switch self {
        case .tae: Color(red: 192 / 255.0, green: 106 / 255.0, blue: 78 / 255.0)
        case .header: Color(red: 109 / 255.0, green: 114 / 255.0, blue: 189 / 255.0)
        case .grae: Color(red: 80 / 255.0, green: 117 / 255.0, blue: 113 / 255.0)
        case .juni: Color(red: 158 / 255.0, green: 107 / 255.0, blue: 130 / 255.0)
        }
    }

    var routeUFOAssetName: String {
        switch self {
        case .tae: "DDRouteUFOTae"
        case .header: "DDRouteUFOHeader"
        case .grae: "DDRouteUFOGrae"
        case .juni: "DDRouteUFOJuni"
        }
    }
}

#Preview {
    RouteOverviewView(
        store: Store(initialState: RouteOverviewFeature.State()) {
            RouteOverviewFeature()
        }
    )
}
