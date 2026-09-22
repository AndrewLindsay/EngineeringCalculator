import SwiftUI

struct PipeWeightBuoyancyView: View {
    @EnvironmentObject private var materialStore: MaterialLibraryStore
    @State private var diameterMode: DiameterMode = .diameter
    @State private var insideValueMM = 300.0
    @State private var selectedPipeMaterialID: UUID?
    @State private var wallThicknessMM = 20.0
    @State private var internalDensity = 1000.0
    @State private var externalDensity = 1025.0
    @State private var extraLayers: [EditableLayer] = []
    @State private var showDetails = false
    @State private var showingAddLayer = false
    @State private var showingCalculationExporter = false
    @State private var calculationExportDocument: StandaloneCalculationFileDocument?
    @State private var calculationSaveError: String?

    enum DiameterMode: String, CaseIterable, Identifiable {
        case diameter = "Internal Diameter"
        case radius = "Internal Radius"
        var id: String { rawValue }
    }

    struct EditableLayer: Identifiable {
        let id: UUID
        var material: EngineeringMaterial
        var thicknessMM: Double
        init(id: UUID = UUID(), material: EngineeringMaterial, thicknessMM: Double = 3.0) {
            self.id = id; self.material = material; self.thicknessMM = thicknessMM
        }
    }

    private var pipeMaterial: EngineeringMaterial? {
        if let id = selectedPipeMaterialID,
           let found = materialStore.steelMaterials.first(where: { $0.id == id }) { return found }
        return materialStore.steelMaterials.first
    }
    private var internalDiameterM: Double {
        let m = max(0, insideValueMM) / 1000
        return diameterMode == .diameter ? m : 2 * m
    }
    private var layers: [PipeLayer] {
        let steel = pipeMaterial ?? EngineeringMaterial(name: "Carbon Steel", category: "Steel", densityKgM3: 7850)
        var output = [PipeLayer(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: steel.name, thicknessM: max(0, wallThicknessMM) / 1000, material: steel)]
        output += extraLayers.map { PipeLayer(id: $0.id, name: $0.material.name, thicknessM: max(0, $0.thicknessMM) / 1000, material: $0.material) }
        return output
    }
    private var pipeConstruction: PipeConstruction {
        PipeConstruction(name: "Current Pipe", internalDiameterM: internalDiameterM, layers: layers,
                         internalFluid: FluidDefinition(name: "Internal Fluid", densityKgM3: max(0, internalDensity)),
                         externalFluid: FluidDefinition(name: "External Fluid", densityKgM3: max(0, externalDensity)))
    }
    private var materialValidation: PipeWeightMaterialValidation { PipeWeightBuoyancyCalculator.validateMaterials(construction: pipeConstruction) }
    private var result: PipeWeightBuoyancyResult? { materialValidation.canCalculate ? PipeWeightBuoyancyCalculator.calculate(construction: pipeConstruction) : nil }

    var body: some View {
        Form {
            pipeGeometrySection
            additionalLayersSection
            materialRequirementsSection
            Section("Layer Stack Used in Calculation") { layerTable }
            Section("Fluids") {
                numericField("Internal fluid density (kg/m³)", value: $internalDensity)
                numericField("External fluid density (kg/m³)", value: $externalDensity)
            }
            resultsSection
            Section { DisclosureGroup("Calculation Details", isExpanded: $showDetails) { if let d = CalculationRegistry.definition(id: "pipeWeightBuoyancy")?.details { CalculationDetailsView(details: d) } } }
        }
        .formStyle(.grouped)
        .navigationTitle("Pipe Weight & Buoyancy")
        .toolbar {
            ToolbarItem {
                Button { saveStandaloneCalculation() } label: {
                    Label("Save Calculation…", systemImage: "square.and.arrow.down")
                }
                .disabled(result == nil)
            }
        }
        .standaloneCalculationOpenValidation()
        .onAppear { initialisePipeMaterialSelection() }
        .onChange(of: materialStore.steelMaterials.map(\.id)) { _, _ in initialisePipeMaterialSelection() }
        .sheet(isPresented: $showingAddLayer) {
            NavigationStack { AddPipeLayerView { m, t in extraLayers.append(EditableLayer(material: m, thicknessMM: t)) }.environmentObject(materialStore) }
        }
        .fileExporter(
            isPresented: $showingCalculationExporter,
            document: calculationExportDocument,
            contentType: .engineeringCalculation,
            defaultFilename: calculationExportDocument.map { CalculationDocumentFileType.suggestedFilename(for: $0.document) }
        ) { outcome in
            if case let .failure(error) = outcome { calculationSaveError = error.localizedDescription }
        }
        .alert("Save Calculation Failed", isPresented: Binding(
            get: { calculationSaveError != nil },
            set: { if !$0 { calculationSaveError = nil } }
        )) {
            Button("OK", role: .cancel) { calculationSaveError = nil }
        } message: {
            Text(calculationSaveError ?? "")
        }
    }

    private func saveStandaloneCalculation() {
        guard let result else { return }
        do {
            let document = try PipeWeightBuoyancyPersistence.makeDocument(
                name: "Pipe Weight & Buoyancy",
                construction: pipeConstruction,
                result: result
            )
            calculationExportDocument = StandaloneCalculationFileDocument(document: document)
            showingCalculationExporter = true
        } catch {
            calculationSaveError = error.localizedDescription
        }
    }

    @ViewBuilder private var pipeGeometrySection: some View {
        Section("Pipe Geometry") {
            Picker("Inside dimension", selection: $diameterMode) { ForEach(DiameterMode.allCases) { Text($0.rawValue).tag($0) } }
            numericField(diameterMode == .diameter ? "Internal Diameter (mm)" : "Internal Radius (mm)", value: $insideValueMM)
            Picker("Pipe material", selection: Binding(get: { selectedPipeMaterialID ?? pipeMaterial?.id }, set: { selectedPipeMaterialID = $0 })) {
                ForEach(materialStore.steelMaterials) { Text($0.name).tag(Optional($0.id)) }
            }
            if let steel = pipeMaterial { LabeledContent("Pipe density") { Text("\(steel.densityKgM3, format: .number.precision(.fractionLength(0))) kg/m³").foregroundStyle(.secondary) } }
            numericField("Pipe wall thickness (mm)", value: $wallThicknessMM)
        }
    }

    @ViewBuilder private var additionalLayersSection: some View {
        Section("Additional Layers") {
            ForEach($extraLayers) { $layer in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { VStack(alignment: .leading) { Text(layer.material.name).font(.headline); if let density = layer.material.densityKgM3 { Text("\(density, format: .number.precision(.fractionLength(0))) kg/m³").font(.caption).foregroundStyle(.secondary) } else { Label("Density missing", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red) } }; Spacer(); Button(role: .destructive) { deleteLayer(id: layer.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless) }
                    numericField("Thickness (mm)", value: $layer.thicknessMM)
                    HStack { Button { moveLayer(id: layer.id, offset: -1) } label: { Label("Move Up", systemImage: "arrow.up") }.disabled(isFirst(id: layer.id)); Button { moveLayer(id: layer.id, offset: 1) } label: { Label("Move Down", systemImage: "arrow.down") }.disabled(isLast(id: layer.id)) }.buttonStyle(.borderless)
                }.padding(.vertical, 5)
            }
            Button { showingAddLayer = true } label: { Label("Add Layer", systemImage: "plus") }
        }
    }

    @ViewBuilder private var materialRequirementsSection: some View {
        if !materialValidation.canCalculate {
            Section("Material Data Required") {
                ForEach(materialValidation.issues) { issue in Label { Text(issue.message) } icon: { Image(systemName: issue.severity == .blocking ? "exclamationmark.triangle.fill" : "exclamationmark.circle") }.foregroundStyle(issue.severity == .blocking ? .red : .orange) }
                Text("Every solid layer requires density before this calculation can run. Edit the material in the Material Library or choose another material.").font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Section { Text("Choose layer materials from the Material Library. Every solid layer requires density. Invalid materials may be added for validation testing, but results are blocked until all required properties are available.").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private var layerTable: some View {
        ViewThatFits(in: .horizontal) { Grid(alignment: .trailing, horizontalSpacing: 5) { GridRow { Text("#"); Text("Layer").frame(minWidth:90,alignment:.leading); Text("ID\n(mm)"); Text("t\n(mm)"); Text("OD\n(mm)"); Text("Density\n(kg/m³)"); Text("Area\n(m²)"); Text("Mass\n(kg/m)") }.font(.caption2.bold()).multilineTextAlignment(.center); Divider().gridCellColumns(8); if let result { ForEach(Array(result.layers.enumerated()), id: \.element.id) { i, l in GridRow { Text("\(i+1)"); Text(l.name).frame(minWidth:90,alignment:.leading); Text(tableNumber(l.innerDiameterM*1000,digits:2)); Text(tableNumber(l.thicknessM*1000,digits:2)); Text(tableNumber(l.outerDiameterM*1000,digits:2)); tableNumber(l.densityKgM3,digits:0); tableNumber(l.areaM2,digits:5); tableNumber(l.massKgPerM,digits:2) } } } else { GridRow { Text("Calculation unavailable").foregroundStyle(.secondary).gridCellColumns(8) } } }.font(.caption2)
            ForEach(Array(layers.enumerated()), id: \.element.id) { i, l in HStack { Text("\(i+1). \(l.name)"); Spacer(); Text(l.material.densityKgM3.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "Missing") } }
        }
    }

    @ViewBuilder private var resultsSection: some View {
        Section("Results") {
            if let result {
                resultRow("Final OD", result.finalOuterDiameterM * 1000, "mm")
                resultRow("Dry pipe mass", result.pipeMassKgPerM, "kg/m")
                resultRow("Dry pipe weight", result.pipeWeightKNPerM, "kN/m")
                resultRow("Internal contents", result.contentsMassKgPerM, "kg/m")
                resultRow("Displaced external fluid", result.displacedMassKgPerM, "kg/m")
                resultRow("Submerged equivalent mass", result.submergedEquivalentMassKgPerM, "kg/m")
                resultRow("Submerged weight", result.submergedWeightKNPerM, "kN/m")
                LabeledContent("Condition") { Text(result.submergedWeightKNPerM >= 0 ? "Sinks" : "Floats").fontWeight(.semibold) }
            } else { Label("Results unavailable until all required material properties are present.", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
        }
    }

    private func numericField(_ title: String, value: Binding<Double>) -> some View { LabeledContent(title) { TextField(title, value: value, format: .number.precision(.fractionLength(0...4))).multilineTextAlignment(.trailing).frame(minWidth:90) } }
    private func resultRow(_ title: String, _ value: Double, _ unit: String) -> some View { LabeledContent(title) { Text("\(value, format: .number.precision(.fractionLength(3))) \(unit)").monospacedDigit() } }
    private func tableNumber(_ value: Double, digits: Int) -> Text { Text(value.formatted(.number.precision(.fractionLength(digits)))) }
    private func deleteLayer(id: UUID) { extraLayers.removeAll { $0.id == id } }
    private func isFirst(_ id: UUID) -> Bool { extraLayers.first?.id == id }
    private func isLast(_ id: UUID) -> Bool { extraLayers.last?.id == id }
    private func moveLayer(id: UUID, offset: Int) { guard let i = extraLayers.firstIndex(where: { $0.id == id }) else { return }; let d = i+offset; guard extraLayers.indices.contains(d) else { return }; extraLayers.swapAt(i,d) }
    private func initialisePipeMaterialSelection() { let steels=materialStore.steelMaterials; guard !steels.isEmpty else{selectedPipeMaterialID=nil;return}; if let selectedPipeMaterialID, steels.contains(where:{$0.id==selectedPipeMaterialID}){return}; selectedPipeMaterialID=steels.first?.id }
}

private struct AddPipeLayerView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMaterialID: UUID?
    @State private var thicknessMM = 3.0
    @State private var showingNewMaterial = false
    let onAdd: (EngineeringMaterial, Double) -> Void

    private var selectedMaterial: EngineeringMaterial? {
        store.allMaterials.first { $0.id == selectedMaterialID }
    }

    var body: some View {
        Form {
            Section("Material") {
                Picker("Material", selection: $selectedMaterialID) {
                    Text("Select a material").tag(nil as UUID?)
                    ForEach(store.categories, id: \.self) { category in
                        Section(category) {
                            ForEach(materials(in: category)) { material in
                                Text(material.name).tag(Optional(material.id))
                            }
                        }
                    }
                }

                if let material = selectedMaterial {
                    LabeledContent("Category") {
                        Text(material.category)
                    }
                    LabeledContent("Density") {
                        if let density = material.densityKgM3 {
                            Text("\(density.formatted()) kg/m³")
                        } else {
                            Label("Missing — calculation will be blocked", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                Button {
                    showingNewMaterial = true
                } label: {
                    Label("Create New Material…", systemImage: "plus")
                }
            }

            Section("Layer") {
                LabeledContent("Thickness (mm)") {
                    TextField("Thickness", value: $thicknessMM, format: .number.precision(.fractionLength(0...4)))
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .navigationTitle("Add Layer")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    guard let material = selectedMaterial else { return }
                    onAdd(material, max(0, thicknessMM))
                    dismiss()
                }
                .disabled(selectedMaterial == nil)
            }
        }
        .sheet(isPresented: $showingNewMaterial) {
            NavigationStack {
                MaterialEditorView()
                    .environmentObject(store)
            }
        }
    }

    private func materials(in category: String) -> [EngineeringMaterial] {
        store.allMaterials.filter {
            $0.category.caseInsensitiveCompare(category) == .orderedSame
        }
    }
}
