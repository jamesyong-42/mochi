<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014+-black?style=flat-square&logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/chip-Apple%20Silicon-black?style=flat-square&logo=apple&logoColor=white" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/swift-5.10+-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.10+">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/github/stars/jamesyong-42/mochi?style=flat-square&color=yellow" alt="Stars">
</p>

<h1 align="center">
  <br>
  🍡 Mochi
  <br>
</h1>

<h3 align="center">
  A tiny, native macOS virtual machine manager.<br>
  Built on Apple's Virtualization.framework — no QEMU, no bloat.
</h3>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#install">Install</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#contributing">Contributing</a>
</p>

---

<!--
<p align="center">
  <img src=".github/assets/screenshot.png" width="720" alt="Mochi Dashboard">
</p>
-->

## Why Mochi?

Most macOS VM tools are heavy, complex, or rely on third-party hypervisors. Mochi takes a different approach — it's a **single-purpose native app** that does one thing well: spin up macOS VMs on Apple Silicon with near-native performance.

No configuration files. No terminal commands. Just click and go.

## Features

- **One-click VM creation** — Mochi downloads the latest compatible macOS restore image automatically
- **Near-native performance** — runs directly on Apple's Virtualization.framework, not emulation
- **Suspend & restore** — save VM state and resume exactly where you left off
- **Shared folders** — seamlessly share files between host and guest (read-only or read-write)
- **Live telemetry** — real-time CPU, memory, and uptime monitoring per VM
- **Menu bar access** — quick-launch running VMs from the menu bar
- **Duplicate VMs** — clone an existing VM with a single click
- **Sparse disk images** — storage grows only as needed, no pre-allocated bloat
- **Configurable hardware** — tune CPU cores, RAM, disk size, and display resolution per VM
- **Beautiful card UI** — a clean, modern dashboard with color themes

## Requirements

| Requirement | Minimum |
|------------|---------|
| macOS | 14.0 (Sonoma) |
| Chip | Apple Silicon (M1+) |
| Xcode | 16.0+ (build from source) |

## Install

```bash
# Clone the repo
git clone https://github.com/jamesyong-42/mochi.git
cd mochi

# Open in Xcode and build
open Mochi.xcodeproj
```

Then hit **⌘R** to build and run. That's it.

> **Tip:** Click the **+** button in the app to create your first VM. Mochi handles the rest — downloading the macOS image, configuring hardware, and installing the guest OS.

## How It Works

```
┌─────────────────────────────────────────────────┐
│  Mochi App (SwiftUI)                            │
│  ┌───────────┐  ┌───────────┐  ┌─────────────┐ │
│  │ Dashboard  │  │  Wizard   │  │  Settings   │ │
│  │  (Cards)   │  │ (Create)  │  │  (Storage)  │ │
│  └─────┬─────┘  └─────┬─────┘  └──────┬──────┘ │
│        │               │               │        │
│  ┌─────▼───────────────▼───────────────▼──────┐ │
│  │           VMManager (@Observable)          │ │
│  └─────────────────┬──────────────────────────┘ │
│                    │                             │
│  ┌─────────────────▼──────────────────────────┐ │
│  │  Virtualization.framework (Apple Native)   │ │
│  │  VZVirtualMachine → VZMacPlatformConfig    │ │
│  └────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘

Storage: ~/Library/Application Support/Mochi/
├── VMs/{uuid}/
│   ├── config.json          # VM configuration
│   ├── disk.img             # Sparse disk image
│   ├── auxiliary-storage    # NVRAM
│   ├── hardware-model       # Platform identity
│   ├── machine-identifier   # Unique machine ID
│   └── saved-state          # Suspended state (optional)
└── IPSWCache/               # Cached macOS images
```

**Key design decisions:**

- **Sparse disk images** — a 64 GB disk only uses ~15 GB on your host until the guest fills it up
- **Native virtualization** — no translation layer, VMs run at near-bare-metal speed on Apple Silicon
- **JSON configs** — every VM's configuration is a plain JSON file you can inspect or back up
- **APFS cloning** — duplicating a VM uses copy-on-write, so clones are instant and space-efficient

## Project Structure

```
Mochi/
├── App/                  # App entry point & main view
├── Models/               # Data models (VMConfig, VMState, Theme)
├── ViewModels/           # State management (VMManager)
├── Views/                # SwiftUI views
│   ├── MochiCard.swift   # VM card component
│   ├── MochiWizard.swift # Create/edit VM sheet
│   ├── MenuBarView.swift # Menu bar extra
│   └── Components/       # Reusable UI components
└── Services/             # Core services
    ├── VirtualizationService.swift  # VM lifecycle
    ├── IPSWService.swift            # Image downloads
    └── StorageService.swift         # Disk & config I/O
```

## Contributing

Contributions are welcome! Here's how:

1. **Fork** the repo
2. **Create a branch** — `git checkout -b my-feature`
3. **Commit your changes** — `git commit -m "Add my feature"`
4. **Push** — `git push origin my-feature`
5. **Open a Pull Request**

Please keep PRs focused and include a clear description of what changed and why.

## Roadmap

- [ ] Linux guest support (Ubuntu, Fedora)
- [ ] Snapshots (multiple save states per VM)
- [ ] VM templates and presets
- [ ] Drag-and-drop file sharing
- [ ] Network configuration options
- [ ] Export/import VMs

## License

[MIT](LICENSE) — use it however you want.

---

<p align="center">
  Built with ♥ and SwiftUI on Apple Silicon
</p>
