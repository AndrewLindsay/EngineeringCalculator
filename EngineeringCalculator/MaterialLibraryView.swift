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
            Picker("Materials", selection: $libraryFilter) {
                ForEach(MaterialLibraryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.vertical, 8)

            List {
                ForEach(visibleCategories, id: \.self) { category in
                    Section {
                        let categoryMaterials = materials(in: category)
                        ForEach(categoryMaterials) { material in
                            HStack(spacing: 8) {
                                NavigationLink { MaterialDetailView(materialID: material.id) } label: { row(material) }
                                if !material.isBuiltIn {
                                    Button(role: .destructive) { materialPendingDeletion = material } label: { Image(systemName: "trash").frame(width: 24, height: 24) }
                                        .buttonStyle(.borderless).help("Delete \(material.name)")
                                }
                            }
                            .contextMenu { materialMenu(material, currentCategory: category) }
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
        .toolbar { Button { showingNew = true } label: { Label("New Material", systemImage: "plus") } }
        .sheet(isPresented: $showingNew) { NavigationStack { MaterialEditorView() } }
        .confirmationDialog("Delete Material?", isPresented: Binding(get: { materialPendingDeletion != nil }, set: { if !$0 { materialPendingDeletion = nil } }), titleVisibility: .visible) {
            if let material = materialPendingDeletion { Button("Delete \(material.name)", role: .destructive) { store.delete(id: material.id); materialPendingDeletion = nil } }
            Button("Cancel", role: .cancel) { materialPendingDeletion = nil }
        } message: { Text("This removes the material from My Materials. Built-in materials cannot be deleted.") }
        .alert("Material Library", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) { Button("OK") { store.lastError = nil } } message: { Text(store.lastError ?? "") }
    }

    private var filteredMaterials: [EngineeringMaterial] {
        switch libraryFilter {
        case .all: store.allMaterials
        case .builtIn: store.builtInMaterials
        case .userDefined: store.userMaterials
        }
    }

    private var visibleCategories: [String] {
        store.categories.filter { category in
            filteredMaterials.contains { $0.category.caseInsensitiveCompare(category) == .orderedSame }
        }
    }

    private func materials(in category: String) -> [EngineeringMaterial] {
        filteredMaterials.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func categoryHeader(_ category: String) -> some View { HStack { Text(category); Spacer(); Text("\(materials(in: category).count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }.contentShape(Rectangle()) }
#if os(macOS)
    private func dropTarget(_ category: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 25, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Drop material into \(category)").font(.system(size: 13, weight: .medium))
                Text("Drag normally to move a user material; hold Option while dragging to copy. Built-in materials are always copied.").font(.caption2).foregroundStyle(.tertiary)
            }; Spacer()
        }.foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 8)).overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }.contentShape(Rectangle())
    }
#endif
    @ViewBuilder private func materialMenu(_ material: EngineeringMaterial, currentCategory: String) -> some View {
        Button("Duplicate") { store.duplicate(material) }
        Menu("Copy to Category") { ForEach(store.categories, id: \.self) { target in Button(target) { store.duplicate(material, to: target) } } }
        if !material.isBuiltIn {
            Menu("Move to Category") { ForEach(store.categories.filter { $0.caseInsensitiveCompare(currentCategory) != .orderedSame }, id: \.self) { target in Button(target) { store.move(material, to: target) } } }
            Divider(); Button("Delete", role: .destructive) { materialPendingDeletion = material }
        }
    }
#if os(macOS)
    private func handleDroppedMaterials(_ items: [String], to category: String) -> Bool {
        let optionHeld = NSApp.currentEvent?.modifierFlags.contains(.option) == true; var handled = false
        for item in items { guard let id = UUID(uuidString: item), let material = store.allMaterials.first(where: { $0.id == id }) else { continue }; if material.isBuiltIn || optionHeld { store.duplicate(material, to: category) } else { store.move(material, to: category) }; handled = true }; return handled
    }
#endif
    private func row(_ material: EngineeringMaterial) -> some View {
        VStack(alignment: .leading, spacing: density.rowPadding) {
            HStack { Text(material.name).font(.system(size: density.bodySize, weight: .semibold)); Spacer(); if material.isBuiltIn { Text("Built-in").font(.caption2).foregroundStyle(.secondary) } else { Text("My Material").font(.caption2).foregroundStyle(.secondary)
#if os(macOS)
                Image(systemName: "line.3.horizontal").font(.caption2).foregroundStyle(.tertiary)
#endif
            } }
            if let grade = material.grade, !grade.isEmpty { Text(grade).font(.system(size: density.smallSize)).foregroundStyle(.secondary) }
        }.padding(.vertical, density.rowPadding)
    }
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
                        propertySection("Identity") { propertyRow("Category", material.category); propertyRow("Library", material.isBuiltIn ? "Built-in" : "My Materials"); if let grade = material.grade, !grade.isEmpty { propertyRow("Grade / specification", grade) } }
                        propertySection("Core Properties") { propertyRow("Density", material.densityKgM3, unit: "kg/m³"); propertyRow("Thermal conductivity", material.thermalConductivityWMK, unit: "W/(m·K)"); propertyRow("Specific heat capacity", material.specificHeatCapacityJkgK, unit: "J/(kg·K)") }
                        DisclosureGroup("Advanced Properties", isExpanded: $showAdvanced) {
                            VStack(alignment: .leading, spacing: 16) {
                                propertySection("Mechanical") { propertyRow("Young's modulus", material.youngsModulusGPa, unit: "GPa"); propertyRow("Poisson's ratio", material.poissonsRatio, unit: ""); propertyRow("Yield strength", material.yieldStrengthMPa, unit: "MPa"); propertyRow("Ultimate tensile strength", material.ultimateTensileStrengthMPa, unit: "MPa"); propertyRow("Shear modulus", material.shearModulusGPa, unit: "GPa"); propertyRow("Compressive strength", material.compressiveStrengthMPa, unit: "MPa") }
                                propertySection("Thermal") { propertyRow("Thermal expansion", material.thermalExpansionMicrostrainPerK, unit: "µm/(m·K)"); propertyRow("Minimum service temperature", material.minimumServiceTemperatureC, unit: "°C"); propertyRow("Maximum service temperature", material.maximumServiceTemperatureC, unit: "°C") }
                                propertySection("Electrical") { propertyRow("Electrical resistivity", material.electricalResistivityOhmM, unit: "Ω·m") }
                            }.padding(.top, 10)
                        }.font(.headline)
                        if let source = material.source, !source.isEmpty { propertySection("Traceability") { propertyRow("Source / Basis", source) } }
                        if let notes = material.notes, !notes.isEmpty { propertySection("Notes") { propertyRow("Notes", notes) } }
                        HStack { Button(material.isBuiltIn ? "Duplicate to My Materials" : "Duplicate") { store.duplicate(material) }; if !material.isBuiltIn { Button("Edit") { editing = true }; Button("Delete Material", role: .destructive) { confirmingDelete = true } }; Spacer() }
                    }.padding(24).frame(maxWidth: 720, alignment: .leading)
                }.navigationTitle(material.name).sheet(isPresented: $editing) { NavigationStack { MaterialEditorView(existing: material) } }
                    .confirmationDialog("Delete Material?", isPresented: $confirmingDelete, titleVisibility: .visible) { Button("Delete \(material.name)", role: .destructive) { store.delete(id: material.id); dismiss() }; Button("Cancel", role: .cancel) { } } message: { Text("This removes the material from My Materials.") }
            } else { ContentUnavailableView("Material Not Found", systemImage: "questionmark.folder") }
        }
    }

    @ViewBuilder private func propertySection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(spacing: 0) { content() }
                .background(.quaternary.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1) }
        }
    }

    private var propertyLabelWidth: CGFloat {
#if os(iOS)
        150
#else
        190
#endif
    }

    private func propertyRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(key).fontWeight(.semibold).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).frame(width: propertyLabelWidth, alignment: .leading)
            Divider().padding(.horizontal, 12)
            Text(value).fontWeight(.medium).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
        }.fixedSize(horizontal: false, vertical: true).padding(.horizontal, 14).padding(.vertical, 10).overlay(alignment: .bottom) { Divider() }
    }

    private func propertyRow(_ key: String, _ value: Double?, unit: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(key).fontWeight(.semibold).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).frame(width: propertyLabelWidth, alignment: .leading)
            Divider().padding(.horizontal, 12)
            Group { if let value { Text(unit.isEmpty ? value.formatted() : "\(value.formatted()) \(unit)").monospacedDigit() } else { Text("Not specified").foregroundStyle(.secondary) } }
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        }.fixedSize(horizontal: false, vertical: true).padding(.horizontal, 14).padding(.vertical, 10).overlay(alignment: .bottom) { Divider() }
    }
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
            Section("Identity") { TextField("Name", text: $name); Picker("Existing category", selection: $category) { ForEach(store.categories, id: \.self) { Text($0).tag($0) }; if !store.categories.contains(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) { Text(category).tag(category) } }; TextField("Category (type a new one if required)", text: $category); TextField("Grade / specification", text: $grade) }
            Section("Core Properties") { TextField("Density (kg/m³)", text: $density); TextField("Thermal conductivity (W/(m·K))", text: $conductivity); TextField("Specific heat capacity (J/(kg·K))", text: $heatCapacity) }
            Section { Toggle("Advanced properties", isOn: $advanced) } footer: { Text("Enable Advanced to enter mechanical, extended thermal and electrical properties. All advanced values are optional.") }
            if advanced {
                Section("Mechanical") { TextField("Young's modulus (GPa)", text: $youngsModulus); TextField("Poisson's ratio", text: $poissonsRatio); TextField("Yield strength (MPa)", text: $yieldStrength); TextField("Ultimate tensile strength (MPa)", text: $ultimateTensileStrength); TextField("Shear modulus (GPa)", text: $shearModulus); TextField("Compressive strength (MPa)", text: $compressiveStrength) }
                Section("Extended Thermal") { TextField("Thermal expansion (µm/(m·K))", text: $thermalExpansion); TextField("Minimum service temperature (°C)", text: $minimumServiceTemperature); TextField("Maximum service temperature (°C)", text: $maximumServiceTemperature) }
                Section("Electrical") { TextField("Electrical resistivity (Ω·m)", text: $electricalResistivity) }
            }
            Section("Traceability") { TextField("Source / basis", text: $source, axis: .vertical); TextField("Notes", text: $notes, axis: .vertical) }
        }.navigationTitle(existing == nil ? "New Material" : "Edit Material").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
    }

    private static func text(_ value: Double?) -> String { value.map { String($0) } ?? "" }
    private func number(_ text: String) -> Double? { Double(text.replacingOccurrences(of: ",", with: ".")) }
    private func save() {
        let material = EngineeringMaterial(id: existing?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), category: store.canonicalCategory(category), densityKgM3: number(density), grade: grade.isEmpty ? nil : grade,
            thermalConductivityWMK: number(conductivity), specificHeatCapacityJkgK: number(heatCapacity), thermalExpansionMicrostrainPerK: number(thermalExpansion), minimumServiceTemperatureC: number(minimumServiceTemperature), maximumServiceTemperatureC: number(maximumServiceTemperature),
            youngsModulusGPa: number(youngsModulus), poissonsRatio: number(poissonsRatio), yieldStrengthMPa: number(yieldStrength), ultimateTensileStrengthMPa: number(ultimateTensileStrength), shearModulusGPa: number(shearModulus), compressiveStrengthMPa: number(compressiveStrength), electricalResistivityOhmM: number(electricalResistivity), source: source.isEmpty ? nil : source, notes: notes.isEmpty ? nil : notes)
        if existing == nil { store.add(material) } else { store.update(material) }
    }
}