import SwiftUI
import UniformTypeIdentifiers

struct ProjectLibraryView: View {
    @EnvironmentObject private var projectLibrary: ProjectLibraryStore
    @State private var showingImporter = false
    @State private var showingNewProject = false
    @State private var newProjectName = ""
    @State private var renameEntry: ProjectLibraryEntry?
    @State private var renameText = ""
    @State private var errorMessage: String?
    @State private var pendingNewProject: CalculationDocument?
    @State private var pendingExistingEntry: ProjectLibraryEntry?
    @State private var duplicateImport: (document: CalculationDocument, entry: ProjectLibraryEntry)?

    var body: some View {
        List {
            Section {
                Button { newProjectName = ""; showingNewProject = true } label: { Label("New Project…", systemImage: "plus.rectangle.on.folder") }
                    .help("Create a new engineering project")
                Button { showingImporter = true } label: { Label("Open / Import Project…", systemImage: "folder.badge.plus") }
                    .help("Open or add an existing .ecproject file to the Project Library")
            }
            Section("Projects") {
                if projectLibrary.entries.isEmpty {
                    ContentUnavailableView("No Saved Projects", systemImage: "folder", description: Text("Create a project or import an existing .ecproject file. Saved projects will appear here."))
                } else {
                    ForEach(projectLibrary.entries) { entry in
                        NavigationLink { CataloguedProjectLoaderView(entry: entry) } label: {
                            VStack(alignment: .leading, spacing: 4) { Text(entry.title).fontWeight(.semibold); HStack { Text("\(entry.calculationCount) calculation\(entry.calculationCount == 1 ? "" : "s")"); Text("•"); Text(entry.modifiedAt.formatted(date: .abbreviated, time: .shortened)) }.font(.caption).foregroundStyle(.secondary) }
                        }
                        .help("Open \(entry.title)")
                        .contextMenu {
                            Button("Rename…") { renameEntry = entry; renameText = entry.title }.help("Rename the project title stored inside the project file")
                            Divider()
                            Button("Remove from Project List", role: .destructive) { projectLibrary.remove(id: entry.id) }.help("Remove this project from the library without deleting its .ecproject file")
                        }
                    }
                }
            }
        }
        .navigationTitle("Projects")
        .navigationDestination(isPresented: Binding(get: { pendingNewProject != nil }, set: { if !$0 { pendingNewProject = nil } })) {
            if let pendingNewProject { ProjectWorkspaceView(initialDocument: pendingNewProject) }
        }
        .navigationDestination(isPresented: Binding(get: { pendingExistingEntry != nil }, set: { if !$0 { pendingExistingEntry = nil } })) {
            if let pendingExistingEntry { CataloguedProjectLoaderView(entry: pendingExistingEntry) }
        }
        .alert("New Project", isPresented: $showingNewProject) {
            TextField("Project name", text: $newProjectName)
            Button("Cancel", role: .cancel) { }
            Button("Create") { createProject() }.disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: { Text("Enter a project name. This name is stored inside the .ecproject file and is independent of the filename.") }
        .alert("Rename Project", isPresented: Binding(get: { renameEntry != nil }, set: { if !$0 { renameEntry = nil } })) {
            TextField("Project name", text: $renameText)
            Button("Cancel", role: .cancel) { renameEntry = nil }
            Button("Rename") { renameProjectFromLibrary() }.disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: { Text("Renaming changes the project title stored inside the project. It does not rename the .ecproject file.") }
        .alert("Project Already in Library", isPresented: Binding(get: { duplicateImport != nil }, set: { if !$0 { duplicateImport = nil } })) {
            Button("Open Existing Project") { openExistingDuplicate() }
            Button("Create Independent Copy") { createIndependentCopy() }
            Button("Cancel", role: .cancel) { duplicateImport = nil }
        } message: {
            Text("This file has the same project identity as ‘\(duplicateImport?.entry.title ?? "")’. Opening it again would create two references to the same project. Open the existing project or create a new independent copy with its own project identity.")
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.engineeringProject], allowsMultipleSelection: false) { result in importProject(result) }
        .alert("Project Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }

    private func createProject() {
        let cleaned = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        pendingNewProject = ProjectWorkspaceModel(title: cleaned).document
    }

    private func renameProjectFromLibrary() {
        guard let entry = renameEntry else { return }
        let cleaned = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        do {
            let url = try projectLibrary.resolvedURL(for: entry)
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let decoded = try CalculationDocumentFileIO.document(from: data)
            var workspace = try ProjectWorkspaceModel(document: decoded)
            try workspace.renameProject(cleaned)
            let updated = workspace.document
            try CalculationDocumentFileIO.data(for: updated).write(to: url, options: .atomic)
            projectLibrary.register(document: updated, at: url)
        } catch { errorMessage = error.localizedDescription }
        renameEntry = nil
    }

    private func importProject(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let document = try CalculationDocumentFileIO.document(from: data)
            guard document.kind == .project else {
                throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(expected: .project, actualExtension: url.pathExtension)
            }

            if let existing = projectLibrary.entry(forProjectID: document.id) {
                duplicateImport = (document, existing)
                return
            }
            projectLibrary.register(document: document, at: url)
        } catch { errorMessage = error.localizedDescription }
    }

    private func openExistingDuplicate() {
        pendingExistingEntry = duplicateImport?.entry
        duplicateImport = nil
    }

    private func createIndependentCopy() {
        guard let source = duplicateImport?.document else { return }
        let now = Date()
        pendingNewProject = CalculationDocument(
            id: UUID(),
            documentFormatVersion: source.documentFormatVersion,
            kind: .project,
            title: "\(source.title) Copy",
            createdAt: now,
            modifiedAt: now,
            calculations: source.calculations,
            embeddedMaterials: source.embeddedMaterials,
            notes: source.notes
        )
        duplicateImport = nil
    }
}

private struct CataloguedProjectLoaderView: View {
    @EnvironmentObject private var projectLibrary: ProjectLibraryStore
    let entry: ProjectLibraryEntry
    @State private var document: CalculationDocument?
    @State private var errorMessage: String?
    var body: some View { Group { if let document { ProjectWorkspaceView(initialDocument: document) } else if let errorMessage { ContentUnavailableView("Project Could Not Be Opened", systemImage: "exclamationmark.triangle", description: Text(errorMessage)) } else { ProgressView("Opening \(entry.title)…") } }.task { load() } }
    private func load() {
        guard document == nil, errorMessage == nil else { return }
        do {
            let url = try projectLibrary.resolvedURL(for: entry)
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let decoded = try CalculationDocumentFileIO.document(from: data)
            guard decoded.kind == .project else { throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(expected: .project, actualExtension: url.pathExtension) }
            projectLibrary.refresh(entry, with: decoded)
            document = decoded
        } catch { errorMessage = error.localizedDescription }
    }
}
