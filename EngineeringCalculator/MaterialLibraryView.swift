import SwiftUI

private enum MaterialLibraryFilter: String, CaseIterable, Identifiable {
    case all = "All", builtIn = "Built-in", userDefined = "My Materials"
    var id: Self { self }
}

struct MaterialLibraryView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.interfaceDensity) private var density
    @State private var showingNew = false
    @State private var materialPendingDeletion: EngineeringMaterial?
    @State private var libraryFilter: MaterialLibraryFilter = .all
    @State private var selectedMaterialID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Materials", selection: $libraryFilter) { ForEach(MaterialLibraryFilter.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented).labelsHidden().padding(.horizontal).padding(.vertical, 8)
            List(selection: $selectedMaterialID) {
                ForEach(visibleCategories, id: \.self) { category in
                    Section {
                        ForEach(materials(in: category)) { material in
                            HStack(spacing: 8) {
                                Button { selectedMaterialID = nil; DispatchQueue.main.async { selectedMaterialID = material.id } } label: { row(material) }
                                    .buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
                                if !material.isBuiltIn { Button(role: .destructive) { materialPendingDeletion = material } label: { Image(systemName: "trash").frame(width: 24, height: 24) }.buttonStyle(.borderless).help("Delete \(material.name)") }
                            }
#if os(macOS)
                            .draggable(material.id.uuidString)
#endif
                        }
#if os(macOS)
                        dropTarget(category).dropDestination(for: String.self) { items, _ in handleDroppedMaterials(items, to: category) }
#endif
                    } header: { categoryHeader(category) }
                }
            }
        }
        .navigationTitle("Material Library")
        .navigationDestination(isPresented: Binding(get: { selectedMaterialID != nil }, set: { if !$0 { selectedMaterialID = nil } })) {
            if let id = selectedMaterialID { MaterialDetailView(materialID: id).onDisappear { selectedMaterialID = nil } }
        }
        .toolbar { Button { showingNew = true } label: { Label("New Material", systemImage: "plus") } }
        .sheet(isPresented: $showingNew) { NavigationStack { MaterialEditorView() } }
        .confirmationDialog("Delete Material?", isPresented: Binding(get: { materialPendingDeletion != nil }, set: { if !$0 { materialPendingDeletion = nil } }), titleVisibility: .visible) {
            if let material = materialPendingDeletion { Button("Delete \(material.name)", role: .destructive) { store.delete(id: material.id); materialPendingDeletion = nil } }
            Button("Cancel", role: .cancel) { materialPendingDeletion = nil }
        } message: { Text("This removes the material from My Materials. Built-in materials cannot be deleted.") }
        .alert("Material Library", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) { Button("OK") { store.lastError = nil } } message: { Text(store.lastError ?? "") }
    }

    private var filteredMaterials: [EngineeringMaterial] { switch libraryFilter { case .all: store.allMaterials; case .builtIn: store.builtInMaterials; case .userDefined: store.userMaterials } }
    private var visibleCategories: [String] { store.categories.filter { category in filteredMaterials.contains { $0.category.caseInsensitiveCompare(category) == .orderedSame } } }
    private func materials(in category: String) -> [EngineeringMaterial] { filteredMaterials.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
    private func categoryHeader(_ category: String) -> some View { HStack { Text(category); Spacer(); Text("\(materials(in: category).count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) } }
#if os(macOS)
    private func dropTarget(_ category: String) -> some View { HStack(spacing: 12) { Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 25, weight: .semibold)); VStack(alignment: .leading, spacing: 2) { Text("Drop material into \(category)").font(.system(size: 13, weight: .medium)); Text("Drag normally to move a user material; hold Option while dragging to copy. Built-in materials are always copied.").font(.caption2).foregroundStyle(.tertiary) }; Spacer() }.foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 8)).overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5,4])) } }
    private func handleDroppedMaterials(_ items: [String], to category: String) -> Bool { let copy = NSApp.currentEvent?.modifierFlags.contains(.option) == true; var handled = false; for item in items { guard let id = UUID(uuidString: item), let material = store.allMaterials.first(where: { $0.id == id }) else { continue }; if material.isBuiltIn || copy { store.duplicate(material, to: category) } else { store.move(material, to: category) }; handled = true }; return handled }
#endif
    private func row(_ material: EngineeringMaterial) -> some View { VStack(alignment: .leading, spacing: density.rowPadding) { HStack { Text(material.name).font(.system(size: density.bodySize, weight: .semibold)); Spacer(); Text(material.isBuiltIn ? "Built-in" : "My Material").font(.caption2).foregroundStyle(.secondary) }; if let grade = material.grade, !grade.isEmpty { Text(grade).font(.system(size: density.smallSize)).foregroundStyle(.secondary) } }.padding(.vertical, density.rowPadding) }
}

private struct MaterialDetailView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    let materialID: UUID
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var showAdvanced = false
    private var material: EngineeringMaterial? { store.allMaterials.first { $0.id == materialID } }

    var body: some View {
        Group { if let material { ScrollView { VStack(alignment: .leading, spacing: 20) {
            section("Identity") { stringRow("Category", material.category); stringRow("Library", material.isBuiltIn ? "Built-in" : "My Materials"); if let grade = material.grade, !grade.isEmpty { stringRow("Grade / specification", grade) } }
            section("Core Properties") { seriesRow("Thermal conductivity", material.thermalConductivityWMK, "W/(m·K)", material.thermalConductivitySeries); seriesRow("Specific heat capacity", material.specificHeatCapacityJkgK, "J/(kg·K)", material.specificHeatCapacitySeries); valueRow("Density", material.densityKgM3, "kg/m³") }
            DisclosureGroup("Advanced Properties", isExpanded: $showAdvanced) { VStack(alignment: .leading, spacing: 16) {
                section("Mechanical") { seriesRow("Young's modulus", material.youngsModulusGPa, "GPa", material.youngsModulusSeries); seriesRow("Poisson's ratio", material.poissonsRatio, "", material.poissonsRatioSeries); seriesRow("Yield strength", material.yieldStrengthMPa, "MPa", material.yieldStrengthSeries); seriesRow("Ultimate tensile strength", material.ultimateTensileStrengthMPa, "MPa", material.ultimateTensileStrengthSeries); seriesRow("Shear modulus", material.shearModulusGPa, "GPa", material.shearModulusSeries); valueRow("Compressive strength", material.compressiveStrengthMPa, "MPa") }
                section("Thermal") { seriesRow("Thermal expansion", material.thermalExpansionMicrostrainPerK, "µm/(m·K)", material.thermalExpansionSeries); valueRow("Minimum service temperature", material.minimumServiceTemperatureC, "°C"); valueRow("Maximum service temperature", material.maximumServiceTemperatureC, "°C") }
                section("Electrical") { seriesRow("Electrical resistivity", material.electricalResistivityOhmM, "Ω·m", material.electricalResistivitySeries) }
            }.padding(.top, 10) }.font(.headline)
            if let source = material.source, !source.isEmpty { section("Traceability") { stringRow("Source / Basis", source) } }
            if let notes = material.notes, !notes.isEmpty { section("Notes") { stringRow("Notes", notes) } }
            HStack { Button(material.isBuiltIn ? "Duplicate to My Materials" : "Duplicate") { store.duplicate(material) }; if !material.isBuiltIn { Button("Edit") { editing = true }; Button("Delete Material", role: .destructive) { confirmingDelete = true } }; Spacer() }
        }.padding(24).frame(maxWidth: 720, alignment: .leading) }.navigationTitle(material.name)
            .sheet(isPresented: $editing) { NavigationStack { MaterialEditorView(existing: material) } }
            .confirmationDialog("Delete Material?", isPresented: $confirmingDelete) { Button("Delete \(material.name)", role: .destructive) { store.delete(id: material.id); dismiss() }; Button("Cancel", role: .cancel) {} }
        } else { ContentUnavailableView("Material Not Found", systemImage: "questionmark.folder") } }
    }

    @ViewBuilder private func seriesRow(_ key: String, _ fallback: Double?, _ unit: String, _ series: MaterialPropertySeries?) -> some View {
        if let series, !series.temperatureTable.isEmpty || series.equation != nil { NavigationLink { MaterialPropertySeriesView(propertyName: key, unit: unit, series: series) } label: { HStack { Text(key).frame(width: 190, alignment: .leading); VStack(alignment: .leading) { Text(format(series.referenceValue ?? fallback, unit)); Text(series.equation != nil ? "Equation" : "\(series.temperatureTable.count) temperature points").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right") }.padding(12) }.buttonStyle(.plain) } else { valueRow(key, fallback, unit) }
    }
    @ViewBuilder private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); VStack(spacing: 0) { content() }.background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 10)) } }
    private func format(_ value: Double?, _ unit: String) -> String { guard let value else { return "Not specified" }; return unit.isEmpty ? EngineeringNumberFormatter.string(value) : "\(EngineeringNumberFormatter.string(value)) \(unit)" }
    private func stringRow(_ key: String, _ value: String) -> some View { HStack(alignment: .top) { Text(key).foregroundStyle(.secondary).frame(width: 190, alignment: .leading); Text(value).frame(maxWidth: .infinity, alignment: .leading) }.padding(12).overlay(alignment: .bottom) { Divider() } }
    private func valueRow(_ key: String, _ value: Double?, _ unit: String) -> some View { stringRow(key, format(value, unit)) }
}

private struct MaterialPropertySeriesView: View {
    let propertyName: String; let unit: String; let series: MaterialPropertySeries
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) {
        if let equation = series.equation { Text("Equation").font(.headline); Text("y(T) = \(equation.a) + \(equation.b)T + \(equation.c)T² + \(equation.d)T³").monospaced() }
        if !series.temperatureTable.isEmpty { Text("Temperature Data").font(.headline); ForEach(series.temperatureTable.sorted { $0.temperatureC < $1.temperatureC }) { point in HStack { Text("\(point.temperatureC.formatted()) °C"); Spacer(); Text(unit.isEmpty ? EngineeringNumberFormatter.string(point.value) : "\(EngineeringNumberFormatter.string(point.value)) \(unit)") }.padding(.vertical, 4) } }
        if let basis = series.basis, !basis.isEmpty { Text("Basis").font(.headline); Text(basis) }; if let source = series.source, !source.isEmpty { Text("Source").font(.headline); Text(source) }
    }.padding(24).frame(maxWidth: 720, alignment: .leading) }.navigationTitle(propertyName) }
}

struct MaterialEditorView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    let existing: EngineeringMaterial?
    @State private var advanced = false
    @State private var name: String; @State private var category: String; @State private var grade: String
    @State private var density: String; @State private var minimumServiceTemperature: String; @State private var maximumServiceTemperature: String; @State private var compressiveStrength: String
    @State private var source: String; @State private var notes: String
    @State private var conductivity: MaterialPropertyDraft; @State private var heatCapacity: MaterialPropertyDraft; @State private var thermalExpansion: MaterialPropertyDraft
    @State private var youngsModulus: MaterialPropertyDraft; @State private var poissonsRatio: MaterialPropertyDraft; @State private var yieldStrength: MaterialPropertyDraft
    @State private var ultimateTensileStrength: MaterialPropertyDraft; @State private var shearModulus: MaterialPropertyDraft; @State private var electricalResistivity: MaterialPropertyDraft

    init(existing: EngineeringMaterial? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? ""); _category = State(initialValue: existing?.category ?? "Other"); _grade = State(initialValue: existing?.grade ?? "")
        _density = State(initialValue: Self.text(existing?.densityKgM3)); _minimumServiceTemperature = State(initialValue: Self.text(existing?.minimumServiceTemperatureC)); _maximumServiceTemperature = State(initialValue: Self.text(existing?.maximumServiceTemperatureC)); _compressiveStrength = State(initialValue: Self.text(existing?.compressiveStrengthMPa)); _source = State(initialValue: existing?.source ?? ""); _notes = State(initialValue: existing?.notes ?? "")
        _conductivity = State(initialValue: MaterialPropertyDraft(fallback: existing?.thermalConductivityWMK, series: existing?.thermalConductivitySeries)); _heatCapacity = State(initialValue: MaterialPropertyDraft(fallback: existing?.specificHeatCapacityJkgK, series: existing?.specificHeatCapacitySeries)); _thermalExpansion = State(initialValue: MaterialPropertyDraft(fallback: existing?.thermalExpansionMicrostrainPerK, series: existing?.thermalExpansionSeries)); _youngsModulus = State(initialValue: MaterialPropertyDraft(fallback: existing?.youngsModulusGPa, series: existing?.youngsModulusSeries)); _poissonsRatio = State(initialValue: MaterialPropertyDraft(fallback: existing?.poissonsRatio, series: existing?.poissonsRatioSeries)); _yieldStrength = State(initialValue: MaterialPropertyDraft(fallback: existing?.yieldStrengthMPa, series: existing?.yieldStrengthSeries)); _ultimateTensileStrength = State(initialValue: MaterialPropertyDraft(fallback: existing?.ultimateTensileStrengthMPa, series: existing?.ultimateTensileStrengthSeries)); _shearModulus = State(initialValue: MaterialPropertyDraft(fallback: existing?.shearModulusGPa, series: existing?.shearModulusSeries)); _electricalResistivity = State(initialValue: MaterialPropertyDraft(fallback: existing?.electricalResistivityOhmM, series: existing?.electricalResistivitySeries))
        _advanced = State(initialValue: existing != nil)
    }

    var body: some View { Form {
        Section("Identity") { LabeledContent("Name") { TextField("Name", text: $name) }; LabeledContent("Existing category") { Picker("Existing category", selection: $category) { ForEach(store.categories, id: \.self) { Text($0).tag($0) } }.labelsHidden() }; LabeledContent("Category") { TextField("Category", text: $category) }; LabeledContent("Grade / specification") { TextField("Grade", text: $grade) } }
        Section("Core Properties") { scalarField("Density", "kg/m³", $density); MaterialTemperaturePropertyEditor(title: "Thermal conductivity", unit: "W/(m·K)", draft: $conductivity); MaterialTemperaturePropertyEditor(title: "Specific heat capacity", unit: "J/(kg·K)", draft: $heatCapacity) }
        Section { Toggle("Advanced properties", isOn: $advanced) }
        if advanced {
            Section("Mechanical") { MaterialTemperaturePropertyEditor(title: "Young's modulus", unit: "GPa", draft: $youngsModulus); MaterialTemperaturePropertyEditor(title: "Poisson's ratio", unit: "", draft: $poissonsRatio); MaterialTemperaturePropertyEditor(title: "Yield strength", unit: "MPa", draft: $yieldStrength); MaterialTemperaturePropertyEditor(title: "Ultimate tensile strength", unit: "MPa", draft: $ultimateTensileStrength); MaterialTemperaturePropertyEditor(title: "Shear modulus", unit: "GPa", draft: $shearModulus); scalarField("Compressive strength", "MPa", $compressiveStrength) }
            Section("Extended Thermal") { MaterialTemperaturePropertyEditor(title: "Thermal expansion", unit: "µm/(m·K)", draft: $thermalExpansion); scalarField("Minimum service temperature", "°C", $minimumServiceTemperature); scalarField("Maximum service temperature", "°C", $maximumServiceTemperature) }
            Section("Electrical") { MaterialTemperaturePropertyEditor(title: "Electrical resistivity", unit: "Ω·m", draft: $electricalResistivity) }
        }
        Section("Traceability") { TextField("Source / basis", text: $source, axis: .vertical).lineLimit(2...6); TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...8) }
    }.formStyle(.grouped).padding(.horizontal, 12).navigationTitle(existing == nil ? "New Material" : "Edit Material")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }.materialEditorSizing()
#if os(macOS)
        .background(MaterialEditorWindowConfigurator())
#endif
    }

    private func scalarField(_ label: String, _ unit: String, _ text: Binding<String>) -> some View { LabeledContent(label) { HStack { TextField("Value", text: text).multilineTextAlignment(.trailing); Text(unit).foregroundStyle(.secondary) } } }
    private static func text(_ value: Double?) -> String { EngineeringNumberFormatter.editableString(value) }
    private func number(_ text: String) -> Double? { EngineeringNumberFormatter.parse(text) }
    private func save() {
        let material = EngineeringMaterial(id: existing?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), category: store.canonicalCategory(category), densityKgM3: number(density), grade: grade.isEmpty ? nil : grade,
            thermalConductivityWMK: conductivity.scalarValue, specificHeatCapacityJkgK: heatCapacity.scalarValue, thermalExpansionMicrostrainPerK: thermalExpansion.scalarValue, minimumServiceTemperatureC: number(minimumServiceTemperature), maximumServiceTemperatureC: number(maximumServiceTemperature), youngsModulusGPa: youngsModulus.scalarValue, poissonsRatio: poissonsRatio.scalarValue, yieldStrengthMPa: yieldStrength.scalarValue, ultimateTensileStrengthMPa: ultimateTensileStrength.scalarValue, shearModulusGPa: shearModulus.scalarValue, compressiveStrengthMPa: number(compressiveStrength), electricalResistivityOhmM: electricalResistivity.scalarValue, source: source.isEmpty ? nil : source, notes: notes.isEmpty ? nil : notes, unsDesignation: existing?.unsDesignation, standardDesignation: existing?.standardDesignation, productForm: existing?.productForm, materialCondition: existing?.materialCondition, smysMPa: existing?.smysMPa, smtsMPa: existing?.smtsMPa,
            thermalConductivitySeries: conductivity.makeSeries(), specificHeatCapacitySeries: heatCapacity.makeSeries(), thermalExpansionSeries: thermalExpansion.makeSeries(), youngsModulusSeries: youngsModulus.makeSeries(), poissonsRatioSeries: poissonsRatio.makeSeries(), yieldStrengthSeries: yieldStrength.makeSeries(), ultimateTensileStrengthSeries: ultimateTensileStrength.makeSeries(), shearModulusSeries: shearModulus.makeSeries(), electricalResistivitySeries: electricalResistivity.makeSeries())
        if existing == nil { store.add(material) } else { store.update(material) }
    }
}

private extension View { @ViewBuilder func materialEditorSizing() -> some View {
#if os(macOS)
    self.frame(minWidth: 640, idealWidth: 760, maxWidth: .infinity, minHeight: 480, idealHeight: 760, maxHeight: .infinity)
#else
    self
#endif
} }

#if os(macOS)
private struct MaterialEditorWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { let view = NSView(); DispatchQueue.main.async { configure(view.window) }; return view }
    func updateNSView(_ nsView: NSView, context: Context) { DispatchQueue.main.async { configure(nsView.window) } }
    private func configure(_ window: NSWindow?) { guard let window else { return }; window.styleMask.insert(.resizable); window.minSize = NSSize(width: 640, height: 480); window.contentMinSize = NSSize(width: 640, height: 480) }
}
#endif
