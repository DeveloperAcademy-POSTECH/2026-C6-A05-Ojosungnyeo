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
            onScheduleTapped: { store.send(.scheduleTapped($0)) },
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
        .sheet(
            isPresented: Binding(
                get: { store.isTimeSelectionPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.timeSelectionDismissed)
                    }
                }
            )
        ) {
            TimeSelectionBottomSheet(
                selectedMinuteOfDay: Binding(
                    get: { store.selectedMinuteOfDay ?? 0 },
                    set: { store.send(.timeSelectionChanged($0)) }
                ),
                onDone: { store.send(.timeSelectionDoneTapped) }
            )
            .presentationDetents([.height(424)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
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
