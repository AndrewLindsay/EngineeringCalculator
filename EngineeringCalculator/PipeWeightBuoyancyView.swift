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

    enum DiameterMode: String, CaseIterable, Identifiable { case diameter = "Internal Diameter", radius = "Internal Radius"; var id: String { rawValue } }
    struct EditableLayer: Identifiable {
        let id: UUID; var material: EngineeringMaterial; var thicknessMM: Double
        init(id: UUID = UUID(), material: EngineeringMaterial, thicknessMM: Double = 3.0) { self.id = id; self.material = material; self.thicknessMM = thicknessMM }
    }

    private var pipeMaterial: EngineeringMaterial? {
        if let id = selectedPipeMaterialID, let found = materialStore.steelMaterials.first(where: { $0.id == id }) { return found }
        return materialStore.steelMaterials.first
    }
    private var internalDiameterM: Double { let m = max(0, insideValueMM) / 1000; return diameterMode == .diameter ? m : 2 * m }
    private var layers: [PipeLayer] {
        let steel = pipeMaterial ?? EngineeringMaterial(name: "Carbon Steel", category: "Steel", densityKgM3: 7850)
        var output = [PipeLayer(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: steel.name,
                                thicknessM: max(0, wallThicknessMM) / 1000, material: steel)]
        output += extraLayers.map { PipeLayer(id: $0.id, name: $0.material.name, thicknessM: max(0, $0.thicknessMM) / 1000, material: $0.material) }
        return output
    }
    private var pipeConstruction: PipeConstruction {
        PipeConstruction(name: "Current Pipe", internalDiameterM: internalDiameterM, layers: layers,
            internalFluid: FluidDefinition(name: "Internal Fluid", densityKgM3: max(0, internalDensity)),
            externalFluid: FluidDefinition(name: "External Fluid", densityKgM3: max(0, externalDensity)))
    }
    private var result: PipeWeightBuoyancyResult { PipeWeightBuoyancyCalculator.calculate(construction: pipeConstruction) }

    var body: some View {
        Form {
            Section("Pipe Geometry") {
                Picker("Inside dimension", selection: $diameterMode) { ForEach(DiameterMode.allCases) { Text($0.rawValue).tag($0) } }
                numericField(diameterMode.rawValue + " (mm)", value: $insideValueMM)
                Picker("Pipe material", selection: $selectedPipeMaterialID) {
                    ForEach(materialStore.steelMaterials) { Text($0.name).tag(Optional($0.id)) }
                }
                if let pipeMaterial, let density = pipeMaterial.densityKgM3 {
                    LabeledContent("Pipe density") { Text("\(density.formatted()) kg/m³").foregroundStyle(.secondary) }
                }
                numericField("Pipe wall thickness (mm)", value: $wallThicknessMM)
            }

            Section {
                ForEach(extraLayers.map(\.id), id: \.self) { id in if let b = binding(for: id) { layerRow(b) } }
                Button { showingAddLayer = true } label: { Label("Add Layer", systemImage: "plus.circle") }
            } header: { Text("Additional Layers") }
            footer: { Text("Choose layer materials from the Material Library. Layers are calculated from inside to outside; use Move Up/Down to change their physical order.") }

            Section("Layer Stack Used in Calculation") { layerTable }
            Section("Fluids") { numericField("Internal fluid density (kg/m³)", value: $internalDensity); numericField("External fluid density (kg/m³)", value: $externalDensity) }
            Section("Results") {
                resultRow("Final OD", result.finalOuterDiameterM * 1000, "mm"); resultRow("Dry pipe mass", result.pipeMassKgPerM, "kg/m")
                resultRow("Dry pipe weight", result.pipeWeightKNPerM, "kN/m"); resultRow("Internal contents", result.contentsMassKgPerM, "kg/m")
                resultRow("Displaced external fluid", result.displacedMassKgPerM, "kg/m"); resultRow("Submerged equivalent mass", result.submergedEquivalentMassKgPerM, "kg/m")
                resultRow("Submerged weight", result.submergedWeightKNPerM, "kN/m")
                LabeledContent("Condition") { Text(result.submergedWeightKNPerM < 0 ? "Buoyant" : "Sinks").fontWeight(.semibold) }
            }
            Section { DisclosureGroup("Calculation Details", isExpanded: $showDetails) { if let d = CalculationRegistry.definition(id: "pipeWeightBuoyancy")?.details { CalculationDetailsView(details: d) } } }
        }
        .formStyle(.grouped).navigationTitle("Pipe Weight & Buoyancy")
        .onAppear { initialisePipeMaterialSelection() }
        .onChange(of: materialStore.steelMaterials.map(\.id)) { _, _ in initialisePipeMaterialSelection() }
        .sheet(isPresented: $showingAddLayer) { NavigationStack { AddPipeLayerView { m, t in extraLayers.append(EditableLayer(material: m, thicknessMM: t)) }.environmentObject(materialStore) } }
    }

    private func initialisePipeMaterialSelection() {
        let steels = materialStore.steelMaterials
        guard !steels.isEmpty else { selectedPipeMaterialID = nil; return }
        if let selectedPipeMaterialID, steels.contains(where: { $0.id == selectedPipeMaterialID }) { return }
        selectedPipeMaterialID = steels.first?.id
    }

    @ViewBuilder private func layerRow(_ layer: Binding<EditableLayer>) -> some View {
        let id = layer.wrappedValue.id
        VStack(alignment: .leading, spacing: 8) {
            HStack { VStack(alignment: .leading) { Text(layer.wrappedValue.material.name).font(.headline); Text("\(layer.wrappedValue.material.densityKgM3 ?? 0, format: .number.precision(.fractionLength(0))) kg/m³").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button(role: .destructive) { deleteLayer(id: id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless) }
            numericField("Thickness (mm)", value: layer.thicknessMM)
            HStack { Button { moveLayer(id: id, offset: -1) } label: { Label("Move Up", systemImage: "arrow.up") }.disabled(isFirst(id)); Button { moveLayer(id: id, offset: 1) } label: { Label("Move Down", systemImage: "arrow.down") }.disabled(isLast(id)) }.buttonStyle(.borderless)
        }.padding(.vertical, 5)
    }
    private func binding(for id: UUID) -> Binding<EditableLayer>? {
        guard extraLayers.contains(where: { $0.id == id }) else { return nil }
        return Binding(get: { extraLayers.first(where: { $0.id == id }) ?? EditableLayer(id: id, material: EngineeringMaterial(name: "Unavailable"), thicknessMM: 0) },
                       set: { value in if let i = extraLayers.firstIndex(where: { $0.id == id }) { extraLayers[i] = value } })
    }
    private var layerTable: some View {
        ScrollView(.horizontal) { Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 5) {
            GridRow { Text("#"); Text("Layer").frame(minWidth: 90, alignment: .leading); Text("ID\n(mm)"); Text("t\n(mm)"); Text("OD\n(mm)"); Text("Density\n(kg/m³)"); Text("Area\n(m²)"); Text("Mass\n(kg/m)") }.font(.caption2.bold()).multilineTextAlignment(.center)
            Divider().gridCellColumns(8)
            ForEach(Array(result.layers.enumerated()), id: \.element.id) { i, l in GridRow { Text("\(i+1)"); Text(l.name).frame(minWidth: 90, alignment: .leading); tableNumber(l.innerDiameterM*1000,digits:2); tableNumber(l.thicknessM*1000,digits:2); tableNumber(l.outerDiameterM*1000,digits:2); tableNumber(l.densityKgM3,digits:0); tableNumber(l.areaM2,digits:5); tableNumber(l.massKgPerM,digits:2) }.font(.caption2) }
            Divider().gridCellColumns(8)
            GridRow { Text(""); Text("TOTAL").fontWeight(.semibold).frame(minWidth:90,alignment:.leading); Text(""); Text(""); tableNumber(result.finalOuterDiameterM*1000,digits:2); Text(""); Text(""); tableNumber(result.pipeMassKgPerM,digits:2).fontWeight(.semibold) }.font(.caption2)
        }.monospacedDigit().padding(.vertical,4) }
    }
    @ViewBuilder private func numericField(_ title:String,value:Binding<Double>)->some View { LabeledContent(title){ TextField(title,value:value,format:.number.precision(.fractionLength(0...4))).multilineTextAlignment(.trailing)
#if os(iOS)
.keyboardType(.decimalPad)
#endif
.frame(minWidth:90) } }
    private func resultRow(_ title:String,_ value:Double,_ unit:String)->some View { LabeledContent(title){Text("\(value, format:.number.precision(.fractionLength(3))) \(unit)").monospacedDigit()} }
    private func tableNumber(_ value:Double,digits:Int)->Text { Text(value.formatted(.number.precision(.fractionLength(digits)))) }
    private func deleteLayer(id:UUID){extraLayers.removeAll{$0.id==id}}; private func isFirst(_ id:UUID)->Bool{extraLayers.first?.id==id}; private func isLast(_ id:UUID)->Bool{extraLayers.last?.id==id}
    private func moveLayer(id:UUID,offset:Int){guard let i=extraLayers.firstIndex(where:{$0.id==id}) else{return};let d=i+offset;guard extraLayers.indices.contains(d) else{return};extraLayers.swapAt(i,d)}
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
                    LabeledContent("Category", value: material.category)
                    LabeledContent("Density") {
                        if let density = material.densityKgM3 {
                            Text("\(density.formatted()) kg/m³")
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
                }
            }
        }
        .navigationTitle("Add Layer")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    guard let material = selectedMaterial else { return }
                    onAdd(material, max(0, thicknessMM))
                    dismiss()
                }
                .disabled(selectedMaterial?.densityKgM3 == nil || thicknessMM <= 0)
            }
        }
        .sheet(isPresented: $showingNewMaterial) {
            NavigationStack { MaterialEditorView().environmentObject(store) }
        }
    }

    private func materials(in category: String) -> [EngineeringMaterial] {
        store.allMaterials.filter { material in
            material.category.caseInsensitiveCompare(category) == .orderedSame
        }
    }
}
