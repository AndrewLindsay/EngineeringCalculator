import SwiftUI

struct MaterialPropertyInspectorView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @State private var selectedMaterialID: UUID?
    @State private var selectedProperty: MaterialPropertyKind?
    @State private var temperatureText = "20"

    private var materials: [EngineeringMaterial] { store.builtInMaterials + store.userMaterials }
    private var material: EngineeringMaterial? { materials.first { $0.id == selectedMaterialID } ?? materials.first }
    private var properties: [MaterialPropertyKind] { material.map(MaterialPropertyResolver.availableProperties) ?? [] }
    private var property: MaterialPropertyKind? { selectedProperty.flatMap { properties.contains($0) ? $0 : nil } ?? properties.first }
    private var temperature: Double? { Double(temperatureText.replacingOccurrences(of: ",", with: ".")) }
    private var resolution: MaterialPropertyResolution? { guard let material, let property else { return nil }; return MaterialPropertyResolver.resolve(property, in: material, atTemperatureC: temperature) }

    var body: some View {
        Form {
            Section("Selection") {
                Picker("Material", selection: Binding(get: { material?.id }, set: { selectedMaterialID = $0; selectedProperty = nil })) {
                    ForEach(materials) { Text($0.name).tag(Optional($0.id)) }
                }
                if let material {
                    Picker("Property", selection: Binding(get: { property }, set: { selectedProperty = $0 })) {
                        ForEach(properties) { Text($0.name).tag(Optional($0)) }
                    }
                }
            }
            if let material, let property {
                Section("Evaluate") {
                    LabeledContent("Temperature") {
                        HStack(spacing: 6) { TextField("Temperature", text: $temperatureText).multilineTextAlignment(.trailing).frame(maxWidth: 120); Text("°C").foregroundStyle(.secondary) }
                    }
                    if let r = resolution {
                        LabeledContent("Result") { Text(resultText(r)).monospacedDigit() }
                        LabeledContent("Method") { Text(methodText(r)) }
                        statusView(r)
                    }
                }
                sourceDataSection(material: material, property: property)
                if let r = resolution, r.source != nil || r.basis != nil {
                    Section("Traceability") {
                        if let basis = r.basis, !basis.isEmpty { LabeledContent("Basis") { Text(basis).multilineTextAlignment(.trailing) } }
                        if let source = r.source, !source.isEmpty { LabeledContent("Source") { Text(source).multilineTextAlignment(.trailing).textSelection(.enabled) } }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Material Property Inspector")
        .onAppear { if selectedMaterialID == nil { selectedMaterialID = materials.first?.id } }
    }

    @ViewBuilder private func statusView(_ r: MaterialPropertyResolution) -> some View {
        switch r.status {
        case .resolved:
            if r.isExtrapolated { Text("Extrapolated outside the stated equation range.").foregroundStyle(.orange) }
            if let lo = r.lowerPoint, let hi = r.upperPoint, lo.temperatureC != hi.temperatureC { Text("Interpolating between \(lo.temperatureC.formatted()) °C / \(lo.value.formatted()) and \(hi.temperatureC.formatted()) °C / \(hi.value.formatted()).").font(.caption).foregroundStyle(.secondary) }
        case .temperatureRequired: Text("Enter a temperature to evaluate this property.").foregroundStyle(.secondary)
        case .missing: Text("No usable data are available for this property.").foregroundStyle(.red)
        case .outsideAvailableRange(let min, let max): Text("Outside tabulated range: \(min.formatted())–\(max.formatted()) °C. Extrapolation is not performed.").foregroundStyle(.orange)
        case .outsideEquationRange(let min, let max): Text("Outside equation validity range \(rangeText(min, max)). Extrapolation is disabled.").foregroundStyle(.orange)
        }
    }

    @ViewBuilder private func sourceDataSection(material: EngineeringMaterial, property: MaterialPropertyKind) -> some View {
        let series = seriesFor(property, material)
        if let series, !series.temperatureTable.isEmpty {
            Section("Tabulated Data") {
                ForEach(series.temperatureTable.sorted { $0.temperatureC < $1.temperatureC }) { point in
                    LabeledContent("\(point.temperatureC.formatted()) °C") { Text("\(point.value.formatted()) \(property.unit)").monospacedDigit() }
                }
            }
        } else if let equation = series?.equation {
            Section("Equation") {
                Text("y = a + bT + cT² + dT³").font(.system(.body, design: .monospaced))
                LabeledContent("a") { Text(equation.a.formatted()) }; LabeledContent("b") { Text(equation.b.formatted()) }; LabeledContent("c") { Text(equation.c.formatted()) }; LabeledContent("d") { Text(equation.d.formatted()) }
            }
        }
    }

    private func resultText(_ r: MaterialPropertyResolution) -> String { guard let value = r.value else { return "—" }; return r.unit.isEmpty ? value.formatted() : "\(value.formatted()) \(r.unit)" }
    private func methodText(_ r: MaterialPropertyResolution) -> String { switch r.method { case .constant: return "Constant"; case .tableExact: return "Tabulated value"; case .linearInterpolation: return "Linear interpolation"; case .equation: return "Equation"; case nil: return "—" } }
    private func rangeText(_ min: Double?, _ max: Double?) -> String { "\(min.map { $0.formatted() } ?? "−∞")–\(max.map { $0.formatted() } ?? "+∞") °C" }
    private func seriesFor(_ p: MaterialPropertyKind, _ m: EngineeringMaterial) -> MaterialPropertySeries? { switch p { case .thermalConductivity: return m.thermalConductivitySeries; case .specificHeatCapacity: return m.specificHeatCapacitySeries; case .thermalExpansion: return m.thermalExpansionSeries; case .youngsModulus: return m.youngsModulusSeries; case .poissonsRatio: return m.poissonsRatioSeries; case .yieldStrength: return m.yieldStrengthSeries; case .ultimateTensileStrength: return m.ultimateTensileStrengthSeries; case .shearModulus: return m.shearModulusSeries; case .electricalResistivity: return m.electricalResistivitySeries; default: return nil } }
}
