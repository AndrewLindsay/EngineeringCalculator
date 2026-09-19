import SwiftUI

private enum MaterialLibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case builtIn = "Built-in"
    case userDefined = "My Materials"
    var id: Self { self }
}

struct MaterialLibraryView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.interfaceDensity) private var density
    @State private var showingNew = false
    @State private var materialPendingDeletion: EngineeringMaterial?
    @State private var libraryFilter: MaterialLibraryFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            Picker("Materials", selection: $libraryFilter) { ForEach(MaterialLibraryFilter.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented).labelsHidden().padding(.horizontal).padding(.vertical, 8)
            List {
                ForEach(visibleCategories, id: \.self) { category in
                    Section {
                        let categoryMaterials = materials(in: category)
                        ForEach(categoryMaterials) { material in
                            HStack(spacing: 8) {
                                NavigationLink { MaterialDetailView(materialID: material.id) } label: { row(material) }
                                if !material.isBuiltIn { Button(role: .destructive) { materialPendingDeletion = material } label: { Image(systemName: "trash").frame(width: 24, height: 24) }.buttonStyle(.borderless).help("Delete \(material.name)") }
                            }.contextMenu { materialMenu(material, currentCategory: category) }
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
        }.navigationTitle("Material Library")
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
    private func categoryHeader(_ category: String) -> some View { HStack { Text(category); Spacer(); Text("\(materials(in: category).count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }.contentShape(Rectangle()) }
#if os(macOS)
    private func dropTarget(_ category: String) -> some View {
        HStack(spacing: 12) { Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 25, weight: .semibold)); VStack(alignment: .leading, spacing: 2) { Text("Drop material into \(category)").font(.system(size: 13, weight: .medium)); Text("Drag normally to move a user material; hold Option while dragging to copy. Built-in materials are always copied.").font(.caption2).foregroundStyle(.tertiary) }; Spacer() }
            .foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 8)).overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }.contentShape(Rectangle())
    }
#endif
    @ViewBuilder private func materialMenu(_ material: EngineeringMaterial, currentCategory: String) -> some View {
        Button("Duplicate") { store.duplicate(material) }; Menu("Copy to Category") { ForEach(store.categories, id: \.self) { target in Button(target) { store.duplicate(material, to: target) } } }
        if !material.isBuiltIn { Menu("Move to Category") { ForEach(store.categories.filter { $0.caseInsensitiveCompare(currentCategory) != .orderedSame }, id: \.self) { target in Button(target) { store.move(material, to: target) } } }; Divider(); Button("Delete", role: .destructive) { materialPendingDeletion = material } }
    }
#if os(macOS)
    private func handleDroppedMaterials(_ items: [String], to category: String) -> Bool { let optionHeld = NSApp.currentEvent?.modifierFlags.contains(.option) == true; var handled = false; for item in items { guard let id = UUID(uuidString: item), let material = store.allMaterials.first(where: { $0.id == id }) else { continue }; if material.isBuiltIn || optionHeld { store.duplicate(material, to: category) } else { store.move(material, to: category) }; handled = true }; return handled }
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
        Group {
            if let material {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        propertySection("Identity") {
                            propertyRow("Category", material.category); propertyRow("Library", material.isBuiltIn ? "Built-in" : "My Materials")
                            if let grade = material.grade, !grade.isEmpty { propertyRow("Grade / specification", grade) }
                            if let uns = material.unsDesignation, !uns.isEmpty { propertyRow("UNS designation", uns) }
                            if let standard = material.standardDesignation, !standard.isEmpty { propertyRow("Standard", standard) }
                            if let form = material.productForm, !form.isEmpty { propertyRow("Product form", form) }
                            if let condition = material.materialCondition, !condition.isEmpty { propertyRow("Condition", condition) }
                        }
                        propertySection("Core Properties") {
                            propertySeriesRow("Thermal conductivity", fallback: material.thermalConductivityWMK, unit: "W/(m·K)", series: material.thermalConductivitySeries)
                            propertySeriesRow("Specific heat capacity", fallback: material.specificHeatCapacityJkgK, unit: "J/(kg·K)", series: material.specificHeatCapacitySeries)
                            propertyRow("Density", material.densityKgM3, unit: "kg/m³")
                        }
                        DisclosureGroup("Advanced Properties", isExpanded: $showAdvanced) {
                            VStack(alignment: .leading, spacing: 16) {
                                propertySection("Mechanical") {
                                    propertySeriesRow("Young's modulus", fallback: material.youngsModulusGPa, unit: "GPa", series: material.youngsModulusSeries)
                                    propertySeriesRow("Poisson's ratio", fallback: material.poissonsRatio, unit: "", series: material.poissonsRatioSeries)
                                    propertySeriesRow("Yield strength", fallback: material.yieldStrengthMPa, unit: "MPa", series: material.yieldStrengthSeries)
                                    propertySeriesRow("Ultimate tensile strength", fallback: material.ultimateTensileStrengthMPa, unit: "MPa", series: material.ultimateTensileStrengthSeries)
                                    propertySeriesRow("Shear modulus", fallback: material.shearModulusGPa, unit: "GPa", series: material.shearModulusSeries)
                                    propertyRow("Compressive strength", material.compressiveStrengthMPa, unit: "MPa")
                                }
                                propertySection("Thermal") {
                                    propertySeriesRow("Thermal expansion", fallback: material.thermalExpansionMicrostrainPerK, unit: "µm/(m·K)", series: material.thermalExpansionSeries)
                                    propertyRow("Minimum service temperature", material.minimumServiceTemperatureC, unit: "°C"); propertyRow("Maximum service temperature", material.maximumServiceTemperatureC, unit: "°C")
                                }
                                propertySection("Electrical") { propertySeriesRow("Electrical resistivity", fallback: material.electricalResistivityOhmM, unit: "Ω·m", series: material.electricalResistivitySeries) }
                            }.padding(.top, 10)
                        }.font(.headline)
                        if let source = material.source, !source.isEmpty { propertySection("Traceability") { propertyRow("Source / Basis", source) } }
                        if let notes = material.notes, !notes.isEmpty { propertySection("Notes") { propertyRow("Notes", notes) } }
                        HStack { Button(material.isBuiltIn ? "Duplicate to My Materials" : "Duplicate") { store.duplicate(material) }; if !material.isBuiltIn { Button("Edit") { editing = true }; Button("Delete Material", role: .destructive) { confirmingDelete = true } }; Spacer() }
                    }.padding(24).frame(maxWidth: 720, alignment: .leading)
                }.navigationTitle(material.name).sheet(isPresented: $editing) { NavigationStack { MaterialEditorView(existing: material) } }.confirmationDialog("Delete Material?", isPresented: $confirmingDelete, titleVisibility: .visible) { Button("Delete \(material.name)", role: .destructive) { store.delete(id: material.id); dismiss() }; Button("Cancel", role: .cancel) { } } message: { Text("This removes the material from My Materials.") }
            } else { ContentUnavailableView("Material Not Found", systemImage: "questionmark.folder") }
        }
    }

    @ViewBuilder private func propertySeriesRow(_ key: String, fallback: Double?, unit: String, series: MaterialPropertySeries?) -> some View {
        if let series, !series.temperatureTable.isEmpty {
            NavigationLink { MaterialPropertySeriesView(propertyName: key, unit: unit, series: series) } label: {
                HStack(alignment: .top, spacing: 0) {
                    Text(key).fontWeight(.semibold).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).frame(width: propertyLabelWidth, alignment: .leading)
                    Divider().padding(.horizontal, 12)
                    VStack(alignment: .leading, spacing: 3) {
                        if let value = series.referenceValue ?? fallback { Text(valueText(value, unit: unit)).monospacedDigit().foregroundStyle(.primary) } else { Text("Temperature table").foregroundStyle(.primary) }
                        Text("\(series.temperatureTable.count) temperature points").font(.caption).foregroundStyle(.secondary)
                    }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary).padding(.leading, 8)
                }.fixedSize(horizontal: false, vertical: true).padding(.horizontal, 14).padding(.vertical, 10).contentShape(Rectangle()).overlay(alignment: .bottom) { Divider() }
            }.buttonStyle(.plain)
        } else { propertyRow(key, fallback, unit: unit) }
    }

    @ViewBuilder private func propertySection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); VStack(spacing: 0) { content() }.background(.quaternary.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay { RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1) } } }
    private var propertyLabelWidth: CGFloat {
#if os(iOS)
        150
#else
        190
#endif
    }
    private func valueText(_ value: Double, unit: String) -> String { let formatted = EngineeringNumberFormatter.string(value); return unit.isEmpty ? formatted : "\(formatted) \(unit)" }
    private func propertyRow(_ key: String, _ value: String) -> some View { HStack(alignment: .top, spacing: 0) { Text(key).fontWeight(.semibold).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).frame(width: propertyLabelWidth, alignment: .leading); Divider().padding(.horizontal, 12); Text(value).fontWeight(.medium).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }.fixedSize(horizontal: false, vertical: true).padding(.horizontal, 14).padding(.vertical, 10).overlay(alignment: .bottom) { Divider() } }
    private func propertyRow(_ key: String, _ value: Double?, unit: String) -> some View { HStack(alignment: .top, spacing: 0) { Text(key).fontWeight(.semibold).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).frame(width: propertyLabelWidth, alignment: .leading); Divider().padding(.horizontal, 12); Group { if let value { Text(valueText(value, unit: unit)).monospacedDigit() } else { Text("Not specified").foregroundStyle(.secondary) } }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading) }.fixedSize(horizontal: false, vertical: true).padding(.horizontal, 14).padding(.vertical, 10).overlay(alignment: .bottom) { Divider() } }
}

private struct MaterialPropertySeriesView: View {
    let propertyName: String
    let unit: String
    let series: MaterialPropertySeries
    private var sortedPoints: [MaterialPropertyPoint] { series.temperatureTable.sorted { $0.temperatureC < $1.temperatureC } }
    private func valueText(_ value: Double) -> String { let formatted = EngineeringNumberFormatter.string(value); return unit.isEmpty ? formatted : "\(formatted) \(unit)" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if series.referenceValue != nil || series.referenceTemperatureC != nil { VStack(alignment: .leading, spacing: 8) { Text("Reference Value").font(.headline); HStack { if let value = series.referenceValue { Text(valueText(value)).font(.title3.bold()).monospacedDigit() }; if let temperature = series.referenceTemperatureC { Text("@ \(temperature.formatted()) °C").foregroundStyle(.secondary) } } } }
                VStack(alignment: .leading, spacing: 8) { Text("Temperature Data").font(.headline); Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 0) { GridRow { Text("Temperature").fontWeight(.semibold); Text("Value").fontWeight(.semibold) }.padding(.vertical, 8); Divider().gridCellColumns(2); ForEach(sortedPoints) { point in GridRow { Text("\(point.temperatureC.formatted()) °C").monospacedDigit(); Text(valueText(point.value)).monospacedDigit() }.padding(.vertical, 8); Divider().gridCellColumns(2) } }.padding(.horizontal, 14).background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 10)).overlay { RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1) } }
                if let basis = series.basis, !basis.isEmpty { infoSection("Basis", basis) }; if let source = series.source, !source.isEmpty { infoSection("Source", source) }; Text("Stored source data only. No interpolation or extrapolation is applied by this viewer.").font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: 720, alignment: .leading)
        }.navigationTitle(propertyName)
    }
    private func infoSection(_ title: String, _ text: String) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 10)) } }
}

struct MaterialEditorView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    let existing: EngineeringMaterial?
    @State private var advanced = false
    @State private var name: String; @State private var category: String; @State private var grade: String
    @State private var density: String; @State private var conductivity: String; @State private var heatCapacity: String
    @State private var thermalExpansion: String; @State private var minimumServiceTemperature: String; @State private var maximumServiceTemperature: String
    @State private var youngsModulus: String; @State private var poissonsRatio: String; @State private var yieldStrength: String; @State private var ultimateTensileStrength: String; @State private var shearModulus: String; @State private var compressiveStrength: String
    @State private var electricalResistivity: String; @State private var source: String; @State private var notes: String

    init(existing: EngineeringMaterial? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? ""); _category = State(initialValue: existing?.category ?? "Other"); _grade = State(initialValue: existing?.grade ?? "")
        _density = State(initialValue: Self.text(existing?.densityKgM3)); _conductivity = State(initialValue: Self.text(existing?.thermalConductivityWMK)); _heatCapacity = State(initialValue: Self.text(existing?.specificHeatCapacityJkgK))
        _thermalExpansion = State(initialValue: Self.text(existing?.thermalExpansionMicrostrainPerK)); _minimumServiceTemperature = State(initialValue: Self.text(existing?.minimumServiceTemperatureC)); _maximumServiceTemperature = State(initialValue: Self.text(existing?.maximumServiceTemperatureC))
        _youngsModulus = State(initialValue: Self.text(existing?.youngsModulusGPa)); _poissonsRatio = State(initialValue: Self.text(existing?.poissonsRatio)); _yieldStrength = State(initialValue: Self.text(existing?.yieldStrengthMPa)); _ultimateTensileStrength = State(initialValue: Self.text(existing?.ultimateTensileStrengthMPa)); _shearModulus = State(initialValue: Self.text(existing?.shearModulusGPa)); _compressiveStrength = State(initialValue: Self.text(existing?.compressiveStrengthMPa))
        _electricalResistivity = State(initialValue: Self.text(existing?.electricalResistivityOhmM)); _source = State(initialValue: existing?.source ?? ""); _notes = State(initialValue: existing?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("Name") { TextField("Name", text: $name).multilineTextAlignment(.trailing) }
                LabeledContent("Existing category") { Picker("Existing category", selection: $category) { ForEach(store.categories, id: \.self) { Text($0).tag($0) }; if !store.categories.contains(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) { Text(category).tag(category) } }.labelsHidden() }
                LabeledContent("Category") { TextField("Category", text: $category).multilineTextAlignment(.trailing) }
                LabeledContent("Grade / specification") { TextField("Grade / specification", text: $grade).multilineTextAlignment(.trailing) }
            }
            Section("Core Properties") {
                propertyField("Density", unit: "kg/m³", text: $density)
                propertyField("Thermal conductivity", unit: "W/(m·K)", text: $conductivity)
                propertyField("Specific heat capacity", unit: "J/(kg·K)", text: $heatCapacity)
            }
            Section { Toggle("Advanced properties", isOn: $advanced) } footer: { Text("Enable Advanced to enter mechanical, extended thermal and electrical properties. All advanced values are optional. Scientific notation such as 8e-7 is accepted.") }
            if advanced {
                Section("Mechanical") {
                    propertyField("Young's modulus", unit: "GPa", text: $youngsModulus); propertyField("Poisson's ratio", unit: "", text: $poissonsRatio); propertyField("Yield strength", unit: "MPa", text: $yieldStrength); propertyField("Ultimate tensile strength", unit: "MPa", text: $ultimateTensileStrength); propertyField("Shear modulus", unit: "GPa", text: $shearModulus); propertyField("Compressive strength", unit: "MPa", text: $compressiveStrength)
                }
                Section("Extended Thermal") { propertyField("Thermal expansion", unit: "µm/(m·K)", text: $thermalExpansion); propertyField("Minimum service temperature", unit: "°C", text: $minimumServiceTemperature); propertyField("Maximum service temperature", unit: "°C", text: $maximumServiceTemperature) }
                Section("Electrical") { propertyField("Electrical resistivity", unit: "Ω·m", text: $electricalResistivity) }
            }
            Section("Traceability") { LabeledContent("Source / basis") { TextField("Source / basis", text: $source, axis: .vertical).lineLimit(2...6) }; LabeledContent("Notes") { TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...8) } }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.visible)
        .padding(.horizontal, 12)
        .navigationTitle(existing == nil ? "New Material" : "Edit Material")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        .materialEditorSizing()
#if os(macOS)
        .background(MaterialEditorWindowConfigurator())
#endif
    }

    @ViewBuilder private func propertyField(_ label: String, unit: String, text: Binding<String>) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                TextField("Value", text: text).multilineTextAlignment(.trailing).frame(minWidth: 80)
                if !unit.isEmpty { Text(unit).foregroundStyle(.secondary).fixedSize() }
            }
        } label: {
            Text(label).fixedSize(horizontal: false, vertical: true)
        }
    }

    private static func text(_ value: Double?) -> String { EngineeringNumberFormatter.editableString(value) }
    private func number(_ text: String) -> Double? { EngineeringNumberFormatter.parse(text) }
    private func save() {
        let material = EngineeringMaterial(id: existing?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), category: store.canonicalCategory(category), densityKgM3: number(density), grade: grade.isEmpty ? nil : grade,
            thermalConductivityWMK: number(conductivity), specificHeatCapacityJkgK: number(heatCapacity), thermalExpansionMicrostrainPerK: number(thermalExpansion), minimumServiceTemperatureC: number(minimumServiceTemperature), maximumServiceTemperatureC: number(maximumServiceTemperature), youngsModulusGPa: number(youngsModulus), poissonsRatio: number(poissonsRatio), yieldStrengthMPa: number(yieldStrength), ultimateTensileStrengthMPa: number(ultimateTensileStrength), shearModulusGPa: number(shearModulus), compressiveStrengthMPa: number(compressiveStrength), electricalResistivityOhmM: number(electricalResistivity), source: source.isEmpty ? nil : source, notes: notes.isEmpty ? nil : notes,
            unsDesignation: existing?.unsDesignation, standardDesignation: existing?.standardDesignation, productForm: existing?.productForm, materialCondition: existing?.materialCondition, smysMPa: existing?.smysMPa, smtsMPa: existing?.smtsMPa,
            thermalConductivitySeries: existing?.thermalConductivitySeries, specificHeatCapacitySeries: existing?.specificHeatCapacitySeries, thermalExpansionSeries: existing?.thermalExpansionSeries, youngsModulusSeries: existing?.youngsModulusSeries, poissonsRatioSeries: existing?.poissonsRatioSeries, yieldStrengthSeries: existing?.yieldStrengthSeries, ultimateTensileStrengthSeries: existing?.ultimateTensileStrengthSeries, shearModulusSeries: existing?.shearModulusSeries, electricalResistivitySeries: existing?.electricalResistivitySeries)
        if existing == nil { store.add(material) } else { store.update(material) }
    }
}

private extension View {
    @ViewBuilder func materialEditorSizing() -> some View {
#if os(macOS)
        self.frame(minWidth: 640, idealWidth: 760, maxWidth: .infinity, minHeight: 480, idealHeight: 760, maxHeight: .infinity)
#else
        self
#endif
    }
}

#if os(macOS)
private struct MaterialEditorWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { DispatchQueue.main.async { configure(nsView.window) } }
    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 640, height: 480)
        window.contentMinSize = NSSize(width: 640, height: 480)
    }
}
#endif
