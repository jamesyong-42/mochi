import SwiftUI

struct ContentView: View {
    @Environment(VMManager.self) private var vmManager
    @State private var selectedVMID: UUID?
    @State private var showCreationSheet = false

    var body: some View {
        NavigationSplitView {
            VMListView(selection: $selectedVMID)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 360)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCreationSheet = true
                        } label: {
                            Label("New VM", systemImage: "plus")
                        }
                        .accessibilityLabel("Create new virtual machine")
                    }
                }
        } detail: {
            if let selectedVMID {
                VMDetailView(vmID: selectedVMID)
            } else {
                ContentUnavailableView(
                    "No VM Selected",
                    systemImage: "desktopcomputer",
                    description: Text("Select a virtual machine from the sidebar, or create a new one.")
                )
            }
        }
        .sheet(isPresented: $showCreationSheet) {
            VMCreationSheet()
        }
        .task {
            vmManager.loadVMs()
        }
        .onChange(of: vmManager.virtualMachines) {
            // Clear selection if the selected VM was deleted
            if let selectedVMID, !vmManager.virtualMachines.contains(where: { $0.id == selectedVMID }) {
                self.selectedVMID = nil
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vmManager.error != nil },
            set: { if !$0 { vmManager.error = nil } }
        )) {
            Button("OK") { vmManager.error = nil }
        } message: {
            Text(vmManager.error ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .showVMCreation)) { _ in
            showCreationSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            Task {
                await vmManager.suspendAllRunningVMs()
            }
        }
    }
}
