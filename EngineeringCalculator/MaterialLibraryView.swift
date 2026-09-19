import SwiftUI

struct MaterialLibraryView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.interfaceDensity) private var density
    @State private var showingNew = false
    @State private var materialPendingDeletion: EngineeringMaterial?

    var body: some View {
        List {
            ForEach(store.categories, id: \.self) { category in
                Section {
                    let materials = materials(in: category)
                    if materials.isEmpty {
                        dropTarget(category, compact: true)
                    } else {
                        ForEach(materials) { material in
                            HStack(spacing: 8) {
                                NavigationLink { MaterialDetailView(materialID: material.id) } label: { row(material) }
                                if !material.isBuiltIn {
                                    Button(role: .destructive) { materialPendingDeletion = material } label: {
                                        Image(systemName: "trash")
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Delete \(material.name)")
                                }
                            }
                            .contextMenu { materialMenu(material, currentCategory: category) }
#if os(macOS)
                            .draggable(material.id.uuidString)
#endif
                        }
                    }
#if os(macOS)
                    dropTarget(category, compact: false)
                        .dropDestination(for: String.self) { items, _ in
                            moveDroppedMaterials(items, to: category)
                        }
#endif
                } header: {
                    categoryHeader(category)
                }
            }
        }
        .navigationTitle("Material Library")
        .toolbar { Button { showingNew = true } label: { Label("New Material", systemImage: "plus") } }
        .sheet(isPresented: $showingNew) { NavigationStack { MaterialEditorView() } }
        .confirmationDialog("Delete Material?", isPresented: Binding(
            get: { materialPendingDeletion != nil },
            set: { if !$0 { materialPendingDeletion = nil } }
        ), titleVisibility: .visible) {
            if let material = materialPendingDeletion {
                Button("Delete \(material.name)", role: .destructive) {
                    store.delete(id: material.id)
                    materialPendingDeletion = nil
                }
            }
            Button("Cancel", role: .cancel) { materialPendingDeletion = nil }
        } message: {
            Text("This removes the material from My Materials. Built-in materials cannot be deleted.")
        }
        .alert("Material Library", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK") { store.lastError = nil }
        } message: { Text(store.lastError ?? "") }
    }

    private func materials(in category: String) -> [EngineeringMaterial] {
        store.allMaterials
            .filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func categoryHeader(_ category: String) -> some View {
        HStack {
            Text(category)
            Spacer()
            Text("\(materials(in: category).count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func dropTarget(_ category: String, compact: Bool) -> some View {
#if os(macOS)
        HStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: compact ? 20 : 24, weight: .semibold))
            Text("Drop material into \(category)")
                .font(.system(size: compact ? 12 : 13, weight: .medium))
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 8 : 11)
        .frame(maxWidth: .infinity, minHeight: compact ? 38 : 46, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }
        .contentShape(Rectangle())
        .help("Drag a user-created material here to move it to \(category)")
#else
        if compact {
            Text("No materials")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
#endif
    }

    @ViewBuilder
    private func materialMenu(_ material: EngineeringMaterial, currentCategory: String) -> some View {
        if material.isBuiltIn {
            Button("Duplicate to My Materials") { store.duplicate(material) }
        } else {
            Menu("Move to Category") {
                ForEach(store.categories.filter { $0.caseInsensitiveCompare(currentCategory) != .orderedSame }, id: \.self) { target in
                    Button(target) { store.move(material, to: target) }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { materialPendingDeletion = material }
        }
    }

#if os(macOS)
    private func moveDroppedMaterials(_ items: [String], to category: String) -> Bool {
        var moved = false
        for item in items {
            guard let id = UUID(uuidString: item),
                  let material = store.userMaterials.first(where: { $0.id == id }) else { continue }
            store.move(material, to: category)
            moved = true
        }
        return moved
    }
#endif

    private func row(_ material: EngineeringMaterial) -> some View {
        VStack(alignment: .leading, spacing: density.rowPadding) {
            HStack {
                Text(material.name).font(.system(size: density.bodySize, weight: .semibold))
                Spacer()
                if material.isBuiltIn {
                    Text("Built-in").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("My Material").font(.caption2).foregroundStyle(.secondary)
#if os(macOS)
                    Image(systemName: "line.3.horizontal").font(.caption2).foregroundStyle(.tertiary)
#endif
                }
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
    @State private var confirmingDelete = false
    @Environment(\.dismiss) private var dismiss
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
                            if material.isBuiltIn {
                                Button("Duplicate to My Materials") { store.duplicate(material) }
                            } else {
                                Button("Edit") { editing = true }
                                Button("Delete Material", role: .destructive) { confirmingDelete = true }
                            }
                            Spacer()
                        }
                    }.padding(24).frame(maxWidth: 720, alignment: .leading)
                }
                .navigationTitle(material.name)
                .sheet(isPresented: $editing) { NavigationStack { MaterialEditorView(existing: material) } }
                .confirmationDialog("Delete Material?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete \(material.name)", role: .destructive) {
                        store.delete(id: material.id)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This removes the material from My Materials.")
                }
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
        _density = State(initialValue: existing?.densityKgM3.map { String($0) } ?? "")
        _conductivity = State(initialValue: existing?.thermalConductivityWMK.map { String($0) } ?? "")
        _heatCapacity = State(initialValue: existing?.specificHeatCapacityJkgK.map { String($0) } ?? "")
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
