import SwiftUI

struct ContentView: View {
    @Environment(VMManager.self) private var vmManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("mochiDarkMode") private var isDarkMode = false
    @State private var showWizard = false
    @State private var editingConfig: VMConfig?
    @State private var showDevPanel = false

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 32)], spacing: 32) {
                    ForEach(vmManager.virtualMachines) { vm in
                        MochiCard(
                            config: vm,
                            state: vmManager.state(for: vm.id),
                            onEdit: {
                                editingConfig = vm
                            }
                        )
                    }

                    // Add new card
                    addNewCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .padding(.top, 4)
            }
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    storageBadge

                    Button {
                        isDarkMode.toggle()
                    } label: {
                        Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    }
                    .help(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode")

                    #if DEBUG
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showDevPanel.toggle()
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .help("Dev Tweaks")
                    #endif
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showWizard = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("New Virtual Machine")
                }
            }
            .overlay(alignment: .topTrailing) {
                #if DEBUG
                if showDevPanel {
                    DevTweakPanel()
                        .padding(.top, 8)
                        .padding(.trailing, 16)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                #endif
            }
        }
        .sheet(isPresented: $showWizard) {
            MochiWizard(mode: .create)
        }
        .sheet(item: $editingConfig) { config in
            MochiWizard(mode: .edit(config))
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .task {
            vmManager.loadVMs()
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
            showWizard = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            Task {
                await vmManager.suspendAllRunningVMs()
            }
        }
    }

    // MARK: - Storage Badge

    private var storageBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive")
            Text(storageBadgeText)
                .font(.caption)
        }
    }

    // MARK: - Add New Card

    private var addNewCard: some View {
        AddNewMochiCard(isDark: isDark) {
            showWizard = true
        }
    }

    // MARK: - Helpers

    private var storageBadgeText: String {
        let bytes = StorageService.totalDiskUsage()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) + " Used"
    }
}

// MARK: - Add New Mochi Card

private struct AddNewMochiCard: View {
    let isDark: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isHovering ? .primary : .secondary)
                    .frame(width: 48, height: 48)
                    .background(.quaternary)
                    .clipShape(Circle())

                Text("Add New Mac")
                    .font(.subheadline.bold())
                    .foregroundStyle(isHovering ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 320)
            .background(.quaternary.opacity(isHovering ? 0.5 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
