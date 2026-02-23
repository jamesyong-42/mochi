import SwiftUI
import UniformTypeIdentifiers

struct SharedFolderPicker: View {
    @Binding var folders: [SharedFolder]
    @State private var showFileImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Shared Folders")
                    .font(.headline)
                Spacer()
                Button("Add Folder") {
                    showFileImporter = true
                }
                .accessibilityLabel("Add shared folder")
            }

            if folders.isEmpty {
                Text("No shared folders configured")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(folders) { folder in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(folder.name)
                                .font(.body)
                            Text(folder.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        if folder.readOnly {
                            Text("Read-only")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            folders.removeAll { $0.id == folder.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(folder.name)")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                let folder = SharedFolder(name: url.lastPathComponent, path: url.path)
                folders.append(folder)
            }
        }
    }
}
