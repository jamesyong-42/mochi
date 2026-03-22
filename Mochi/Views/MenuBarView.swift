import SwiftUI

struct MenuBarView: View {
    @Environment(VMManager.self) private var vmManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if vmManager.runningVMs.isEmpty {
                Text("No running VMs")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                Text("Running VMs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(vmManager.runningVMs) { vm in
                    Button {
                        openWindow(value: vm.id)
                    } label: {
                        HStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text(vm.name)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
            }

            Divider()
                .padding(.vertical, 4)

            Button("Open Mac VM") {
                NSApplication.shared.activate()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()
                .padding(.vertical, 4)

            Button("Quit") {
                Task {
                    await vmManager.suspendAllRunningVMs()
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .padding(.vertical, 4)
        .frame(minWidth: 200)
    }
}
