import SwiftUI

struct MaterialLibraryView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.interfaceDensity) private var density
    @State private var showingNew = false

    var body: some View {
        List {
            ForEach(store.categories, id: \.self) { category in
                let materials = store.allMaterials.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }
                if !materials.isEmpty {
                    Section(category) {
                        ForEach(materials) { material in
                            NavigationLink { MaterialDetailView(materialID: material.id) } label: { row(material) }
                                .contextMenu {
                                    if material.isBuiltIn {
                                        Button("Duplicate to My Materials") { store.duplicate(material) }
                                    } else {
                                        Menu("Move to Category") {
                                            ForEach(store.categories.filter { $0.caseInsensitiveCompare(category) != .orderedSame }, id: \.self) { target in
                                                Button(target) { store.move(material, to: target) }
                                            }
                                        }
                                        Divider()
                                        Button("Delete", role: .destructive) { store.delete(id: material.id) }
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Material Library")
        .toolbar { Button { showingNew = true } label: { Label("New Material", systemImage: "plus") } }
        .sheet(isPresented: $showingNew) { NavigationStack { MaterialEditorView() } }
        .alert("Material Library", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK") { store.lastError = nil }
        } message: { Text(store.lastError ?? "") }
    }

    private func row(_ material: EngineeringMaterial) -> some View {
        VStack(alignment: .leading, spacing: density.rowPadding) {
            HStack {
                Text(material.name).font(.system(size: density.bodySize, weight: .semibold))
                if material.isBuiltIn { Text("Built-in").font(.caption2).foregroundStyle(.secondary) }
            }
            if let grade = material.grade, !grade.isEmpty {
                Text(grade).font(.system(size: density.smallSize)).foregroundStyle(.secondary)
            }
        }.padding(.vertical, density.rowPadding)
    }
}

private struct MaterialDetailView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    let materialID: UUID
    @State private var editing = false

    private var material: EngineeringMaterial? { store.allMaterials.first { $0.id == materialID } }

    var body: some View {
        Group {
            if let material {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        propertySection("Identity") {
                            propertyRow("Category", material.category)
                            propertyRow("Library", material.isBuiltIn ? "Built-in" : "My Materials")
                            if let grade = material.grade, !grade.isEmpty { propertyRow("Grade / specification", grade) }
                        }
                        propertySection("Properties") {
                            propertyRow("Density", material.densityKgM3, unit: "kg/m³")
                            propertyRow("Thermal conductivity", material.thermalConductivityWMK, unit: "W/(m·K)")
                            propertyRow("Specific heat capacity", material.specificHeatCapacityJkgK, unit: "J/(kg·K)")
                        }
                        if let source = material.source, !source.isEmpty { propertySection("Traceability") { propertyRow("Source / Basis", source) } }
                        if let notes = material.notes, !notes.isEmpty { propertySection("Notes") { propertyRow("Notes", notes) } }
                        HStack {
                            if material.isBuiltIn { Button("Duplicate to My Materials") { store.duplicate(material) } }
                            else { Button("Edit") { editing = true } }
                            Spacer()
                        }
                    }.padding(24).frame(maxWidth: 720, alignment: .leading)
                }
                .navigationTitle(material.name)
                .sheet(isPresented: $editing) { NavigationStack { MaterialEditorView(existing: material) } }
            } else { ContentUnavailableView("Material Not Found", systemImage: "questionmark.folder") }
        }
    }

    @ViewBuilder private func propertySection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(spacing: 0) { content() }.background(.quaternary.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1) }
        }
    }
    private func propertyRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(key).fontWeight(.semibold).foregroundStyle(.secondary).frame(width: 175, alignment: .leading)
            Divider().padding(.horizontal, 12)
            Text(value).fontWeight(.medium).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
        }.padding(.horizontal, 14).padding(.vertical, 10).overlay(alignment: .bottom) { Divider() }
    }
    private func propertyRow(_ key: String, _ value: Double?, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(key).fontWeight(.semibold).foregroundStyle(.secondary).frame(width: 175, alignment: .leading)
            Divider().padding(.horizontal, 12)
            if let value { Text("\(value.formatted()) \(unit)").monospacedDigit() }
            else { Text("Not specified").foregroundStyle(.secondary) }
            Spacer()
        }.padding(.horizontal, 14).padding(.vertical, 10).overlay(alignment: .bottom) { Divider() }
    }
}

struct MaterialEditorView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    let existing: EngineeringMaterial?
    @State private var name: String
    @State private var category: String
    @State private var grade: String
    @State private var density: String
    @State private var conductivity: String
    @State private var heatCapacity: String
    @State private var source: String
    @State private var notes: String

    init(existing: EngineeringMaterial? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.category ?? "Other")
        _grade = State(initialValue: existing?.grade ?? "")
        _density = State(initialValue: existing?.densityKgM3.map(String.init) ?? "")
        _conductivity = State(initialValue: existing?.thermalConductivityWMK.map(String.init) ?? "")
        _heatCapacity = State(initialValue: existing?.specificHeatCapacityJkgK.map(String.init) ?? "")
        _source = State(initialValue: existing?.source ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $name)
                Picker("Existing category", selection: $category) {
                    ForEach(store.categories, id: \.self) { Text($0).tag($0) }
                    if !store.categories.contains(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) { Text(category).tag(category) }
                }
                TextField("Category (type a new one if required)", text: $category)
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
        .navigationTitle(existing == nil ? "New Material" : "Edit Material")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
    }

    private func number(_ text: String) -> Double? { Double(text.replacingOccurrences(of: ",", with: ".")) }
    private func save() {
        let material = EngineeringMaterial(id: existing?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: store.canonicalCategory(category), densityKgM3: number(density), grade: grade.isEmpty ? nil : grade,
            thermalConductivityWMK: number(conductivity), specificHeatCapacityJkgK: number(heatCapacity),
            source: source.isEmpty ? nil : source, notes: notes.isEmpty ? nil : notes)
        if existing == nil { store.add(material) } else { store.update(material) }
    }
}
