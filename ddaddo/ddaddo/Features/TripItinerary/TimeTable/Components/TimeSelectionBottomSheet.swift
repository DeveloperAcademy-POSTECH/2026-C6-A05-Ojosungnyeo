import SwiftUI

struct TimeSelectionBottomSheet: View {
    @Binding var selectedMinuteOfDay: Int
    let canConfirm: Bool
    let showsOverlapError: Bool
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DDColor.actionSecondary)
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            HStack {
                Text("몇 시에 갈까요?")
                    .ddTypography(.heading18)
                    .foregroundStyle(DDColor.textPrimary)

                Spacer()

                Button("완료", action: onDone)
                    .ddTypography(.labelEmphasis14)
                    .foregroundStyle(canConfirm ? DDColor.textOnPrimary : DDColor.textSecondary)
                    .frame(width: 64, height: 40)
                    .background(canConfirm ? DDColor.actionPrimary : DDColor.actionSecondary)
                    .clipShape(.capsule)
                    .buttonStyle(.plain)
                    .disabled(!canConfirm)
            }
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, 17)

            HStack(spacing: 0) {
                Picker("오전 오후", selection: periodBinding) {
                    Text("오전").tag(0)
                    Text("오후").tag(1)
                }
                .frame(maxWidth: .infinity)

                Picker("시", selection: hourBinding) {
                    ForEach(1...12, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .frame(maxWidth: .infinity)

                Picker("분", selection: minuteBinding) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 216)
            .padding(.horizontal, DDSpacing.large)
            .padding(.top, 18)

            if showsOverlapError {
                Text("다른 일정과 시간이 겹쳐요.\n시간을 다시 선택해 주세요.")
                    .ddTypography(.label14)
                    .foregroundStyle(DDColor.actionPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DDSpacing.large)
                    .padding(.top, 7)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DDColor.surfaceDefault)
        .preferredColorScheme(.dark)
    }

    private var periodBinding: Binding<Int> {
        Binding(
            get: { selectedMinuteOfDay / 720 },
            set: { period in
                selectedMinuteOfDay = (period * 12 + (hourOfDay % 12)) * 60 + minute
            }
        )
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { (hourOfDay + 11) % 12 + 1 },
            set: { hour in
                selectedMinuteOfDay = ((selectedMinuteOfDay / 720) * 12 + hour % 12) * 60 + minute
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { minute },
            set: { selectedMinuteOfDay = hourOfDay * 60 + $0 }
        )
    }

    private var hourOfDay: Int { selectedMinuteOfDay / 60 }
    private var minute: Int { selectedMinuteOfDay % 60 }
}
