import SwiftUI

@main
struct MochiApp: App {
    @State private var vmManager = VMManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vmManager)
                .environment(vmManager.ipswService)
                .frame(minWidth: 800, minHeight: 500)
        }
        .defaultSize(width: 1100, height: 720)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Virtual Machine…") {
                    NotificationCenter.default.post(name: .showVMCreation, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            CommandMenu("VM") {
                Button("Start") {
                    NotificationCenter.default.post(name: .vmAction, object: "start")
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Stop") {
                    NotificationCenter.default.post(name: .vmAction, object: "stop")
                }
                .keyboardShortcut(".", modifiers: [.command])

                Button("Pause") {
                    NotificationCenter.default.post(name: .vmAction, object: "pause")
                }

                Button("Resume") {
                    NotificationCenter.default.post(name: .vmAction, object: "resume")
                }

                Divider()

                Button("Suspend") {
                    NotificationCenter.default.post(name: .vmAction, object: "suspend")
                }
                .keyboardShortcut("s", modifiers: [.command, .option])

                Divider()

                Button("Duplicate") {
                    NotificationCenter.default.post(name: .vmAction, object: "duplicate")
                }
                .keyboardShortcut("d", modifiers: [.command])
            }
        }

        WindowGroup("VM Display", for: UUID.self) { $vmID in
            if let vmID {
                VMDisplayWindow(vmID: vmID)
                    .environment(vmManager)
                    .environment(vmManager.ipswService)
            }
        }
        .defaultSize(width: 1280, height: 800)

        MenuBarExtra("Mac VM", systemImage: "desktopcomputer") {
            MenuBarView()
                .environment(vmManager)
                .environment(vmManager.ipswService)
        }

        Settings {
            SettingsView()
                .environment(vmManager)
                .environment(vmManager.ipswService)
        }
    }
}

extension Notification.Name {
    static let showVMCreation = Notification.Name("showVMCreation")
    static let vmAction = Notification.Name("vmAction")
}
