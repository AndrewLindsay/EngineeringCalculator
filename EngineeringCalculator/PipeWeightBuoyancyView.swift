import SwiftUI

struct PipeWeightBuoyancyView: View {
    @EnvironmentObject private var materialStore: MaterialLibraryStore

    @State private var diameterMode: DiameterMode = .diameter
    @State private var insideValueMM = 300.0
    @State private var wallName = "Steel Pipe"
    @State private var wallThicknessMM = 20.0
    @State private var pipeDensity = 7850.0
    @State private var internalDensity = 1000.0
    @State private var externalDensity = 1025.0
    @State private var extraLayers: [EditableLayer] = []
    @State private var showDetails = false
    @State private var showingAddLayer = false

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
            self.id = id
            self.material = material
            self.thicknessMM = thicknessMM
        }
    }

    private var internalDiameterM: Double {
        let metres = max(0, insideValueMM) / 1000.0
        return diameterMode == .diameter ? metres : 2.0 * metres
    }

    private var layers: [PipeLayer] {
        var output = [
            PipeLayer(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: wallName,
                thicknessM: max(0, wallThicknessMM) / 1000.0,
                densityKgM3: max(0, pipeDensity)
            )
        ]

        output += extraLayers.map {
            PipeLayer(
                id: $0.id,
                name: $0.material.name,
                thicknessM: max(0, $0.thicknessMM) / 1000.0,
                material: $0.material
            )
        }
        return output
    }

    private var pipeConstruction: PipeConstruction {
        PipeConstruction(
            name: "Current Pipe",
            internalDiameterM: internalDiameterM,
            layers: layers,
            internalFluid: FluidDefinition(name: "Internal Fluid", densityKgM3: max(0, internalDensity)),
            externalFluid: FluidDefinition(name: "External Fluid", densityKgM3: max(0, externalDensity))
        )
    }

    private var result: PipeWeightBuoyancyResult {
        PipeWeightBuoyancyCalculator.calculate(construction: pipeConstruction)
    }

    var body: some View {
        Form {
            Section("Pipe Geometry") {
                Picker("Inside dimension", selection: $diameterMode) {
                    ForEach(DiameterMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                numericField(diameterMode.rawValue + " (mm)", value: $insideValueMM)
                TextField("Pipe layer name", text: $wallName)
                numericField("Pipe wall thickness (mm)", value: $wallThicknessMM)
                numericField("Pipe density (kg/m³)", value: $pipeDensity)
            }

            Section {
                ForEach($extraLayers) { $layer in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(layer.material.name).font(.headline)
                                Text("\(layer.material.densityKgM3 ?? 0, format: .number.precision(.fractionLength(0))) kg/m³")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { deleteLayer(id: layer.id) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete this layer")
                        }

                        numericField("Thickness (mm)", value: $layer.thicknessMM)

                        HStack {
                            Button { moveLayer(id: layer.id, offset: -1) } label: {
                                Label("Move Up", systemImage: "arrow.up")
                            }
                            .disabled(isFirst(layer.id))
                            Button { moveLayer(id: layer.id, offset: 1) } label: {
                                Label("Move Down", systemImage: "arrow.down")
                            }
                            .disabled(isLast(layer.id))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 5)
                }

                Button { showingAddLayer = true } label: {
                    Label("Add Layer", systemImage: "plus.circle")
                }
            } header: {
                Text("Additional Layers")
            } footer: {
                Text("Choose layer materials from the Material Library. Layers are calculated from inside to outside; use Move Up/Down to change their physical order.")
            }

            Section("Layer Stack Used in Calculation") { layerTable }

            Section("Fluids") {
                numericField("Internal fluid density (kg/m³)", value: $internalDensity)
                numericField("External fluid density (kg/m³)", value: $externalDensity)
            }

            Section("Results") {
                resultRow("Final OD", result.finalOuterDiameterM * 1000, "mm")
                resultRow("Dry pipe mass", result.pipeMassKgPerM, "kg/m")
                resultRow("Dry pipe weight", result.pipeWeightKNPerM, "kN/m")
                resultRow("Internal contents", result.contentsMassKgPerM, "kg/m")
                resultRow("Displaced external fluid", result.displacedMassKgPerM, "kg/m")
                resultRow("Submerged equivalent mass", result.submergedEquivalentMassKgPerM, "kg/m")
                resultRow("Submerged weight", result.submergedWeightKNPerM, "kN/m")
                LabeledContent("Condition") {
                    Text(result.submergedWeightKNPerM < 0 ? "Buoyant" : "Sinks").fontWeight(.semibold)
                }
            }

            Section {
                DisclosureGroup("Calculation Details", isExpanded: $showDetails) {
                    if let details = CalculationRegistry.definition(id: "pipeWeightBuoyancy")?.details {
                        CalculationDetailsView(details: details)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pipe Weight & Buoyancy")
        .sheet(isPresented: $showingAddLayer) {
            NavigationStack {
                AddPipeLayerView { material, thickness in
                    extraLayers.append(EditableLayer(material: material, thicknessMM: thickness))
                }
                .environmentObject(materialStore)
            }
        }
    }

    private var layerTable: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 5) {
                GridRow {
                    Text("#"); Text("Layer").frame(minWidth: 90, alignment: .leading)
                    Text("ID\n(mm)"); Text("t\n(mm)"); Text("OD\n(mm)")
                    Text("Density\n(kg/m³)"); Text("Area\n(m²)"); Text("Mass\n(kg/m)")
                }
                .font(.caption2.bold()).multilineTextAlignment(.center)
                Divider().gridCellColumns(8)

                ForEach(Array(result.layers.enumerated()), id: \.element.id) { index, layer in
                    GridRow {
                        Text("\(index + 1)")
                        Text(layer.name).frame(minWidth: 90, alignment: .leading)
                        tableNumber(layer.innerDiameterM * 1000, digits: 2)
                        tableNumber(layer.thicknessM * 1000, digits: 2)
                        tableNumber(layer.outerDiameterM * 1000, digits: 2)
                        tableNumber(layer.densityKgM3, digits: 0)
                        tableNumber(layer.areaM2, digits: 5)
                        tableNumber(layer.massKgPerM, digits: 2)
                    }.font(.caption2)
                }

                Divider().gridCellColumns(8)
                GridRow {
                    Text(""); Text("TOTAL").fontWeight(.semibold).frame(minWidth: 90, alignment: .leading)
                    Text(""); Text(""); tableNumber(result.finalOuterDiameterM * 1000, digits: 2)
                    Text(""); Text(""); tableNumber(result.pipeMassKgPerM, digits: 2).fontWeight(.semibold)
                }.font(.caption2)
            }
            .monospacedDigit().padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func numericField(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField(title, value: value, format: .number.precision(.fractionLength(0...4)))
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .frame(minWidth: 90)
        }
    }

    private func resultRow(_ title: String, _ value: Double, _ unit: String) -> some View {
        LabeledContent(title) {
            Text("\(value, format: .number.precision(.fractionLength(3))) \(unit)").monospacedDigit()
        }
    }

    private func tableNumber(_ value: Double, digits: Int) -> Text {
        Text(value.formatted(.number.precision(.fractionLength(digits))))
    }

    private func deleteLayer(id: UUID) { extraLayers.removeAll { $0.id == id } }
    private func isFirst(_ id: UUID) -> Bool { extraLayers.first?.id == id }
    private func isLast(_ id: UUID) -> Bool { extraLayers.last?.id == id }
    private func moveLayer(id: UUID, offset: Int) {
        guard let current = extraLayers.firstIndex(where: { $0.id == id }) else { return }
        let destination = current + offset
        guard extraLayers.indices.contains(destination) else { return }
        extraLayers.swapAt(current, destination)
    }
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
                    ForEach(store.builtInMaterials) { material in
                        Text("\(material.name) — Built-in").tag(Optional(material.id))
                    }
                    ForEach(store.userMaterials) { material in
                        Text("\(material.name) — My Materials").tag(Optional(material.id))
                    }
                }

                if let material = selectedMaterial {
                    LabeledContent("Category", value: material.category)
                    LabeledContent("Density") {
                        if let density = material.densityKgM3 {
                            Text("\(density, format: .number.precision(.fractionLength(0...2))) kg/m³")
                        } else {
                            Text("Not specified").foregroundStyle(.secondary)
                        }
                    }
                }

                Button { showingNewMaterial = true } label: {
                    Label("Create New Material…", systemImage: "plus")
                }
            }

            Section("Layer") {
                LabeledContent("Thickness (mm)") {
                    TextField("Thickness", value: $thicknessMM, format: .number.precision(.fractionLength(0...4)))
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }
        }
        .navigationTitle("Add Layer")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    guard let material = selectedMaterial else { return }
                    onAdd(material, max(0, thicknessMM)); dismiss()
                }
                .disabled(selectedMaterial?.densityKgM3 == nil || thicknessMM <= 0)
            }
        }
        .sheet(isPresented: $showingNewMaterial) {
            NavigationStack {
                NewPipeMaterialView { newMaterial in
                    store.add(newMaterial)
                    selectedMaterialID = newMaterial.id
                }
            }
        }
    }
}

private struct NewPipeMaterialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "General"
    @State private var grade = ""
    @State private var density = ""
    @State private var conductivity = ""
    @State private var heatCapacity = ""
    @State private var source = ""
    @State private var notes = ""
    let onSave: (EngineeringMaterial) -> Void

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $name)
                TextField("Category", text: $category)
                TextField("Grade / specification", text: $grade)
            }
            Section("Properties") {
                TextField("Density (kg/m³)", text: $density)
                TextField("Thermal conductivity (W/(m·K))", text: $conductivity)
                TextField("Specific heat capacity (J/(kg·K))", text: $heatCapacity)
            }
            Section("Traceability") {
                TextField("Source / basis", text: $source, axis: .vertical)
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("New Material")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let material = EngineeringMaterial(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        category: category,
                        densityKgM3: number(density),
                        grade: grade.isEmpty ? nil : grade,
                        thermalConductivityWMK: number(conductivity),
                        specificHeatCapacityJkgK: number(heatCapacity),
                        source: source.isEmpty ? nil : source,
                        notes: notes.isEmpty ? nil : notes
                    )
                    onSave(material); dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || number(density) == nil)
            }
        }
    }

    private func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }
}
