//
//  DDProgressBar.swift
//  ddaddo
//

import SwiftUI

struct DDProgressBar: View {
    let currentStep: Int

    private let totalSteps = 4
    private let trackHeight: CGFloat = 3

    private var progress: CGFloat {
        let clampedStep = min(max(currentStep, 1), totalSteps)
        return CGFloat(clampedStep) / CGFloat(totalSteps)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DDColor.textTertiary)

                Capsule()
                    .fill(DDColor.actionPrimary)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: trackHeight)
        .animation(.easeInOut(duration: 0.35), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("진행 단계")
        .accessibilityValue("총 \(totalSteps)단계 중 \(Int(progress * CGFloat(totalSteps)))단계")
    }
}

#Preview("Step 1") {
    DDProgressBar(currentStep: 1)
        .padding(DDSpacing.large)
        .background(DDColor.surfaceDefault)
}

#Preview("Step 2") {
    DDProgressBar(currentStep: 2)
        .padding(DDSpacing.large)
        .background(DDColor.surfaceDefault)
}

#Preview("Step 3") {
    DDProgressBar(currentStep: 3)
        .padding(DDSpacing.large)
        .background(DDColor.surfaceDefault)
}

#Preview("Step 4") {
    DDProgressBar(currentStep: 4)
        .padding(DDSpacing.large)
        .background(DDColor.surfaceDefault)
}

#Preview("Interactive") {
    DDProgressBarInteractivePreview()
}

private struct DDProgressBarInteractivePreview: View {
    @State private var currentStep = 1

    var body: some View {
        VStack(spacing: DDSpacing.xLarge) {
            DDProgressBar(currentStep: currentStep)

            HStack(spacing: DDSpacing.small) {
                Button("이전") {
                    currentStep = max(currentStep - 1, 1)
                }

                Text("\(currentStep) / 4")
                    .ddTypography(.bodyEmphasis16)
                    .foregroundStyle(DDColor.textPrimary)

                Button("다음") {
                    currentStep = min(currentStep + 1, 4)
                }
            }
            .buttonStyle(.bordered)
            .tint(DDColor.actionPrimary)
        }
        .padding(DDSpacing.large)
        .background(DDColor.surfaceDefault)
    }
}
