import SwiftUI
import UniformTypeIdentifiers

struct ProjectLibraryView: View {
    @EnvironmentObject private var projectLibrary: ProjectLibraryStore
    @State private var showingImporter = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ProjectWorkspaceView()
                } label: {
                    Label("New Project", systemImage: "plus.rectangle.on.folder")
                }

                Button {
                    showingImporter = true
                } label: {
                    Label("Open / Import Project…", systemImage: "folder.badge.plus")
                }
            }

            Section("Projects") {
                if projectLibrary.entries.isEmpty {
                    ContentUnavailableView(
                        "No Saved Projects",
                        systemImage: "folder",
                        description: Text("Create a project or import an existing .ecproject file. Saved projects will appear here.")
                    )
                } else {
                    ForEach(projectLibrary.entries) { entry in
                        NavigationLink {
                            ProjectWorkspaceView(libraryEntry: entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title).fontWeight(.semibold)
                                HStack {
                                    Text("\(entry.calculationCount) calculation\(entry.calculationCount == 1 ? "" : "s")")
                                    Text("•")
                                    Text(entry.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .contextMenu {
                            Button("Remove from Project List", role: .destructive) {
                                projectLibrary.remove(id: entry.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Projects")
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.engineeringProject],
            allowsMultipleSelection: false
        ) { result in
            importProject(result)
        }
        .alert("Project Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func importProject(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let document = try CalculationDocumentFileIO.document(from: data)
            guard document.kind == .project else {
                throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(
                    expected: .project,
                    actualExtension: url.pathExtension
                )
            }
            projectLibrary.register(document: document, at: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
