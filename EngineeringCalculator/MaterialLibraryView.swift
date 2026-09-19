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
        .toolbar { Button { showingNew = true } label: { Label("New Material", systemImage: "plus") } }
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
                    propertyRow("Library", material.isBuiltIn ? "Built-in" : "My Library")
                    if let grade = material.grade, !grade.isEmpty { propertyRow("Grade / specification", grade) }
                }
                propertySection("Core Properties") {
                    propertyRow("Density", propertySummary(material.densityProperty, fallback: material.densityKgM3), unit: "kg/m³")
                    propertyRow("Thermal conductivity", propertySummary(material.thermalConductivityProperty, fallback: material.thermalConductivityWMK), unit: "W/(m·K)")
                    propertyRow("Specific heat capacity", propertySummary(material.specificHeatCapacityProperty, fallback: material.specificHeatCapacityJkgK), unit: "J/(kg·K)")
                }
                if let source = material.source, !source.isEmpty { propertySection("Traceability") { propertyRow("Source / Basis", source) } }
                if let notes = material.notes, !notes.isEmpty { propertySection("Notes") { propertyRow("Notes", notes) } }
                HStack {
                    if material.isBuiltIn { Button("Duplicate to My Library") { store.duplicate(material) } }
                    else { Button("Edit") { editing = true } }
                    Spacer()
                }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .navigationTitle(material.name)
        .sheet(isPresented: $editing) { NavigationStack { MaterialEditorView(existing: material) } }
    }

    private func propertySummary(_ property: EngineeringPropertyValue?, fallback: Double?) -> String {
        guard let property else { return fallback?.formatted() ?? "Not specified" }
        switch property {
        case .constant(let value): return value.formatted()
        case .temperatureTable(let points): return "Temperature table (\(points.count) points)"
        case .temperatureEquation: return "Temperature equation"
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

    private func propertyRow(_ key: String, _ value: String, unit: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(key).fontWeight(.semibold).foregroundStyle(.secondary)
                .frame(width: 175, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            Divider().padding(.horizontal, 12)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value).fontWeight(.medium).textSelection(.enabled)
                if let unit, !value.hasPrefix("Temperature") { Text(unit).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private enum PropertyInputMode: String, CaseIterable, Identifiable {
    case constant = "Constant"
    case table = "Table"
    case equation = "Equation"
    var id: String { rawValue }
}

private struct EditableTemperaturePoint: Identifiable, Hashable {
    var id = UUID()
    var temperature = ""
    var value = ""
}

private struct PropertyDraft {
    var mode: PropertyInputMode = .constant
    var constant = ""
    var points: [EditableTemperaturePoint] = []
    var a = "0", b = "0", c = "0", d = "0"
    var minimumTemperature = ""
    var maximumTemperature = ""
    var allowsExtrapolation = false

    init(property: EngineeringPropertyValue?, fallback: Double?) {
        guard let property else { constant = fallback.map(String.init) ?? ""; return }
        switch property {
        case .constant(let value):
            mode = .constant; constant = String(value)
        case .temperatureTable(let sourcePoints):
            mode = .table
            points = sourcePoints.sorted { $0.temperatureC < $1.temperatureC }.map {
                EditableTemperaturePoint(temperature: String($0.temperatureC), value: String($0.value))
            }
        case .temperatureEquation(let equation):
            mode = .equation
            a = String(equation.a); b = String(equation.b); c = String(equation.c); d = String(equation.d)
            minimumTemperature = equation.minimumTemperatureC.map(String.init) ?? ""
            maximumTemperature = equation.maximumTemperatureC.map(String.init) ?? ""
            allowsExtrapolation = equation.allowsExtrapolation
        }
    }

    func makeValue() -> EngineeringPropertyValue? {
        func number(_ text: String) -> Double? { Double(text.replacingOccurrences(of: ",", with: ".")) }
        switch mode {
        case .constant:
            return number(constant).map { .constant($0) }
        case .table:
            let parsed = points.compactMap { row -> TemperaturePropertyPoint? in
                guard let t = number(row.temperature), let v = number(row.value) else { return nil }
                return TemperaturePropertyPoint(temperatureC: t, value: v)
            }.sorted { $0.temperatureC < $1.temperatureC }
            return parsed.isEmpty ? nil : .temperatureTable(parsed)
        case .equation:
            guard let aa = number(a), let bb = number(b), let cc = number(c), let dd = number(d) else { return nil }
            return .temperatureEquation(TemperatureEquation(a: aa, b: bb, c: cc, d: dd,
                minimumTemperatureC: number(minimumTemperature), maximumTemperatureC: number(maximumTemperature),
                allowsExtrapolation: allowsExtrapolation))
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
    @State private var density: PropertyDraft
    @State private var conductivity: PropertyDraft
    @State private var heatCapacity: PropertyDraft
    @State private var source: String
    @State private var notes: String

    init(existing: EngineeringMaterial? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.category ?? "General")
        _grade = State(initialValue: existing?.grade ?? "")
        _density = State(initialValue: PropertyDraft(property: existing?.densityProperty, fallback: existing?.densityKgM3))
        _conductivity = State(initialValue: PropertyDraft(property: existing?.thermalConductivityProperty, fallback: existing?.thermalConductivityWMK))
        _heatCapacity = State(initialValue: PropertyDraft(property: existing?.specificHeatCapacityProperty, fallback: existing?.specificHeatCapacityJkgK))
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
            .padding(.horizontal, 8)

            Section("Core Properties") {
                MaterialPropertyEditor(title: "Density", unit: "kg/m³", draft: $density)
                MaterialPropertyEditor(title: "Thermal conductivity", unit: "W/(m·K)", draft: $conductivity)
                MaterialPropertyEditor(title: "Specific heat capacity", unit: "J/(kg·K)", draft: $heatCapacity)
            }
            .padding(.horizontal, 8)

            Section("Traceability") {
                TextField("Source / basis", text: $source, axis: .vertical).lineLimit(2...8)
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...8)
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle(existing == nil ? "New Material" : "Edit Material")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save(); dismiss() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .materialEditorWindowSizing()
    }

    private func save() {
        let densityValue = density.makeValue()
        let conductivityValue = conductivity.makeValue()
        let heatCapacityValue = heatCapacity.makeValue()
        let referenceTemperature = 20.0
        let material = EngineeringMaterial(
            id: existing?.id ?? UUID(), name: name, category: category,
            densityKgM3: densityValue?.value(atTemperatureC: referenceTemperature),
            grade: grade.isEmpty ? nil : grade,
            thermalConductivityWMK: conductivityValue?.value(atTemperatureC: referenceTemperature),
            specificHeatCapacityJkgK: heatCapacityValue?.value(atTemperatureC: referenceTemperature),
            densityProperty: densityValue, thermalConductivityProperty: conductivityValue,
            specificHeatCapacityProperty: heatCapacityValue,
            source: source.isEmpty ? nil : source, notes: notes.isEmpty ? nil : notes
        )
        if existing == nil { store.add(material) } else { store.update(material) }
    }
}

private struct MaterialPropertyEditor: View {
    let title: String
    let unit: String
    @Binding var draft: PropertyDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).fontWeight(.semibold)
                Spacer()
                Picker("Data type", selection: $draft.mode) {
                    ForEach(PropertyInputMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented).frame(maxWidth: 310)
            }

            switch draft.mode {
            case .constant:
                HStack { TextField("Value", text: $draft.constant); Text(unit).foregroundStyle(.secondary) }
            case .table:
                tableEditor
            case .equation:
                equationEditor
            }
        }
        .padding(.vertical, 6)
    }

    private var tableEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Temperature (°C)").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text("Value (\(unit))").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: 28, height: 1)
            }
            ForEach($draft.points) { $point in
                HStack {
                    TextField("Temperature", text: $point.temperature).frame(maxWidth: .infinity)
                    TextField("Value", text: $point.value).frame(maxWidth: .infinity)
                    Button(role: .destructive) { draft.points.removeAll { $0.id == point.id } } label: {
                        Image(systemName: "minus.circle")
                    }.buttonStyle(.borderless).frame(width: 28)
                }
            }
            Button { draft.points.append(EditableTemperaturePoint()) } label: { Label("Add Row", systemImage: "plus") }
            Text("Values are linearly interpolated between temperatures. Values outside the table range are not extrapolated.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var equationEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("y(T) = a + bT + cT² + dT³   (T in °C)").font(.callout).monospaced()
            HStack {
                coefficient("a", $draft.a); coefficient("b", $draft.b)
                coefficient("c", $draft.c); coefficient("d", $draft.d)
            }
            HStack {
                TextField("Minimum temperature (°C)", text: $draft.minimumTemperature)
                TextField("Maximum temperature (°C)", text: $draft.maximumTemperature)
            }
            Toggle("Allow extrapolation outside the valid temperature range", isOn: $draft.allowsExtrapolation)
            Text("Leave a temperature limit blank when the source does not specify that bound.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func coefficient(_ label: String, _ value: Binding<String>) -> some View {
        HStack(spacing: 4) { Text(label).foregroundStyle(.secondary); TextField(label, text: value).labelsHidden() }
    }
}

private extension View {
    @ViewBuilder func materialEditorWindowSizing() -> some View {
        #if os(macOS)
        self.frame(minWidth: 620, idealWidth: 720, minHeight: 560, idealHeight: 760)
        #else
        self
        #endif
    }
}
