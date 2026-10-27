//
//  TransportationChoiceCard.swift
//  ddaddo
//
//  Created by sun on 10/23/26.
//

import SwiftUI

struct TransportationChoiceCard: View {
    let transportation: Transportation
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DDSpacing.small) {
                Image(transportation.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)

                Text(transportation.title)
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(DDColor.surfaceElevated)
            .clipShape(.rect(cornerRadius: DDRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: DDRadius.medium)
                    .stroke(
                        isSelected ? DDColor.actionPrimary : DDColor.borderDefault,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Circle()
                        .fill(DDColor.actionPrimary)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Image("DDTransportationCheck")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                        }
                        .padding(9)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
