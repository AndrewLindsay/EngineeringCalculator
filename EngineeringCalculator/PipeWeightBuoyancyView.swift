import SwiftUI

struct PipeWeightBuoyancyView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var materialStore: MaterialLibraryStore
    @Environment(\.projectCalculationUpdateContext) private var projectUpdateContext
    @State private var diameterMode: DiameterMode = .diameter
    @State private var insideValueMM = 300.0
    @State private var selectedPipeMaterialID: UUID?
    @State private var openedPipeMaterial: EngineeringMaterial?
    @State private var wallThicknessMM = 20.0
    @State private var internalDensity = 1000.0
    @State private var externalDensity = 1025.0
    @State private var extraLayers: [EditableLayer] = []
    @State private var showDetails = false
    @State private var showingAddLayer = false
    @State private var showingCalculationExporter = false
    @State private var calculationExportDocument: StandaloneCalculationFileDocument?
    @State private var calculationSaveError: String?
    @State private var projectUpdateMessage: String?
    @State private var baselineSignature: EditSignature?
    @State private var showingUnsavedCalculationAlert = false

    enum DiameterMode: String, CaseIterable, Identifiable { case diameter = "Internal Diameter"; case radius = "Internal Radius"; var id: String { rawValue } }
    struct EditableLayer: Identifiable { let id: UUID; var material: EngineeringMaterial; var thicknessMM: Double; init(id: UUID = UUID(), material: EngineeringMaterial, thicknessMM: Double = 3.0) { self.id = id; self.material = material; self.thicknessMM = thicknessMM } }
    private struct LayerEditSignature: Equatable { let id: UUID; let materialID: UUID; let thicknessMM: Double }
    private struct EditSignature: Equatable { let diameterMode: DiameterMode; let insideValueMM: Double; let pipeMaterialID: UUID?; let wallThicknessMM: Double; let internalDensity: Double; let externalDensity: Double; let layers: [LayerEditSignature] }

    private var pipeMaterial: EngineeringMaterial? {
        if let id = selectedPipeMaterialID { if let openedPipeMaterial, openedPipeMaterial.id == id { return openedPipeMaterial }; if let found = materialStore.steelMaterials.first(where: { $0.id == id }) { return found } }
        return openedPipeMaterial ?? materialStore.steelMaterials.first
    }
    private var internalDiameterM: Double { let m = max(0, insideValueMM) / 1000; return diameterMode == .diameter ? m : 2 * m }
    private var layers: [PipeLayer] { let steel = pipeMaterial ?? EngineeringMaterial(name: "Carbon Steel", category: "Steel", densityKgM3: 7850); var output = [PipeLayer(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: steel.name, thicknessM: max(0, wallThicknessMM) / 1000, material: steel)]; output += extraLayers.map { PipeLayer(id: $0.id, name: $0.material.name, thicknessM: max(0, $0.thicknessMM) / 1000, material: $0.material) }; return output }
    private var pipeConstruction: PipeConstruction { PipeConstruction(name: "Current Pipe", internalDiameterM: internalDiameterM, layers: layers, internalFluid: FluidDefinition(name: "Internal Fluid", densityKgM3: max(0, internalDensity)), externalFluid: FluidDefinition(name: "External Fluid", densityKgM3: max(0, externalDensity))) }
    private var materialValidation: PipeWeightMaterialValidation { PipeWeightBuoyancyCalculator.validateMaterials(construction: pipeConstruction) }
    private var result: PipeWeightBuoyancyResult? { materialValidation.canCalculate ? PipeWeightBuoyancyCalculator.calculate(construction: pipeConstruction) : nil }
    private var currentSignature: EditSignature { EditSignature(diameterMode: diameterMode, insideValueMM: insideValueMM, pipeMaterialID: pipeMaterial?.id, wallThicknessMM: wallThicknessMM, internalDensity: internalDensity, externalDensity: externalDensity, layers: extraLayers.map { LayerEditSignature(id: $0.id, materialID: $0.material.id, thicknessMM: $0.thicknessMM) }) }
    private var hasUnsavedProjectCaseChanges: Bool { guard projectUpdateContext != nil, let baselineSignature else { return false }; return currentSignature != baselineSignature }

    var body: some View {
        Form {
            pipeGeometrySection; additionalLayersSection; materialRequirementsSection
            Section("Layer Stack Used in Calculation") { layerTable }
            Section(String(localized: "pipeWeight.section.fluids")) { numericField("Internal fluid density (kg/m³)", value: $internalDensity); numericField("External fluid density (kg/m³)", value: $externalDensity) }
            resultsSection
            Section { DisclosureGroup("Calculation Details", isExpanded: $showDetails) { if let d = CalculationRegistry.definition(id: "pipeWeightBuoyancy")?.details { CalculationDetailsView(details: d) } } }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "pipeWeight.title") + (hasUnsavedProjectCaseChanges ? " •" : ""))
        .navigationBarBackButtonHidden(projectUpdateContext != nil)
        .toolbar {
            if projectUpdateContext != nil {
                ToolbarItem(placement: .navigation) { Button { requestCalculationExit() } label: { Label("Back", systemImage: "chevron.left") }.help("Return to project") }
            }
            ToolbarItem {
                if projectUpdateContext != nil { Button { _ = updateProjectCase() } label: { Label("Update Project Case", systemImage: "arrow.triangle.2.circlepath") }.disabled(result == nil || !hasUnsavedProjectCaseChanges).help(Text("tooltip.updateProjectCase")) }
                else { Button { saveStandaloneCalculation() } label: { Label("Save Calculation…", systemImage: "square.and.arrow.down") }.disabled(result == nil).help(Text("tooltip.saveCalculation")) }
            }
        }
        .standaloneCalculationOpen { document in try loadStandaloneCalculation(document) }
        .onAppear { initialisePipeMaterialSelection() }
        .onChange(of: materialStore.steelMaterials.map(\.id)) { _, _ in initialisePipeMaterialSelection() }
        .sheet(isPresented: $showingAddLayer) { NavigationStack { AddPipeLayerView { m, t in extraLayers.append(EditableLayer(material: m, thicknessMM: t)) }.environmentObject(materialStore) } }
        .fileExporter(isPresented: $showingCalculationExporter, document: calculationExportDocument, contentType: .engineeringCalculation, defaultFilename: calculationExportDocument.map { CalculationDocumentFileType.suggestedFilename(for: $0.document) }) { outcome in if case let .failure(error) = outcome { calculationSaveError = error.localizedDescription } }
        .alert("Unsaved Calculation Changes", isPresented: $showingUnsavedCalculationAlert) {
            Button("Update Project") { if updateProjectCase(showConfirmation: false) { dismiss() } }
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This calculation has changes that have not yet been copied into the project. Update the project case before returning?") }
        .alert("Save Calculation Failed", isPresented: Binding(get: { calculationSaveError != nil }, set: { if !$0 { calculationSaveError = nil } })) { Button("OK", role: .cancel) { calculationSaveError = nil } } message: { Text(calculationSaveError ?? "") }
        .alert("Project Case Updated", isPresented: Binding(get: { projectUpdateMessage != nil }, set: { if !$0 { projectUpdateMessage = nil } })) { Button("OK", role: .cancel) { projectUpdateMessage = nil } } message: { Text(projectUpdateMessage ?? "") }
    }

    private func loadStandaloneCalculation(_ document: CalculationDocument) throws -> String {
        let restored = try PipeWeightBuoyancyPersistence.restore(from: document); let construction = restored.construction
        guard let pipeLayer = construction.layers.first else { throw PipeWeightBuoyancyPersistence.RestoreError.missingInput("layer.0") }
        let recalculated = PipeWeightBuoyancyCalculator.calculate(construction: construction); let differences = PipeWeightBuoyancyPersistence.compareStoredOutputs(restored.storedOutputs, with: recalculated)
        diameterMode = .diameter; insideValueMM = construction.internalDiameterM * 1000; openedPipeMaterial = pipeLayer.material; selectedPipeMaterialID = pipeLayer.material.id; wallThicknessMM = pipeLayer.thicknessM * 1000
        extraLayers = construction.layers.dropFirst().map { EditableLayer(id: $0.id, material: $0.material, thicknessMM: $0.thicknessM * 1000) }; internalDensity = construction.internalFluid.densityKgM3; externalDensity = construction.externalFluid.densityKgM3
        baselineSignature = EditSignature(diameterMode: .diameter, insideValueMM: construction.internalDiameterM * 1000, pipeMaterialID: pipeLayer.material.id, wallThicknessMM: pipeLayer.thicknessM * 1000, internalDensity: construction.internalFluid.densityKgM3, externalDensity: construction.externalFluid.densityKgM3, layers: construction.layers.dropFirst().map { LayerEditSignature(id: $0.id, materialID: $0.material.id, thicknessMM: $0.thicknessM * 1000) })
        let name = document.calculations.first?.name ?? document.title; let layerText = "\(construction.layers.count) pipe layer\(construction.layers.count == 1 ? "" : "s")"
        if differences.isEmpty { return "\(name) was opened successfully. \(layerText) were restored and the recalculated outputs match the stored results. Embedded material snapshots are being used for this calculation and were not added to the Material Library." }
        return "\(name) was opened and \(layerText) were restored. Warning: \(differences.count) recalculated output\(differences.count == 1 ? "" : "s") differ from the stored results. Embedded material snapshots are being used for this calculation and were not added to the Material Library."
    }

    private func makeCurrentDocument(name: String) throws -> CalculationDocument { guard let result else { throw PipeWeightBuoyancyPersistence.RestoreError.missingInput("result") }; return try PipeWeightBuoyancyPersistence.makeDocument(name: name, construction: pipeConstruction, result: result) }
    private func requestCalculationExit() { if hasUnsavedProjectCaseChanges { showingUnsavedCalculationAlert = true } else { dismiss() } }
    @discardableResult private func updateProjectCase(showConfirmation: Bool = true) -> Bool {
        guard let context = projectUpdateContext else { return false }
        do { try context.update(try makeCurrentDocument(name: context.calculationName)); baselineSignature = currentSignature; if showConfirmation { projectUpdateMessage = "\(context.calculationName) has been updated in the current project. Save the project to persist the change to its .ecproject file." }; return true } catch { calculationSaveError = error.localizedDescription; return false }
    }
    private func saveStandaloneCalculation() { do { calculationExportDocument = StandaloneCalculationFileDocument(document: try makeCurrentDocument(name: String(localized: "pipeWeight.title"))); showingCalculationExporter = true } catch { calculationSaveError = error.localizedDescription } }

    @ViewBuilder private var pipeGeometrySection: some View {
        Section(String(localized: "pipeWeight.section.geometry")) {
            Picker("Inside dimension", selection: $diameterMode) { ForEach(DiameterMode.allCases) { mode in Text(mode.rawValue).tag(mode) } }
            numericField(diameterMode == .diameter ? "Internal Diameter (mm)" : "Internal Radius (mm)", value: $insideValueMM)
            Picker("Pipe material", selection: Binding(get: { selectedPipeMaterialID ?? pipeMaterial?.id }, set: { newID in selectedPipeMaterialID = newID; if newID != openedPipeMaterial?.id { openedPipeMaterial = nil } })) { if let openedPipeMaterial, !materialStore.steelMaterials.contains(where: { $0.id == openedPipeMaterial.id }) { Text("\(openedPipeMaterial.name) (embedded)").tag(Optional(openedPipeMaterial.id)) }; ForEach(materialStore.steelMaterials) { material in Text(material.name).tag(Optional(material.id)) } }
            LabeledContent("Pipe density") { if let density = pipeMaterial?.densityKgM3 { Text("\(density, format: .number.precision(.fractionLength(0))) kg/m³").foregroundStyle(.secondary) } else { Label("Missing", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) } }
            numericField("Pipe wall thickness (mm)", value: $wallThicknessMM)
        }
    }

    @ViewBuilder private var additionalLayersSection: some View {
        Section(String(localized: "pipeWeight.section.layers")) {
            ForEach($extraLayers) { $layer in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { VStack(alignment: .leading) { Text(layer.material.name).font(.headline); if let density = layer.material.densityKgM3 { Text("\(density, format: .number.precision(.fractionLength(0))) kg/m³").font(.caption).foregroundStyle(.secondary) } else { Label(String(localized: "validation.densityMissing"), systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red) } }; Spacer(); Button(role: .destructive) { deleteLayer(id: layer.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help(Text("tooltip.deleteLayer")).accessibilityLabel(Text("tooltip.deleteLayer")) }
                    numericField("Thickness (mm)", value: $layer.thicknessMM)
                    HStack { Button { moveLayer(id: layer.id, offset: -1) } label: { Label("Move Up", systemImage: "arrow.up") }.disabled(isFirst(layer.id)).help(Text("tooltip.moveLayerUp")); Button { moveLayer(id: layer.id, offset: 1) } label: { Label("Move Down", systemImage: "arrow.down") }.disabled(isLast(layer.id)).help(Text("tooltip.moveLayerDown")) }.buttonStyle(.borderless)
                }.padding(.vertical, 5)
            }
            Button { showingAddLayer = true } label: { Label("Add Layer", systemImage: "plus") }.help(Text("tooltip.addLayer"))
        }
    }

    @ViewBuilder private var materialRequirementsSection: some View { if !materialValidation.canCalculate { Section("Material Data Required") { ForEach(materialValidation.issues) { issue in materialIssueRow(issue) }; Text("Every solid layer requires density before this calculation can run. Edit the material in the Material Library or choose another material.").font(.caption).foregroundStyle(.secondary) } } else { Section { Text("Choose layer materials from the Material Library. Every solid layer requires density. Invalid materials may be added for validation testing, but results are blocked until all required properties are available.").font(.caption).foregroundStyle(.secondary) } } }
    private func materialIssueRow(_ issue: MaterialValidationIssue) -> some View { let isBlocking = issue.severity == .error; return Label { Text(issue.message) } icon: { Image(systemName: isBlocking ? "exclamationmark.triangle.fill" : "exclamationmark.circle") }.foregroundStyle(isBlocking ? Color.red : Color.orange) }
    private var layerTable: some View { ViewThatFits(in: .horizontal) { detailedLayerGrid; compactLayerList } }
    private var detailedLayerGrid: some View { Grid(alignment: .trailing, horizontalSpacing: 5) { GridRow { Text("#"); Text("Layer").frame(minWidth: 90, alignment: .leading); Text("ID\n(mm)"); Text("t\n(mm)"); Text("OD\n(mm)"); Text("Density\n(kg/m³)"); Text("Area\n(m²)"); Text("Mass\n(kg/m)") }.font(.caption2.bold()).multilineTextAlignment(.center); Divider().gridCellColumns(8); if let result { ForEach(Array(result.layers.enumerated()), id: \.element.id) { index, layer in GridRow { Text("\(index + 1)"); Text(layer.name).frame(minWidth: 90, alignment: .leading); tableNumber(layer.innerDiameterM * 1000, digits: 2); tableNumber(layer.thicknessM * 1000, digits: 2); tableNumber(layer.outerDiameterM * 1000, digits: 2); tableNumber(layer.densityKgM3, digits: 0); tableNumber(layer.areaM2, digits: 5); tableNumber(layer.massKgPerM, digits: 2) } } } else { GridRow { Text("Calculation unavailable").foregroundStyle(.secondary).gridCellColumns(8) } } }.font(.caption2) }
    private var compactLayerList: some View { VStack(spacing: 6) { ForEach(Array(layers.enumerated()), id: \.element.id) { index, layer in HStack { Text("\(index + 1). \(layer.name)"); Spacer(); Text(layer.material.densityKgM3.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "Missing") } } } }
    @ViewBuilder private var resultsSection: some View { Section(String(localized: "pipeWeight.section.results")) { if let result { resultRow("Final OD", result.finalOuterDiameterM * 1000, "mm"); resultRow("Dry pipe mass", result.pipeMassKgPerM, "kg/m"); resultRow("Dry pipe weight", result.pipeWeightKNPerM, "kN/m"); resultRow("Internal contents", result.contentsMassKgPerM, "kg/m"); resultRow("Displaced external fluid", result.displacedMassKgPerM, "kg/m"); resultRow("Submerged equivalent mass", result.submergedEquivalentMassKgPerM, "kg/m"); resultRow("Submerged weight", result.submergedWeightKNPerM, "kN/m"); LabeledContent("Condition") { Text(result.submergedWeightKNPerM >= 0 ? "Sinks" : "Floats").fontWeight(.semibold) } } else { Label(String(localized: "validation.calculationUnavailable"), systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) } } }
    private func numericField(_ title: String, value: Binding<Double>) -> some View { LabeledContent(title) { TextField(title, value: value, format: .number.precision(.fractionLength(0...4))).multilineTextAlignment(.trailing).frame(minWidth: 90) } }
    private func resultRow(_ title: String, _ value: Double, _ unit: String) -> some View { LabeledContent(title) { Text("\(value, format: .number.precision(.fractionLength(3))) \(unit)").monospacedDigit() } }
    private func tableNumber(_ value: Double, digits: Int) -> Text { Text(value.formatted(.number.precision(.fractionLength(digits)))) }
    private func deleteLayer(id: UUID) { extraLayers.removeAll { $0.id == id } }
    private func isFirst(_ id: UUID) -> Bool { extraLayers.first?.id == id }
    private func isLast(_ id: UUID) -> Bool { extraLayers.last?.id == id }
    private func moveLayer(id: UUID, offset: Int) { guard let index = extraLayers.firstIndex(where: { $0.id == id }) else { return }; let destination = index + offset; guard extraLayers.indices.contains(destination) else { return }; extraLayers.swapAt(index, destination) }
    private func initialisePipeMaterialSelection() { if let selectedPipeMaterialID, openedPipeMaterial?.id == selectedPipeMaterialID { return }; let steels = materialStore.steelMaterials; guard !steels.isEmpty else { selectedPipeMaterialID = nil; return }; if let selectedPipeMaterialID, steels.contains(where: { $0.id == selectedPipeMaterialID }) { return }; openedPipeMaterial = nil; selectedPipeMaterialID = steels.first?.id }
}

private struct AddPipeLayerView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMaterialID: UUID?
    @State private var thicknessMM = 3.0
    @State private var showingNewMaterial = false
    let onAdd: (EngineeringMaterial, Double) -> Void
    private var selectedMaterial: EngineeringMaterial? { store.allMaterials.first { $0.id == selectedMaterialID } }
    var body: some View {
        Form { Section("Material") { Picker("Material", selection: $selectedMaterialID) { Text("Select a material").tag(nil as UUID?); ForEach(store.categories, id: \.self) { category in Section(category) { ForEach(materials(in: category)) { material in Text(material.name).tag(Optional(material.id)) } } } }; if let material = selectedMaterial { LabeledContent("Category") { Text(material.category) }; LabeledContent("Density") { if let density = material.densityKgM3 { Text("\(density.formatted()) kg/m³") } else { Label("Missing – calculation will be blocked", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) } } }; Button { showingNewMaterial = true } label: { Label("Create New Material…", systemImage: "plus") }.help(Text("tooltip.createMaterial")) }; Section("Layer") { LabeledContent("Thickness (mm)") { TextField("Thickness", value: $thicknessMM, format: .number.precision(.fractionLength(0...4))).multilineTextAlignment(.trailing) } } }
        .navigationTitle("Add Layer")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Add") { guard let material = selectedMaterial else { return }; onAdd(material, max(0, thicknessMM)); dismiss() }.disabled(selectedMaterial == nil) } }
        .sheet(isPresented: $showingNewMaterial) { NavigationStack { MaterialEditorView().environmentObject(store) } }
    }
    private func materials(in category: String) -> [EngineeringMaterial] { store.allMaterials.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame } }
}
