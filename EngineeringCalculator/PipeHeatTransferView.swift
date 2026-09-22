import SwiftUI

struct PipeHeatTransferView: View {
    @EnvironmentObject private var materialStore: MaterialLibraryStore

    @State private var internalDiameterMM = 300.0
    @State private var insideTemperatureC = 100.0
    @State private var outsideTemperatureC = 20.0
    @State private var lengthM = 1.0
    @State private var editableLayers: [EditableHeatLayer] = []
    @State private var showingAddLayer = false
    @State private var showDetails = false

    struct EditableHeatLayer: Identifiable {
        let id: UUID
        var material: EngineeringMaterial
        var thicknessMM: Double

        init(id: UUID = UUID(), material: EngineeringMaterial, thicknessMM: Double = 10.0) {
            self.id = id
            self.material = material
            self.thicknessMM = thicknessMM
        }
    }

    private var input: PipeHeatTransferInput {
        PipeHeatTransferInput(
            internalDiameterM: max(0, internalDiameterMM) / 1000.0,
            layers: editableLayers.map {
                PipeHeatTransferLayer(
                    id: $0.id,
                    name: $0.material.name,
                    thicknessM: max(0, $0.thicknessMM) / 1000.0,
                    material: $0.material
                )
            },
            insideBoundaryTemperatureC: insideTemperatureC,
            outsideBoundaryTemperatureC: outsideTemperatureC,
            lengthM: max(0, lengthM)
        )
    }

    private var validated: ValidatedPipeHeatTransferResult {
        PipeHeatTransferCalculator.validatedCalculate(input: input)
    }

    private var evaluationTemperatureC: Double {
        PipeHeatTransferCalculator.propertyEvaluationTemperatureC(for: input)
    }

    var body: some View {
        Form {
            Section("Geometry & Boundary Conditions") {
                numericField("Internal diameter (mm)", value: $internalDiameterMM)
                numericField("Inside boundary temperature (°C)", value: $insideTemperatureC)
                numericField("Outside boundary temperature (°C)", value: $outsideTemperatureC)
                numericField("Calculation length (m)", value: $lengthM)
                LabeledContent("Property evaluation temperature") {
                    Text("\(evaluationTemperatureC.formatted(.number.precision(.fractionLength(1)))) °C")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            layersSection
            materialRequirementsSection
            resultsSection
            layerResultsSection

            Section {
                DisclosureGroup("Calculation Details", isExpanded: $showDetails) {
                    if let details = CalculationRegistry.definition(id: "pipeHeatTransfer")?.details {
                        CalculationDetailsView(details: details)
                    } else {
                        Text("Steady-state radial conduction through concentric cylindrical layers. Thermal conductivity is currently evaluated at the arithmetic mean of the specified inside and outside boundary temperatures.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pipe Heat Transfer")
        .sheet(isPresented: $showingAddLayer) {
            NavigationStack {
                AddHeatTransferLayerView { material, thickness in
                    editableLayers.append(EditableHeatLayer(material: material, thicknessMM: thickness))
                }
                .environmentObject(materialStore)
            }
        }
    }

    private var layersSection: some View {
        Section {
            if editableLayers.isEmpty {
                ContentUnavailableView(
                    "No Layers",
                    systemImage: "square.stack.3d.up.slash",
                    description: Text("Add at least one solid layer to calculate radial heat transfer.")
                )
            } else {
                ForEach(editableLayers.map(\.id), id: \.self) { id in
                    if let layer = binding(for: id) {
                        layerRow(layer)
                    }
                }
            }

            Button {
                showingAddLayer = true
            } label: {
                Label("Add Layer", systemImage: "plus.circle")
            }
        } header: {
            Text("Pipe / Insulation Layers")
        } footer: {
            Text("Layers are ordered from the internal bore outwards. Each layer requires thermal conductivity at the calculation property temperature.")
        }
    }

    @ViewBuilder
    private var materialRequirementsSection: some View {
        let validation = validated.validation
        if !validation.canCalculate {
            Section {
                ForEach(validation.layers.filter { !$0.canCalculate }) { layer in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(layer.layerName, systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text("Material: \(layer.materialName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(layer.result.errors) { issue in
                            Text(issue.message)
                                .font(.callout)
                        }
                    }
                    .padding(.vertical, 3)
                }
            } header: {
                Text("Material Requirements")
            } footer: {
                Text("Results are blocked until every layer has usable thermal conductivity data at the required temperature.")
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        Section("Results") {
            if editableLayers.isEmpty {
                Label("Add at least one layer to calculate heat transfer.", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            } else if let result = validated.result {
                resultRow("Final OD", result.finalOuterDiameterM * 1000.0, "mm", digits: 2)
                resultRow("Total conduction resistance", result.totalResistanceKPerW, "K/W", digits: 6)
                resultRow("Heat rate", result.heatRateW, "W", digits: 3)
                resultRow("Heat rate per length", result.heatRatePerLengthWM, "W/m", digits: 3)
                LabeledContent("Heat-flow direction") {
                    Text(result.heatRateW >= 0 ? "Inside → outside" : "Outside → inside")
                        .fontWeight(.semibold)
                }
            } else if validated.validation.canCalculate {
                Label("Check geometry, layer thicknesses and calculation length.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Label("Results blocked until material requirements are satisfied.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var layerResultsSection: some View {
        if let result = validated.result {
            Section("Layer Results") {
                ScrollView(.horizontal) {
                    Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
                        GridRow {
                            Text("Layer").frame(minWidth: 120, alignment: .leading)
                            Text("ID\n(mm)")
                            Text("OD\n(mm)")
                            Text("k\n(W/m·K)")
                            Text("R\n(K/W)")
                            Text("T in\n(°C)")
                            Text("T out\n(°C)")
                        }
                        .font(.caption2.bold())
                        .multilineTextAlignment(.center)

                        Divider().gridCellColumns(7)

                        ForEach(result.layers) { layer in
                            GridRow {
                                Text(layer.name).frame(minWidth: 120, alignment: .leading)
                                number(layer.innerRadiusM * 2000.0, digits: 2)
                                number(layer.outerRadiusM * 2000.0, digits: 2)
                                number(layer.thermalConductivityWMK, digits: 4)
                                number(layer.resistanceKPerW, digits: 6)
                                number(layer.innerBoundaryTemperatureC, digits: 2)
                                number(layer.outerBoundaryTemperatureC, digits: 2)
                            }
                            .font(.caption2)
                        }
                    }
                    .monospacedDigit()
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func layerRow(_ layer: Binding<EditableHeatLayer>) -> some View {
        let id = layer.wrappedValue.id
        let resolution = MaterialPropertyResolver.resolve(
            .thermalConductivity,
            in: layer.wrappedValue.material,
            atTemperatureC: evaluationTemperatureC
        )

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(layer.wrappedValue.material.name)
                        .font(.headline)
                    if let k = resolution.value {
                        Text("k = \(k.formatted(.number.precision(.significantDigits(1...5)))) W/(m·K) at \(evaluationTemperatureC.formatted(.number.precision(.fractionLength(1)))) °C")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label(conductivityStatusText(resolution), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
                Button(role: .destructive) {
                    editableLayers.removeAll { $0.id == id }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            numericField("Thickness (mm)", value: layer.thicknessMM)

            HStack {
                Button { moveLayer(id: id, offset: -1) } label: {
                    Label("Move Up", systemImage: "arrow.up")
                }
                .disabled(editableLayers.first?.id == id)

                Button { moveLayer(id: id, offset: 1) } label: {
                    Label("Move Down", systemImage: "arrow.down")
                }
                .disabled(editableLayers.last?.id == id)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func binding(for id: UUID) -> Binding<EditableHeatLayer>? {
        guard editableLayers.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: {
                editableLayers.first(where: { $0.id == id }) ?? EditableHeatLayer(material: EngineeringMaterial(name: "Unavailable"))
            },
            set: { value in
                if let index = editableLayers.firstIndex(where: { $0.id == id }) {
                    editableLayers[index] = value
                }
            }
        )
    }

    private func moveLayer(id: UUID, offset: Int) {
        guard let index = editableLayers.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard editableLayers.indices.contains(destination) else { return }
        editableLayers.swapAt(index, destination)
    }

    private func conductivityStatusText(_ resolution: MaterialPropertyResolution) -> String {
        switch resolution.status {
        case .missing:
            return "Thermal conductivity missing"
        case .temperatureRequired:
            return "Thermal conductivity requires temperature"
        case .outsideAvailableRange(let minimumC, let maximumC):
            return "k unavailable at this temperature (range \(minimumC.formatted())–\(maximumC.formatted()) °C)"
        case .outsideEquationRange:
            return "k correlation is outside its valid temperature range"
        case .resolved:
            return "Thermal conductivity unavailable"
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

    private func resultRow(_ title: String, _ value: Double, _ unit: String, digits: Int) -> some View {
        LabeledContent(title) {
            Text("\(value.formatted(.number.precision(.fractionLength(0...digits)))) \(unit)")
                .monospacedDigit()
        }
    }

    private func number(_ value: Double, digits: Int) -> Text {
        Text(value.formatted(.number.precision(.fractionLength(0...digits))))
    }
}

private struct AddHeatTransferLayerView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMaterialID: UUID?
    @State private var thicknessMM = 10.0
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
                    LabeledContent("Category", value: material.category)
                    LabeledContent("Thermal conductivity") {
                        if MaterialPropertyResolver.availableProperties(in: material).contains(.thermalConductivity) {
                            Text("Available")
                                .foregroundStyle(.secondary)
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
        .navigationTitle("Add Heat Transfer Layer")
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
                .disabled(selectedMaterial == nil || thicknessMM <= 0)
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
