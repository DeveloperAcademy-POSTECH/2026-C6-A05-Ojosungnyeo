//
//  RootFeature.swift
//  ddaddo
//
//  Created by sun on 10/19/26.
//

import SwiftUI
import ComposableArchitecture

struct RootFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var home = HomeFeature.State()
    }

    @CasePathable
    enum Action {
        case home(HomeFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .home(.addTripButtonTapped):
                // 여행 생성 화면이 추가되면 이 지점에서 Root 내비게이션 상태를 변경합니다.
                return .none
            case .home(.menuButtonTapped):
                // TODO: 메뉴 화면 구현 후 내비게이션 연결
                return .none
            }
        }

        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
    }
}

struct RootView: View {
    let store: StoreOf<RootFeature>

    var body: some View {
        HomeView(store: store.scope(state: \.home, action: \.home))
    }
}

#Preview {
    RootView(
        store: Store(initialState: RootFeature.State()) {
            RootFeature()
        }
    )
}
