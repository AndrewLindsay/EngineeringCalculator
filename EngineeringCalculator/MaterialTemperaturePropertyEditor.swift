import SwiftUI

enum MaterialPropertyInputMode: String, CaseIterable, Identifiable {
    case constant = "Constant"
    case table = "Table"
    case equation = "Equation"
    var id: Self { self }
}

struct EditableMaterialPropertyPoint: Identifiable, Hashable {
    var id = UUID()
    var temperatureC: String = ""
    var value: String = ""
}

struct MaterialPropertyDraft: Hashable {
    var mode: MaterialPropertyInputMode
    var constantValue: String
    var referenceTemperatureC: String
    var table: [EditableMaterialPropertyPoint]
    var a: String
    var b: String
    var c: String
    var d: String
    var minimumTemperatureC: String
    var maximumTemperatureC: String
    var allowsExtrapolation: Bool
    var source: String
    var basis: String

    init(fallback: Double?, series: MaterialPropertySeries?) {
        constantValue = EngineeringNumberFormatter.editableString(series?.referenceValue ?? fallback)
        referenceTemperatureC = EngineeringNumberFormatter.editableString(series?.referenceTemperatureC)
        table = (series?.temperatureTable ?? []).sorted { $0.temperatureC < $1.temperatureC }.map {
            EditableMaterialPropertyPoint(temperatureC: EngineeringNumberFormatter.editableString($0.temperatureC), value: EngineeringNumberFormatter.editableString($0.value))
        }
        if let equation = series?.equation {
            mode = .equation
            a = EngineeringNumberFormatter.editableString(equation.a)
            b = EngineeringNumberFormatter.editableString(equation.b)
            c = EngineeringNumberFormatter.editableString(equation.c)
            d = EngineeringNumberFormatter.editableString(equation.d)
            minimumTemperatureC = EngineeringNumberFormatter.editableString(equation.minimumTemperatureC)
            maximumTemperatureC = EngineeringNumberFormatter.editableString(equation.maximumTemperatureC)
            allowsExtrapolation = equation.allowsExtrapolation
        } else {
            mode = table.isEmpty ? .constant : .table
            a = "0"; b = "0"; c = "0"; d = "0"
            minimumTemperatureC = ""; maximumTemperatureC = ""
            allowsExtrapolation = false
        }
        source = series?.source ?? ""
        basis = series?.basis ?? ""
    }

    private func number(_ text: String) -> Double? { EngineeringNumberFormatter.parse(text) }

    var scalarValue: Double? {
        switch mode {
        case .constant: return number(constantValue)
        case .table, .equation: return number(constantValue)
        }
    }

    func makeSeries() -> MaterialPropertySeries? {
        switch mode {
        case .constant:
            return nil
        case .table:
            let points = table.compactMap { row -> MaterialPropertyPoint? in
                guard let temperature = number(row.temperatureC), let value = number(row.value) else { return nil }
                return MaterialPropertyPoint(temperatureC: temperature, value: value)
            }.sorted { $0.temperatureC < $1.temperatureC }
            guard !points.isEmpty else { return nil }
            return MaterialPropertySeries(referenceValue: number(constantValue), referenceTemperatureC: number(referenceTemperatureC), temperatureTable: points, source: source.isEmpty ? nil : source, basis: basis.isEmpty ? nil : basis)
        case .equation:
            guard let aa = number(a), let bb = number(b), let cc = number(c), let dd = number(d) else { return nil }
            let equation = MaterialPropertyEquation(a: aa, b: bb, c: cc, d: dd, minimumTemperatureC: number(minimumTemperatureC), maximumTemperatureC: number(maximumTemperatureC), allowsExtrapolation: allowsExtrapolation)
            return MaterialPropertySeries(referenceValue: number(constantValue), referenceTemperatureC: number(referenceTemperatureC), equation: equation, source: source.isEmpty ? nil : source, basis: basis.isEmpty ? nil : basis)
        }
    }
}

struct MaterialTemperaturePropertyEditor: View {
    let title: String
    let unit: String
    @Binding var draft: MaterialPropertyDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(title).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Picker("Data type", selection: $draft.mode) {
                    ForEach(MaterialPropertyInputMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }

            switch draft.mode {
            case .constant: constantEditor
            case .table: tableEditor
            case .equation: equationEditor
            }
        }
        .padding(.vertical, 6)
    }

    private var constantEditor: some View {
        HStack {
            Text("Value").foregroundStyle(.secondary)
            Spacer()
            TextField("Value", text: $draft.constantValue).multilineTextAlignment(.trailing).frame(maxWidth: 140)
            if !unit.isEmpty { Text(unit).foregroundStyle(.secondary).fixedSize() }
        }
    }

    private var tableEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            referenceEditor
            HStack {
                Text("Temperature (°C)").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text("Value (\(unit))").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: 30, height: 1)
            }
            ForEach($draft.table) { $row in
                HStack {
                    TextField("Temperature", text: $row.temperatureC).frame(maxWidth: .infinity)
                    TextField("Value", text: $row.value).frame(maxWidth: .infinity)
                    Button(role: .destructive) { draft.table.removeAll { $0.id == row.id } } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless).frame(width: 30)
                }
            }
            Button { draft.table.append(EditableMaterialPropertyPoint()) } label: { Label("Add Row", systemImage: "plus") }
            Text("Linear interpolation is used between table points. Extrapolation beyond the table range is not permitted.")
                .font(.caption).foregroundStyle(.secondary)
            traceabilityEditor
        }
    }

    private var equationEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            referenceEditor
            Text("y(T) = a + bT + cT² + dT³   where T is in °C").font(.callout).monospaced()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                coefficient("a", $draft.a); coefficient("b", $draft.b); coefficient("c", $draft.c); coefficient("d", $draft.d)
            }
            HStack {
                TextField("Minimum temperature (°C)", text: $draft.minimumTemperatureC)
                TextField("Maximum temperature (°C)", text: $draft.maximumTemperatureC)
            }
            Toggle("Allow extrapolation outside valid range", isOn: $draft.allowsExtrapolation)
            traceabilityEditor
        }
    }

    private var referenceEditor: some View {
        HStack {
            TextField("Reference value", text: $draft.constantValue)
            if !unit.isEmpty { Text(unit).foregroundStyle(.secondary).fixedSize() }
            Text("at").foregroundStyle(.secondary)
            TextField("Temperature", text: $draft.referenceTemperatureC).frame(maxWidth: 100)
            Text("°C").foregroundStyle(.secondary)
        }
    }

    private var traceabilityEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Property source", text: $draft.source, axis: .vertical).lineLimit(1...4)
            TextField("Basis / correlation notes", text: $draft.basis, axis: .vertical).lineLimit(1...4)
        }
    }

    private func coefficient(_ label: String, _ value: Binding<String>) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); TextField(label, text: value).labelsHidden() }
    }
}
