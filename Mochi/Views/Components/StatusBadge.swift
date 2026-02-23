import SwiftUI

struct StatusBadge: View {
    let state: VMState

    var body: some View {
        HStack(spacing: 6) {
            if state.isTransitional {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }

            Text(state.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status")
        .accessibilityValue(state.displayName)
    }

    private var color: Color {
        switch state {
        case .running: .green
        case .paused: .orange
        case .stopped: .gray
        case .error: .red
        case .installing: .blue
        default: .gray
        }
    }
}
