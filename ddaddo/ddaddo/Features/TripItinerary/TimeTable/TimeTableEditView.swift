import ComposableArchitecture
import SwiftUI

struct TimeTableEditView: View {
    let timeTableStore: StoreOf<TimeTableFeature>
    let store: StoreOf<TimeTableEditFeature>

    var body: some View {
        TimeTableContent(
            store: timeTableStore,
            onBack: { store.send(.backButtonTapped) },
            onSave: { store.send(.saveButtonTapped) },
            onAddSchedule: { store.send(.addScheduleButtonTapped) },
            groups: timeTableStore.groups
        )
        .sheet(
            isPresented: Binding(
                get: { store.isAddSchedulePresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.addScheduleDismissed)
                    }
                }
            )
        ) {
            AddScheduleBottomSheet(store: store)
                .presentationDetents([.height(395), .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(40)
                .presentationBackground(DDColor.surfaceDefault)
        }
    }
}

#Preview {
    TimeTableView(
        store: Store(initialState: TimeTableFeature.State(isEditing: true)) {
            TimeTableFeature()
        }
    )
}
