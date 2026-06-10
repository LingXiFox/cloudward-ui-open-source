import SwiftUI

struct CloudRippleView: View {
    let isActive: Bool
    let reduceMotion: Bool
    @State private var startDate = Date()

    var body: some View {
        ZStack {
            if isActive {
                if reduceMotion {
                    Circle()
                        .fill(CloudwardColors.celadon.opacity(0.18))
                        .frame(width: 24, height: 24)
                        .transition(.opacity)
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                        let phase = ripplePhase(at: timeline.date)
                        Circle()
                            .stroke(CloudwardColors.celadon.opacity(0.6 * (1 - phase)), lineWidth: 2)
                            .frame(width: 8 + phase * 48, height: 8 + phase * 48)
                    }
                    .transition(.opacity)
                }
            }
        }
        .frame(width: 52, height: 52)
        .allowsHitTesting(false)
        .onChange(of: isActive) {
            if isActive {
                startDate = Date()
            }
        }
    }

    private func ripplePhase(at date: Date) -> Double {
        let raw = date.timeIntervalSince(startDate) / 0.6
        return min(max(raw, 0), 1)
    }
}
