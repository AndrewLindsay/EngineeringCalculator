import SwiftUI
import UniformTypeIdentifiers

struct ProjectWorkspaceView: View {
    @State private var workspace = ProjectWorkspaceModel()
    @State private var selectedCalculationID: UUID?
    @State private var showingProjectImporter = false
    @State private var showingCalculationImporter = false
    @State private var showingExporter = false
    @State private var exportDocument: ProjectCalculationFileDocument?
    @State private var showingAddCalculation = false
    @State private var renameTarget: SavedCalculation?
    @State private var renameText = ""
    @State private var errorMessage: String?

    var body: some View {
        List(selection: $selectedCalculationID) {
            Section {
                if workspace.calculations.isEmpty {
                    ContentUnavailableView(
                        "No Calculations",
                        systemImage: "doc.badge.plus",
                        description: Text("Create a new calculation case or add an existing .eccalc file to this project.")
                    )
                } else {
                    ForEach(workspace.calculations) { calculation in
                        NavigationLink {
                            projectCalculationDestination(calculation)
                        } label: {
                            calculationRow(calculation)
                        }
                        .tag(calculation.id)
                        .contextMenu { calculationMenu(calculation) }
                    }
                    .onMove(perform: moveCalculations)
                    .onDelete(perform: deleteCalculations)
                }
            } header: {
                Text(workspace.title)
            } footer: {
                Text("Project calculations retain their saved inputs, outputs and embedded material definitions. Opening a project does not import those materials into the global Material Library.")
            }
        }
        .navigationTitle(workspace.title)
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button { showingAddCalculation = true } label: {
                        Label("New Calculation…", systemImage: "plus")
                    }
                    Button { showingCalculationImporter = true } label: {
                        Label("Add Existing Calculation…", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Label("Add Calculation", systemImage: "plus")
                }
                Button { saveProject() } label: {
                    Label("Save Project…", systemImage: "square.and.arrow.down")
                }
                Button { showingProjectImporter = true } label: {
                    Label("Open Project…", systemImage: "folder")
                }
            }
        }
        .sheet(isPresented: $showingAddCalculation) {
            AddProjectCalculationView { calculation in
                do { try workspace.addCalculation(calculation) }
                catch { errorMessage = error.localizedDescription }
            }
        }
        .alert("Rename Calculation", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Calculation name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Rename") { renameCalculation() }
        }
        .alert("Project Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .fileImporter(isPresented: $showingProjectImporter, allowedContentTypes: [.engineeringProject], allowsMultipleSelection: false) { result in
            openProject(result)
        }
        .fileImporter(isPresented: $showingCalculationImporter, allowedContentTypes: [.engineeringCalculation], allowsMultipleSelection: false) { result in
            importCalculation(result)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .engineeringProject,
            defaultFilename: exportDocument.map { CalculationDocumentFileType.suggestedFilename(for: $0.document) }
        ) { result in
            if case let .failure(error) = result { errorMessage = error.localizedDescription }
        }
    }

    @ViewBuilder
    private func projectCalculationDestination(_ calculation: SavedCalculation) -> some View {
        let document = standaloneDocument(for: calculation)
        switch calculation.calculatorID {
        case PipeWeightBuoyancyPersistence.calculatorID:
            PipeWeightBuoyancyView()
                .environment(\.initialStandaloneCalculationDocument, document)
        default:
            ContentUnavailableView(
                "Project Case Not Yet Editable",
                systemImage: "wrench.and.screwdriver",
                description: Text("\(title(for: calculation.calculatorID)) is stored safely in this project, but live project editing has not yet been connected for this calculator.")
            )
            .navigationTitle(calculation.name)
        }
    }

    private func standaloneDocument(for calculation: SavedCalculation) -> CalculationDocument {
        CalculationDocument(
            kind: .standaloneCalculation,
            title: calculation.name,
            createdAt: calculation.createdAt,
            modifiedAt: calculation.modifiedAt,
            calculations: [calculation],
            embeddedMaterials: workspace.embeddedMaterials
        )
    }

    @ViewBuilder
    private func calculationRow(_ calculation: SavedCalculation) -> some View {
        HStack {
            Image(systemName: icon(for: calculation.calculatorID))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(calculation.name).fontWeight(.semibold)
                Text(title(for: calculation.calculatorID))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(calculation.inputs.count) inputs")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func calculationMenu(_ calculation: SavedCalculation) -> some View {
        Button("Rename…") {
            renameTarget = calculation
            renameText = calculation.name
        }
        Button("Duplicate") {
            do { try workspace.duplicateCalculation(id: calculation.id) }
            catch { errorMessage = error.localizedDescription }
        }
        Divider()
        Button("Delete", role: .destructive) {
            do { try workspace.deleteCalculation(id: calculation.id) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func moveCalculations(from source: IndexSet, to destination: Int) {
        guard source.count == 1, let index = source.first else { return }
        do { try workspace.moveCalculation(from: index, to: destination) }
        catch { errorMessage = error.localizedDescription }
    }

    private func deleteCalculations(at offsets: IndexSet) {
        let ids = offsets.compactMap { workspace.calculations.indices.contains($0) ? workspace.calculations[$0].id : nil }
        for id in ids {
            do { try workspace.deleteCalculation(id: id) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func renameCalculation() {
        guard let target = renameTarget else { return }
        do { try workspace.renameCalculation(id: target.id, to: renameText) }
        catch { errorMessage = error.localizedDescription }
        renameTarget = nil
    }

    private func saveProject() {
        exportDocument = ProjectCalculationFileDocument(document: workspace.document)
        showingExporter = true
    }

    private func openProject(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let document = try readSecurityScopedDocument(from: url)
            guard document.kind == .project else {
                throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(expected: .project, actualExtension: CalculationDocumentFileType.standaloneExtension)
            }
            workspace = try ProjectWorkspaceModel(document: document)
            selectedCalculationID = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importCalculation(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let document = try readSecurityScopedDocument(from: url)
            guard document.kind == .standaloneCalculation else {
                throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(expected: .standaloneCalculation, actualExtension: CalculationDocumentFileType.projectExtension)
            }
            guard let importedID = document.calculations.first?.id else {
                throw ProjectWorkspaceError.invalidStandaloneCalculationCount(document.calculations.count)
            }
            try workspace.addPortableCalculation(from: document)
            selectedCalculationID = importedID
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// SwiftUI's fileImporter may vend a security-scoped provider URL whose temporary
    /// filename has no Engineering Calculator extension. The importer has already filtered
    /// the user's selection by UTType, so decode the payload directly here and validate its
    /// document kind in the calling operation instead of validating the provider URL suffix.
    private func readSecurityScopedDocument(from url: URL) throws -> CalculationDocument {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            return try CalculationDocumentFileIO.document(from: data)
        } catch let error as CalculationDocumentCodecError {
            throw error
        } catch {
            throw CalculationDocumentFileError.cannotRead(error.localizedDescription)
        }
    }

    private func title(for calculatorID: String) -> String {
        CalculationRegistry.definition(id: calculatorID)?.title ?? calculatorID
    }

    private func icon(for calculatorID: String) -> String {
        CalculationRegistry.definition(id: calculatorID)?.systemImage ?? "function"
    }
}

private struct AddProjectCalculationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCalculatorID = CalculationRegistry.all.first?.id ?? "pipeWeightBuoyancy"
    @State private var name = ""
    let onAdd: (SavedCalculation) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Calculation") {
                    Picker("Calculator", selection: $selectedCalculatorID) {
                        ForEach(CalculationRegistry.all) { definition in
                            Text(definition.title).tag(definition.id)
                        }
                    }
                    TextField("Case name", text: $name)
                }
                Section {
                    Text("Creates a new project case container. Live editing of a newly created project-owned case will be connected in the next increment. To add a complete calculation now, use Add Existing Calculation and select an .eccalc file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Calculation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let definition = CalculationRegistry.definition(id: selectedCalculatorID)
                        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let calculation = SavedCalculation(
                            name: cleaned.isEmpty ? (definition?.title ?? "Calculation") : cleaned,
                            calculatorID: selectedCalculatorID
                        )
                        onAdd(calculation)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProjectCalculationFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.engineeringProject] }
    static var writableContentTypes: [UTType] { [.engineeringProject] }

    let document: CalculationDocument

    init(document: CalculationDocument) {
        self.document = document
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoded = try CalculationDocumentFileIO.document(from: data)
        guard decoded.kind == .project else {
            throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(expected: .project, actualExtension: "ecproject")
        }
        document = decoded
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try CalculationDocumentFileIO.data(for: document))
    }
}
