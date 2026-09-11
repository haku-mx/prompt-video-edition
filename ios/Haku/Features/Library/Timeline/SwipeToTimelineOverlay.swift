//
//  SwipeToTimelineOverlay.swift
//  Minimal gesture affordance shared by collection and video detail screens.
//

import SwiftUI

struct SwipeToTimelineOverlay: View {
    var bottomPadding: CGFloat
    let onCommit: () -> Void

    @State private var showHint = true
    @State private var pull: CGFloat = 0
    @State private var armed = false

    private let threshold: CGFloat = 96

    private var progress: CGFloat { min(1, max(0, pull / threshold)) }
    private var offset: CGFloat { min(pull * 0.48, 52) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(Double(progress) * 0.055)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            cue
                .padding(.bottom, bottomPadding)
        }
    }

    private var cue: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HakuColor.textPrimary)
                .rotationEffect(.degrees(-90))
                .offset(y: -progress * 2)

            Text("swipe up\nto edit")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.2)
                .multilineTextAlignment(.center)
                .foregroundStyle(HakuColor.textSecondary)
        }
        .frame(width: 100, height: 52, alignment: .top)
        .opacity(showHint ? 0.58 + Double(progress) * 0.2 : 0)
        .blur(radius: showHint ? 0 : 3)
        .contentShape(Rectangle())
        .gesture(pullGesture)
        .offset(y: -offset)
        .animation(.easeOut(duration: 0.18), value: armed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Swipe up to edit")
        .accessibilityAction(named: Text("Open timeline")) {
            onCommit()
        }
        .task {
            do {
                try await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.5)) {
                    showHint = false
                }
            } catch { }
        }
    }

    private var pullGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                pull = max(0, -value.translation.height)
                let nowArmed = pull >= threshold
                if nowArmed && !armed {
                    Haptics.light()
                }
                armed = nowArmed
            }
            .onEnded { value in
                let distance = -value.translation.height
                let predictedDistance = -value.predictedEndTranslation.height
                if distance >= threshold || predictedDistance >= threshold * 1.15 {
                    onCommit()
                }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                    pull = 0
                    armed = false
                }
            }
    }
}
