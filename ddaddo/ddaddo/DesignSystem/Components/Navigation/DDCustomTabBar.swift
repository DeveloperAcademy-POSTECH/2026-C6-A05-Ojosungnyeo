//
//  DDCustomTabBar.swift
//  ddaddo
//
//  Created by sun on 10/29/26.
//

import SwiftUI

struct DDTabBarItem<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let iconName: String
}

struct DDCustomTabBar<ID: Hashable>: View {
    let items: [DDTabBarItem<ID>]
    let selection: ID
    let onSelect: (ID) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .frame(height: 62)
        .background(alignment: .top) {
            tabBarBackground
        }
    }

    private func tabButton(_ item: DDTabBarItem<ID>) -> some View {
        let isSelected = item.id == selection

        return Button {
            onSelect(item.id)
        } label: {
            VStack(spacing: 3) {
                Image(item.iconName)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 28, height: 28)

                Text(item.title)
                    .ddTypography(isSelected ? .captionEmphasis12 : .caption12)
                    .frame(height: 18)
            }
            .foregroundStyle(isSelected ? DDColor.actionPrimary : DDColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var tabBarBackground: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 28,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 28
        )
        .fill(DDColor.surfaceNavigation)
        .stroke(DDColor.borderSubtle, lineWidth: 1)
        .frame(height: 96)
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    DDCustomTabBar(
        items: [
            DDTabBarItem(id: 0, title: "plans", iconName: "DDTabCalendar"),
            DDTabBarItem(id: 1, title: "route", iconName: "DDTabRoute")
        ],
        selection: 0,
        onSelect: { _ in }
    )
    .background(DDColor.surfaceDefault)
}
