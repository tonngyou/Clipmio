// Copyright (c) 2026 tonngyou. MIT License.
import SwiftUI

/// Animate the incoming content only. Outgoing pages are removed immediately.
struct ContentEntrance: ViewModifier {
    let reduceMotion: Bool
    var offset: CGFloat = 6
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(x: revealed || reduceMotion ? 0 : offset)
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? 0.08 : 0.16)) { revealed = true }
            }
    }
}
