//
//  MemberPlacesBottomSheet.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import SwiftUI

struct MemberPlacesBottomSheet: View {
    let isExpanded: Bool
    let selectedMember: TripMember
    let participants: [PlaceSelectionFeature.Participant]
    let places: [PinnedPlace]
    let canDeletePlaces: Bool
    let canConfirm: Bool
    var bottomContentInset: CGFloat = DDSpacing.xLarge
    let memberTapped: (TripMember) -> Void
    let placeTapped: (PinnedPlace) -> Void
    let deletePlace: (PinnedPlace) -> Void
    let confirmButtonTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 142, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 19)

            memberSelector
                .padding(.top, DDSpacing.xLarge)

            if isExpanded {
                if places.isEmpty {
                    Text("아직 핀 찍힌 장소가 없어요")
                        .ddTypography(.body16)
                        .foregroundStyle(DDColor.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, bottomContentInset)
                } else {
                    placeList
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DDSpacing.large)
        .frame(maxWidth: .infinity)
        .frame(height: 535)
        .background(DDColor.surfaceDefault)
        .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
    }

    private var memberSelector: some View {
        HStack(spacing: DDSpacing.xSmall) {
            ForEach(participants) { participant in
                Button {
                    memberTapped(participant.member)
                } label: {
                    PlaceSelectionParticipantAvatar(
                        participant: participant,
                        isSelected: selectedMember == participant.member
                    )
                }
                .buttonStyle(.plain)
                .disabled(!participant.hasJoined)
            }

            Spacer(minLength: DDSpacing.small)

            Button("확정하기", action: confirmButtonTapped)
                .ddTypography(.label14)
                .foregroundStyle(canConfirm ? DDColor.textPrimary : DDColor.textTertiary)
                .padding(.horizontal, DDSpacing.medium)
                .frame(height: 28)
                .background(DDColor.surfaceControl)
                .clipShape(.capsule)
                .disabled(!canConfirm)
        }
    }

    private var placeList: some View {
        List {
            ForEach(places) { place in
                Button {
                    placeTapped(place)
                } label: {
                    PlacePinCard(place: place)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: DDSpacing.medium, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if canDeletePlaces {
                        Button(role: .destructive) {
                            deletePlace(place)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }

            Color.clear
                .frame(height: bottomContentInset)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, DDSpacing.medium)
    }
}
