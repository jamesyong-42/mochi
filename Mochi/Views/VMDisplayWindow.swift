import SwiftUI

struct VMDisplayWindow: View {
    @Environment(VMManager.self) private var vmManager
    let vmID: UUID

    private var session: VMSession? {
        vmManager.session(for: vmID)
    }

    var body: some View {
        Group {
            if let session, let vm = session.virtualMachine, session.state == .running {
                VMDisplayView(virtualMachine: vm)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "VM Not Running",
                    systemImage: "desktopcomputer.trianglebadge.exclamationmark",
                    description: Text("Start the virtual machine to see its display.")
                )
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle(vmManager.virtualMachines.first { $0.id == vmID }?.name ?? "VM Display")
    }
}
