import SwiftUI
import AppKit

/// Invisible view that configures the hosting NSWindow for transparency.
/// Does NOT touch the view hierarchy — only sets window-level properties.
struct WindowAccessor: NSViewRepresentable {
    var windowOpacity: Double

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.frame = .zero
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.alphaValue = windowOpacity
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = windowOpacity
    }
}
