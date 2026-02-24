import SwiftUI

struct AnimatedBackground: View {
    @Environment(BackgroundTweaks.self) private var tweaks

    var body: some View {
        Rectangle()
            .fill(.clear)
            .glassEffect(tweaks.glassStyle, in: .rect)
            .ignoresSafeArea()
            .background(WindowAccessor(windowOpacity: tweaks.windowOpacity))
    }
}
