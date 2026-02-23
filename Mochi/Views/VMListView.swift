import SwiftUI

struct VMListView: View {
    @Environment(VMManager.self) private var vmManager
    @Binding var selection: UUID?

    var body: some View {
        List(selection: $selection) {
            ForEach(vmManager.virtualMachines) { vm in
                VMListRow(config: vm, state: vmManager.state(for: vm.id))
                    .tag(vm.id)
                    .contextMenu {
                        Button("Duplicate") {
                            Task { await vmManager.duplicateVM(sourceID: vm.id) }
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            Task { await vmManager.deleteVM(id: vm.id) }
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if vmManager.virtualMachines.isEmpty && !vmManager.isLoading {
                ContentUnavailableView(
                    "No Virtual Machines",
                    systemImage: "desktopcomputer",
                    description: Text("Click + to create a new virtual machine.")
                )
            }
        }
    }
}

struct VMListRow: View {
    let config: VMConfig
    let state: VMState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(config.name)
                .font(.body)
                .fontWeight(.medium)

            HStack(spacing: 8) {
                StatusBadge(state: state)
                Text("\(config.cpuCount) CPU · \(config.memoryInGB) GB")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
