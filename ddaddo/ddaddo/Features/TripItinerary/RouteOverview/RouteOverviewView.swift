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
        .animation(.easeInOut(duration: 0.25), value: store.isEditing)
        .onAppear {
            isItineraryExpanded = false
            store.send(.onAppear)
        }
        .preferredColorScheme(.dark)
    }

    private var routeMap: some View {
        RouteGoogleMapView(
            stops: store.visibleStops,
            selectedMember: store.selectedMember
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

    private func itineraryPanel(fullHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.textTertiary)
                .frame(width: 142, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

            if store.isEditing {
                editingHeader
                    .padding(.top, 14)

                Text("여행 일정")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
                    .padding(.top, 14)

                editingItineraryList
                    .padding(.top, 12)
            } else {
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
        }
        .padding(.leading, 15)
        .padding(.trailing, DDSpacing.large)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(
            height: store.isEditing
                ? fullHeight
                : (isItineraryExpanded ? 413 : 139),
            alignment: .top
        )
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
        .contentShape(.rect)
        .gesture(
            store.isEditing
                ? nil
                : DragGesture(minimumDistance: 12)
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

    private var editingHeader: some View {
        HStack(spacing: DDSpacing.xSmall) {
            ForEach(TripMember.allCases) { member in
                DDMiniHeadAvatar(character: member.routeAvatarCharacter, size: 37)
            }

            Spacer(minLength: 0)

            Button("완료") {
                store.send(.editingDoneButtonTapped)
            }
            .ddTypography(.bodyEmphasis16)
            .foregroundStyle(DDColor.textOnPrimary)
            .padding(.horizontal, DDSpacing.large)
            .frame(height: 34)
            .background(DDColor.actionPrimary)
            .clipShape(.capsule)
            .buttonStyle(.plain)
        }
    }

    private var memberFilter: some View {
        HStack(spacing: DDSpacing.xSmall) {
            ForEach(TripMember.allCases) { member in
                Button {
                    store.send(.memberTapped(member))
                } label: {
                    DDMiniHeadAvatar(character: member.routeAvatarCharacter, size: 37)
                        .opacity(
                            store.selectedMember == nil || store.selectedMember == member
                                ? 1
                                : 0.35
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(member.accessibilityName) 일정 보기")
                .accessibilityValue(store.selectedMember == member ? "선택됨" : "선택 안 됨")
            }

            Spacer(minLength: 0)

            Button("편집") {
                store.send(.editButtonTapped)
            }
            .ddTypography(.bodyEmphasis16)
            .foregroundStyle(DDColor.textPrimary)
            .frame(width: 56, height: 34)
            .background(DDColor.surfaceControl)
            .clipShape(.capsule)
            .buttonStyle(.plain)
        }
    }

    private var itineraryList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(store.visibleStops.enumerated()), id: \.element.id) { index, stop in
                    HStack(alignment: .top, spacing: 20) {
                        timelineMarker(index: index, isLast: index == store.visibleStops.count - 1)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(stop.name)
                                    .ddTypography(.bodyEmphasis16)
                                    .foregroundStyle(DDColor.textPrimary)

                                if store.selectedMember == nil,
                                   stop.members.count < TripMember.allCases.count {
                                    HStack(spacing: -5) {
                                        ForEach(members(for: stop)) { member in
                                            Circle()
                                                .fill(member.routeAccentColor)
                                                .frame(width: 14, height: 14)
                                        }
                                    }
                                }
                            }

                            Text(stop.category)
                                .ddTypography(.label14)
                                .foregroundStyle(DDColor.textSecondary)
                        }
                        .padding(.horizontal, DDSpacing.xLarge)
                        .frame(maxWidth: .infinity, minHeight: 71, alignment: .leading)
                        .background(DDColor.surfaceElevated)
                        .clipShape(.rect(cornerRadius: 20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(DDColor.textTertiary, lineWidth: 1)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var editingItineraryList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(store.visibleStops.enumerated()), id: \.element.id) { index, stop in
                    HStack(alignment: .top, spacing: 12) {
                        timelineMarker(index: index, isLast: false)
                        editingStopCard(stop)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    timelineMarker(index: store.visibleStops.count, isLast: true)

                    Button {
                    } label: {
                        Text("+장소 추가하기")
                            .ddTypography(.bodyEmphasis16)
                            .foregroundStyle(DDColor.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                            .padding(.horizontal, DDSpacing.xLarge)
                            .background(DDColor.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 20))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(DDColor.textTertiary, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private func editingStopCard(_ stop: RouteStop) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(stop.name)
                        .ddTypography(.bodyEmphasis16)

                    if store.selectedMember == nil,
                       stop.members.count < TripMember.allCases.count {
                        HStack(spacing: -5) {
                            ForEach(members(for: stop)) { member in
                                Circle()
                                    .fill(member.routeAccentColor)
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                }
                .foregroundStyle(DDColor.textPrimary)

                Text(stop.category)
                    .ddTypography(.labelEmphasis14)
                    .foregroundStyle(DDColor.actionPrimary)
            }

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DDColor.textSecondary)
                .frame(width: 28, height: 44)
                .accessibilityLabel("일정 순서 변경")
        }
        .padding(.horizontal, DDSpacing.xLarge)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(DDColor.surfaceElevated)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(DDColor.textTertiary, lineWidth: 1)
        }
    }

    private func timelineMarker(index: Int, isLast: Bool) -> some View {
        ZStack(alignment: .top) {
            if !isLast {
                Rectangle()
                    .fill(DDColor.textTertiary)
                    .frame(width: 5, height: 92)
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
        .frame(width: 15, height: 71, alignment: .top)
    }

    private func members(for stop: RouteStop) -> [TripMember] {
        TripMember.allCases.filter(stop.members.contains)
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
