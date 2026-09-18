import SwiftUI

struct MaterialLibraryView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.interfaceDensity) private var density
    @State private var showingNew = false

    var body: some View {
        List {
            Section("Built-in Materials") {
                ForEach(store.builtInMaterials) { material in
                    NavigationLink { MaterialDetailView(material: material) } label: { row(material) }
                }
            }
            Section("My Materials") {
                if store.userMaterials.isEmpty {
                    Text("No user materials yet. Duplicate a built-in material or add a new one.")
                        .foregroundStyle(.secondary)
                        .font(.system(size: density.smallSize))
                }
                ForEach(store.userMaterials) { material in
                    NavigationLink { MaterialDetailView(material: material) } label: { row(material) }
                }
                .onDelete(perform: store.delete)
            }
        }
        .navigationTitle("Material Library")
        .toolbar {
            Button { showingNew = true } label: { Label("New Material", systemImage: "plus") }
        }
        .sheet(isPresented: $showingNew) { NavigationStack { MaterialEditorView() } }
        .alert("Material Library", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK") { store.lastError = nil }
        } message: { Text(store.lastError ?? "") }
    }

    private func row(_ material: EngineeringMaterial) -> some View {
        VStack(alignment: .leading, spacing: density.rowPadding) {
            Text(material.name).font(.system(size: density.bodySize, weight: .semibold))
            Text(material.category).font(.system(size: density.smallSize)).foregroundStyle(.secondary)
        }.padding(.vertical, density.rowPadding)
    }
}

private struct MaterialDetailView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    let material: EngineeringMaterial
    @State private var editing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                propertySection("Identity") {
                    propertyRow("Category", material.category)

                    propertyRow(
                        "Library",
                        material.isBuiltIn ? "Built-in" : "My Library"
                    )

                    if let grade = material.grade, !grade.isEmpty {
                        propertyRow("Grade / specification", grade)
                    }
                }

                propertySection("Properties") {
                    propertyRow(
                        "Density",
                        material.densityKgM3,
                        unit: "kg/m³"
                    )

                    propertyRow(
                        "Thermal conductivity",
                        material.thermalConductivityWMK,
                        unit: "W/(m·K)"
                    )

                    propertyRow(
                        "Specific heat capacity",
                        material.specificHeatCapacityJkgK,
                        unit: "J/(kg·K)"
                    )
                }

                if let source = material.source, !source.isEmpty {
                    propertySection("Traceability") {
                        propertyRow("Source / Basis", source)
                    }
                }

                if let notes = material.notes, !notes.isEmpty {
                    propertySection("Notes") {
                        propertyRow("Notes", notes)
                    }
                }

                HStack {
                    if material.isBuiltIn {
                        Button("Duplicate to My Library") {
                            store.duplicate(material)
                        }
                    } else {
                        Button("Edit") {
                            editing = true
                        }
                    }

                    Spacer()
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle(material.name)
        .sheet(isPresented: $editing) {
            NavigationStack {
                MaterialEditorView(existing: material)
            }
        }
    }

    @ViewBuilder
    private func propertySection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                content()
            }
            .background(.quaternary.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.quaternary, lineWidth: 1)
            }
        }
    }

    private func propertyRow(
        _ key: String,
        _ value: String
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(key)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 175, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.horizontal, 12)

            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func propertyRow(
        _ key: String,
        _ value: Double?,
        unit: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(key)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 175, alignment: .leading)

            Divider()
                .padding(.horizontal, 12)

            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value.formatted())
                        .fontWeight(.semibold)
                        .monospacedDigit()

                    Text(unit)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Not specified")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct MaterialEditorView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    let existing: EngineeringMaterial?
    @State private var name: String
    @State private var category: String
    @State private var grade: String
    @State private var density = ""
    @State private var conductivity = ""
    @State private var heatCapacity = ""
    @State private var source = ""
    @State private var notes = ""

    init(existing: EngineeringMaterial? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.category ?? "General")
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
        .navigationTitle(existing == nil ? "New Material" : "Edit Material")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
    }

    private func number(_ text: String) -> Double? { Double(text.replacingOccurrences(of: ",", with: ".")) }
    private func save() {
        let material = EngineeringMaterial(
            id: existing?.id ?? UUID(),
            name: name,
            category: category,
            densityKgM3: number(density),
            grade: grade.isEmpty ? nil : grade,
            thermalConductivityWMK: number(conductivity),
            specificHeatCapacityJkgK: number(heatCapacity),
            source: source.isEmpty ? nil : source,
            notes: notes.isEmpty ? nil : notes
        )
        if existing == nil { store.add(material) } else { store.update(material) }
    }
}

private struct MaterialPropertyRow: View {
    let key: String
    let value: String
    var unit: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(key)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

            Divider()

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                if let unit, !unit.isEmpty {
                    Text(unit)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .background(.quaternary.opacity(0.25))
    }
}

private struct MaterialPropertyGrid<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                content
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
