import SwiftUI

struct CloudRippleView: View {
    let reduceMotion: Bool
    @State private var isExpanded = false

    var body: some View {
        Circle()
            .stroke(CloudwardColors.celadon.opacity(reduceMotion ? 0.18 : (isExpanded ? 0 : 0.6)), lineWidth: 2)
            .frame(width: reduceMotion ? 24 : (isExpanded ? 56 : 8), height: reduceMotion ? 24 : (isExpanded ? 56 : 8))
            .allowsHitTesting(false)
            .onAppear {
                guard reduceMotion == false else {
                    return
                }

                withAnimation(.easeOut(duration: 0.6)) {
                    isExpanded = true
                }
            }
    }
}
