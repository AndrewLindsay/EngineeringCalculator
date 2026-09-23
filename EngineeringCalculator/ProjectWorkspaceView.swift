import SwiftUI
import UniformTypeIdentifiers

struct ProjectWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectLibrary: ProjectLibraryStore
    @EnvironmentObject private var materialStore: MaterialLibraryStore
    @State private var workspace: ProjectWorkspaceModel
    @State private var savedDocument: CalculationDocument
    @State private var selectedCalculationID: UUID?
    @State private var showingProjectImporter = false
    @State private var showingCalculationImporter = false
    @State private var showingExporter = false
    @State private var exportDocument: ProjectCalculationFileDocument?
    @State private var showingAddCalculation = false
    @State private var renameTarget: SavedCalculation?
    @State private var renameText = ""
    @State private var errorMessage: String?
    @State private var showingUnsavedProjectAlert = false
    @State private var dismissAfterSave = false
    private let sourceURL: URL?

    init(initialDocument: CalculationDocument? = nil, sourceURL: URL? = nil) {
        let model: ProjectWorkspaceModel
        if let initialDocument, let loaded = try? ProjectWorkspaceModel(document: initialDocument) { model = loaded }
        else { model = ProjectWorkspaceModel() }
        _workspace = State(initialValue: model)
        _savedDocument = State(initialValue: model.document)
        self.sourceURL = sourceURL
    }

    private var isDirty: Bool { workspace.document != savedDocument }

    var body: some View {
        List(selection: $selectedCalculationID) {
            Section {
                if workspace.calculations.isEmpty {
                    ContentUnavailableView("No Calculations", systemImage: "doc.badge.plus", description: Text("Create a new calculation case or add an existing .eccalc file to this project."))
                } else {
                    ForEach(workspace.calculations) { calculation in
                        NavigationLink { projectCalculationDestination(calculation) } label: { calculationRow(calculation) }
                            .tag(calculation.id)
                            .help("Open \(calculation.name)")
                            .contextMenu { calculationMenu(calculation) }
                    }
                    .onMove(perform: moveCalculations)
                    .onDelete(perform: deleteCalculations)
                }
            } header: { Text(workspace.title) } footer: {
                Text("Project calculations retain their saved inputs, outputs and embedded material definitions. Opening a project does not import those materials into the global Material Library.")
            }
        }
        .navigationTitle(workspace.title + (isDirty ? " •" : ""))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { requestProjectExit() } label: { Label("Back", systemImage: "chevron.left") }
                    .help("Return to Projects")
            }
            ToolbarItemGroup {
                Menu {
                    Button { showingAddCalculation = true } label: { Label("New Calculation…", systemImage: "plus") }
                        .help("Create a new calculation case in this project")
                    Button { showingCalculationImporter = true } label: { Label("Add Existing Calculation…", systemImage: "doc.badge.plus") }
                        .help("Import an existing .eccalc calculation into this project")
                } label: { Label("Add Calculation", systemImage: "plus") }
                    .help("Add a calculation to this project")
                Button { saveProject() } label: { Label(sourceURL == nil ? "Save Project…" : "Save Project", systemImage: "square.and.arrow.down") }
                    .disabled(!isDirty && sourceURL != nil)
                    .help(sourceURL == nil ? "Save this project as an .ecproject file" : "Save changes to this project")
            }
        }
        .sheet(isPresented: $showingAddCalculation) {
            AddProjectCalculationView { calculatorID, name in createProjectCalculation(calculatorID: calculatorID, name: name) }
        }
        .alert("Rename Calculation", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
            TextField("Calculation name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Rename") { renameCalculation() }
        }
        .alert("Unsaved Project Changes", isPresented: $showingUnsavedProjectAlert) {
            Button("Save") { saveProject(thenDismiss: true) }
            Button("Don’t Save", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This project has changes that have not been written to its .ecproject file. Save them before returning to Projects?")
        }
        .alert("Project Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) { errorMessage = nil } } message: { Text(errorMessage ?? "") }
        .fileImporter(isPresented: $showingProjectImporter, allowedContentTypes: [.engineeringProject], allowsMultipleSelection: false) { result in openProject(result) }
        .fileImporter(isPresented: $showingCalculationImporter, allowedContentTypes: [.engineeringCalculation], allowsMultipleSelection: false) { result in importCalculation(result) }
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .engineeringProject, defaultFilename: exportDocument.map { CalculationDocumentFileType.suggestedFilename(for: $0.document) }) { result in
            switch result {
            case .success(let url):
                projectLibrary.register(document: workspace.document, at: url)
                savedDocument = workspace.document
                if dismissAfterSave { dismissAfterSave = false; dismiss() }
            case .failure(let error):
                dismissAfterSave = false
                errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder private func projectCalculationDestination(_ calculation: SavedCalculation) -> some View {
        let document = standaloneDocument(for: calculation)
        switch calculation.calculatorID {
        case PipeWeightBuoyancyPersistence.calculatorID:
            PipeWeightBuoyancyView().environment(\.initialStandaloneCalculationDocument, document).environment(\.projectCalculationUpdateContext, ProjectCalculationUpdateContext(calculationID: calculation.id, calculationName: calculation.name, update: { updatedDocument in try updateProjectCalculation(id: calculation.id, from: updatedDocument) }))
        default:
            ContentUnavailableView("Project Case Not Yet Editable", systemImage: "wrench.and.screwdriver", description: Text("\(title(for: calculation.calculatorID)) is stored safely in this project, but live project editing has not yet been connected for this calculator.")).navigationTitle(calculation.name)
        }
    }

    private func standaloneDocument(for calculation: SavedCalculation) -> CalculationDocument { CalculationDocument(kind: .standaloneCalculation, title: calculation.name, createdAt: calculation.createdAt, modifiedAt: calculation.modifiedAt, calculations: [calculation], embeddedMaterials: workspace.embeddedMaterials) }

    private func updateProjectCalculation(id: UUID, from document: CalculationDocument) throws {
        guard document.kind == .standaloneCalculation else { throw ProjectWorkspaceError.notAStandaloneCalculation }
        guard document.calculations.count == 1, let updatedCalculation = document.calculations.first else { throw ProjectWorkspaceError.invalidStandaloneCalculationCount(document.calculations.count) }
        try workspace.updateProjectCalculation(id: id, with: updatedCalculation, embeddedMaterials: document.embeddedMaterials)
    }

    private func createProjectCalculation(calculatorID: String, name: String) {
        do {
            switch calculatorID {
            case "pipeWeightBuoyancy":
                let steel = materialStore.steelMaterials.first ?? EngineeringMaterial(name: "Carbon Steel", category: "Steel", densityKgM3: 7850)
                let construction = PipeConstruction(name: "Current Pipe", internalDiameterM: 0.300, layers: [PipeLayer(name: steel.name, thicknessM: 0.020, material: steel)], internalFluid: FluidDefinition(name: "Internal Fluid", densityKgM3: 1000), externalFluid: FluidDefinition(name: "External Fluid", densityKgM3: 1025))
                let result = PipeWeightBuoyancyCalculator.calculate(construction: construction)
                let document = try PipeWeightBuoyancyPersistence.makeDocument(name: name, construction: construction, result: result)
                guard let calculationID = document.calculations.first?.id else { throw ProjectWorkspaceError.invalidStandaloneCalculationCount(document.calculations.count) }
                try workspace.addPortableCalculation(from: document)
                selectedCalculationID = calculationID
            default:
                let calculation = SavedCalculation(name: name, calculatorID: calculatorID)
                try workspace.addCalculation(calculation)
                selectedCalculationID = calculation.id
            }
        } catch { errorMessage = error.localizedDescription }
    }

    @ViewBuilder private func calculationRow(_ calculation: SavedCalculation) -> some View {
        HStack { Image(systemName: icon(for: calculation.calculatorID)).frame(width: 24); VStack(alignment: .leading, spacing: 3) { Text(calculation.name).fontWeight(.semibold); Text(title(for: calculation.calculatorID)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(calculation.inputs.count) inputs").font(.caption2).foregroundStyle(.secondary) }
    }

    @ViewBuilder private func calculationMenu(_ calculation: SavedCalculation) -> some View {
        Button("Rename…") { renameTarget = calculation; renameText = calculation.name }.help("Rename this project calculation")
        Button("Duplicate") { do { try workspace.duplicateCalculation(id: calculation.id) } catch { errorMessage = error.localizedDescription } }.help("Duplicate this calculation case")
        Divider()
        Button("Delete", role: .destructive) { do { try workspace.deleteCalculation(id: calculation.id) } catch { errorMessage = error.localizedDescription } }.help("Delete this calculation from the project")
    }

    private func moveCalculations(from source: IndexSet, to destination: Int) { guard source.count == 1, let index = source.first else { return }; do { try workspace.moveCalculation(from: index, to: destination) } catch { errorMessage = error.localizedDescription } }
    private func deleteCalculations(at offsets: IndexSet) { let ids = offsets.compactMap { workspace.calculations.indices.contains($0) ? workspace.calculations[$0].id : nil }; for id in ids { do { try workspace.deleteCalculation(id: id) } catch { errorMessage = error.localizedDescription } } }
    private func renameCalculation() { guard let target = renameTarget else { return }; do { try workspace.renameCalculation(id: target.id, to: renameText) } catch { errorMessage = error.localizedDescription }; renameTarget = nil }

    private func requestProjectExit() {
        if isDirty { showingUnsavedProjectAlert = true } else { dismiss() }
    }

    private func saveProject(thenDismiss: Bool = false) {
        if let sourceURL {
            do {
                let access = sourceURL.startAccessingSecurityScopedResource()
                defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }
                try CalculationDocumentFileIO.write(workspace.document, to: sourceURL)
                projectLibrary.register(document: workspace.document, at: sourceURL)
                savedDocument = workspace.document
                if thenDismiss { dismiss() }
            } catch { errorMessage = error.localizedDescription }
        } else {
            dismissAfterSave = thenDismiss
            exportDocument = ProjectCalculationFileDocument(document: workspace.document)
            showingExporter = true
        }
    }

    private func openProject(_ result: Result<[URL], Error>) {
        do { guard let url = try result.get().first else { return }; let document = try readSecurityScopedDocument(from: url); guard document.kind == .project else { throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(expected: .project, actualExtension: CalculationDocumentFileType.standaloneExtension) }; workspace = try ProjectWorkspaceModel(document: document); savedDocument = document; projectLibrary.register(document: document, at: url); selectedCalculationID = nil } catch { errorMessage = error.localizedDescription }
    }

    private func importCalculation(_ result: Result<[URL], Error>) {
        do { guard let url = try result.get().first else { return }; let document = try readSecurityScopedDocument(from: url); guard document.kind == .standaloneCalculation else { throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(expected: .standaloneCalculation, actualExtension: CalculationDocumentFileType.projectExtension) }; guard let importedID = document.calculations.first?.id else { throw ProjectWorkspaceError.invalidStandaloneCalculationCount(document.calculations.count) }; try workspace.addPortableCalculation(from: document); selectedCalculationID = importedID } catch { errorMessage = error.localizedDescription }
    }

    private func readSecurityScopedDocument(from url: URL) throws -> CalculationDocument { let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; do { return try CalculationDocumentFileIO.document(from: Data(contentsOf: url)) } catch let error as CalculationDocumentCodecError { throw error } catch { throw CalculationDocumentFileError.cannotRead(error.localizedDescription) } }
    private func registryDefinition(for calculatorID: String) -> CalculationDefinition? { switch calculatorID { case PipeWeightBuoyancyPersistence.calculatorID: return CalculationRegistry.definition(id: "pipeWeightBuoyancy"); case PipeHeatTransferPersistence.calculatorID: return CalculationRegistry.definition(id: "pipeHeatTransfer"); default: return CalculationRegistry.definition(id: calculatorID) } }
    private func title(for calculatorID: String) -> String { registryDefinition(for: calculatorID)?.title ?? calculatorID }
    private func icon(for calculatorID: String) -> String { registryDefinition(for: calculatorID)?.systemImage ?? "function" }
}

private struct AddProjectCalculationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCalculatorID = CalculationRegistry.all.first?.id ?? "pipeWeightBuoyancy"
    @State private var name = ""
    let onAdd: (String, String) -> Void
    var body: some View {
        NavigationStack { Form { Section("Calculation") { Picker("Calculator", selection: $selectedCalculatorID) { ForEach(CalculationRegistry.all) { definition in Text(definition.title).tag(definition.id) } }; TextField("Case name", text: $name) }; Section { Text("Creates a new project-owned calculation using the calculator's standard starting inputs. Changes remain in the current project workspace until you explicitly save the project.").font(.caption).foregroundStyle(.secondary) } }.navigationTitle("New Calculation").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.help("Cancel creating this calculation") }; ToolbarItem(placement: .confirmationAction) { Button("Create") { let definition = CalculationRegistry.definition(id: selectedCalculatorID); let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines); onAdd(selectedCalculatorID, cleaned.isEmpty ? (definition?.title ?? "Calculation") : cleaned); dismiss() }.help("Create this calculation in the project") } } }
    }
}

struct ProjectCalculationFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.engineeringProject] }
    static var writableContentTypes: [UTType] { [.engineeringProject] }
    let document: CalculationDocument
    init(document: CalculationDocument) { self.document = document }
    init(configuration: ReadConfiguration) throws { guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }; let decoded = try CalculationDocumentFileIO.document(from: data); guard decoded.kind == .project else { throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(expected: .project, actualExtension: "ecproject") }; document = decoded }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: try CalculationDocumentFileIO.data(for: document)) }
}
