import SwiftUI

struct ContentView: View {
    @Environment(VMManager.self) private var vmManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("mochiDarkMode") private var isDarkMode = false
    @State private var showWizard = false
    @State private var editingConfig: VMConfig?
    @State private var showDevPanel = false
    @State private var backgroundTweaks = BackgroundTweaks()

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AnimatedBackground()
                .environment(backgroundTweaks)

            VStack(spacing: 0) {
                // Traffic light spacer for hidden title bar
                Color.clear.frame(height: 12)

                // Toolbar header
                toolbarHeader
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // Scrollable card grid
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
                    .padding(.horizontal, 40)
                    .padding(.bottom, 80)
                    .padding(.top, 8)
                }
            }

            // Wizard overlays
            if showWizard {
                MochiWizard(mode: .create) {
                    withAnimation(.spring(response: 0.3)) {
                        showWizard = false
                    }
                }
                .transition(.opacity)
            }

            if let config = editingConfig {
                MochiWizard(mode: .edit(config)) {
                    withAnimation(.spring(response: 0.3)) {
                        editingConfig = nil
                    }
                }
                .transition(.opacity)
            }

            // Dev tweak panel
            if showDevPanel {
                DevTweakPanel()
                    .environment(backgroundTweaks)
                    .padding(.top, 52)
                    .padding(.trailing, 16)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
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
            withAnimation(.spring(response: 0.3)) {
                showWizard = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            Task {
                await vmManager.suspendAllRunningVMs()
            }
        }
    }

    // MARK: - Toolbar Header

    private var toolbarHeader: some View {
        HStack(spacing: 16) {
            MochiIcon(size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("My Mochis")
                    .font(.system(size: 30, weight: .black))
                    .tracking(-1)
                    .foregroundStyle(
                        LinearGradient(
                            colors: isDark
                                ? [.white, Color(hex: "9ca3af")]       // white → gray-400
                                : [Color(hex: "1f2937"), Color(hex: "6b7280")], // gray-800 → gray-500
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Manage your little virtual worlds")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isDark ? Color.white.opacity(0.4) : Color(hex: "9ca3af")) // gray-400
            }

            Spacer()

            // Storage badge
            HStack(spacing: 8) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 12))
                    .opacity(0.6)
                Text(storageBadgeText)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .opacity(0.8)
            }
            .foregroundStyle(isDark ? Color.white.opacity(0.6) : Color(hex: "6b7280"))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Dark/Light toggle
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isDarkMode.toggle()
                }
            } label: {
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isDarkMode ? .yellow : .orange)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Dev tweaks toggle
            #if DEBUG
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showDevPanel.toggle()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14))
                    .foregroundStyle(showDevPanel ? .white : .secondary)
                    .frame(width: 36, height: 36)
                    .background(showDevPanel ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.ultraThinMaterial))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            #endif
        }
    }

    // MARK: - Add New Card

    private var addNewCard: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showWizard = true
            }
        } label: {
            VStack(spacing: 16) {
                // Circle with plus icon
                Image(systemName: "plus")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(isDark ? Color.white.opacity(0.4) : Color(hex: "9ca3af"))
                    .frame(width: 64, height: 64)
                    .background(isDark ? Color.white.opacity(0.05) : .white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(isDark ? 0 : 0.05), radius: 4)

                Text("Add New Mochi")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(isDark ? Color.white.opacity(0.4) : Color(hex: "9ca3af"))
                    .opacity(0.6)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 320)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .strokeBorder(
                        isDark ? Color.white.opacity(0.1) : Color(hex: "e5e7eb"), // gray-200
                        style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var storageBadgeText: String {
        let bytes = StorageService.totalDiskUsage()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) + " Used"
    }
}
