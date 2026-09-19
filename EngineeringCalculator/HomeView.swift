import SwiftUI
import Charts

struct HomeView: View {
    @AppStorage("calculatorOrder") private var storedOrder = ""
    @Environment(\.interfaceDensity) private var density

    private var orderedCalculations: [CalculationDefinition] {
        let saved = storedOrder.split(separator: ",").map(String.init)
        let lookup = Dictionary(uniqueKeysWithValues: CalculationRegistry.all.map { ($0.id, $0) })
        let savedItems = saved.compactMap { lookup[$0] }
        let savedSet = Set(saved)
        return savedItems + CalculationRegistry.all.filter { !savedSet.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(orderedCalculations) { calculation in
                        NavigationLink(value: calculation.id) {
                            Label {
                                VStack(alignment: .leading, spacing: density.rowPadding) {
                                    Text(calculation.title).font(.system(size: density.bodySize, weight: .semibold))
                                    Text(calculation.subtitle).font(.system(size: density.smallSize)).foregroundStyle(.secondary)
                                }
                            } icon: { Image(systemName: calculation.systemImage).font(.system(size: density.bodySize + 3)) }
                            .padding(.vertical, density.rowPadding)
                        }
                    }.onMove(perform: move)
                } header: { Text("Calculations") } footer: {
                    #if os(iOS)
                    Text("Tap Edit to rearrange calculators. Your preferred order is saved on this device.")
                    #elseif os(macOS)
                    Text("Drag calculators to rearrange them. Your preferred order is saved on this Mac.")
                    #endif
                }
            }
            .navigationTitle("Engineering Calculator")
            .toolbar {
                #if os(iOS)
                EditButton()
                #endif
                NavigationLink(value: "propertyInspector") { Image(systemName: "chart.xyaxis.line") }.help("Material property inspector")
                NavigationLink(value: "materials") { Image(systemName: "books.vertical") }.help("Material library")
                NavigationLink(value: "settings") { Image(systemName: "gearshape") }.help("Interface settings")
            }
            .navigationDestination(for: String.self) { id in
                switch id {
                case "pipeWeightBuoyancy": PipeWeightBuoyancyView()
                case "propertyInspector": MaterialPropertyInspectorView()
                case "materials": MaterialLibraryView()
                case "settings": SettingsView()
                default: PlaceholderCalculatorView()
                }
            }
        }
    }
    private func move(from source: IndexSet, to destination: Int) { var items = orderedCalculations; items.move(fromOffsets: source, toOffset: destination); storedOrder = items.map(\.id).joined(separator: ",") }
}

private struct SettingsView: View {
    @AppStorage("interfaceDensity") private var densityRaw = InterfaceDensity.compact.rawValue
    @Environment(\.interfaceDensity) private var density
    var body: some View {
        Form {
            Section("Interface") {
                Picker("Interface Density", selection: $densityRaw) { ForEach(InterfaceDensity.allCases) { option in Text(option.title).tag(option.rawValue) } }.pickerStyle(.segmented)
                Text("Compact shows more engineering data on screen. Standard uses a conventional layout. Comfortable increases text and spacing.").font(.system(size: density.smallSize)).foregroundStyle(.secondary)
            }
            Section("Preview") {
                LabeledContent("Pipe density") { Text("7,850 kg/m³").monospacedDigit() }.font(.system(size: density.bodySize))
                LabeledContent("Wall thickness") { Text("20.00 mm").monospacedDigit() }.font(.system(size: density.bodySize))
            }
        }.formStyle(.grouped).navigationTitle("Settings")
    }
}

private struct PlaceholderCalculatorView: View {
    var body: some View { ContentUnavailableView("Future Calculator", systemImage: "wrench.and.screwdriver", description: Text("Add future calculation modules here.")).navigationTitle("Future Calculator") }
}

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
                Picker("Material", selection: Binding(get: { material?.id }, set: { selectedMaterialID = $0; selectedProperty = nil })) { ForEach(materials) { Text($0.name).tag(Optional($0.id)) } }
                if material != nil { Picker("Property", selection: Binding(get: { property }, set: { selectedProperty = $0 })) { ForEach(properties) { Text($0.name).tag(Optional($0)) } } }
            }
            if let material, let property {
                Section("Evaluate") {
                    LabeledContent("Temperature") { HStack(spacing: 6) { TextField("Temperature", text: $temperatureText).multilineTextAlignment(.trailing).frame(maxWidth: 120); Text("°C").foregroundStyle(.secondary) } }
                    if let r = resolution { LabeledContent("Result") { Text(resultText(r)).monospacedDigit() }; LabeledContent("Method") { Text(methodText(r)) }; statusView(r) }
                }
                propertyGraphSection(material: material, property: property)
                sourceDataSection(material: material, property: property)
                if let r = resolution, r.source != nil || r.basis != nil {
                    Section("Traceability") {
                        if let basis = r.basis, !basis.isEmpty { LabeledContent("Basis") { Text(basis).multilineTextAlignment(.trailing) } }
                        if let source = r.source, !source.isEmpty { LabeledContent("Source") { Text(source).multilineTextAlignment(.trailing).textSelection(.enabled) } }
                    }
                }
            }
        }.formStyle(.grouped).navigationTitle("Material Property Inspector").onAppear { if selectedMaterialID == nil { selectedMaterialID = materials.first?.id } }
    }

    @ViewBuilder private func propertyGraphSection(material: EngineeringMaterial, property: MaterialPropertyKind) -> some View {
        if let series = seriesFor(property, material), !series.temperatureTable.isEmpty || series.equation != nil {
            Section("Property Graph") {
                PropertySeriesChart(
                    series: series,
                    property: property,
                    selectedTemperature: temperature,
                    selectedValue: resolution?.value
                )
                Text(series.equation == nil ? "Line shows linear interpolation between tabulated values. The larger point is the evaluated result." : "Line shows the stored equation over its stated range. The larger point is the evaluated result.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
        if let series, !series.temperatureTable.isEmpty { Section("Tabulated Data") { ForEach(series.temperatureTable.sorted { $0.temperatureC < $1.temperatureC }) { point in LabeledContent("\(point.temperatureC.formatted()) °C") { Text("\(point.value.formatted()) \(property.unit)").monospacedDigit() } } } }
        else if let equation = series?.equation { Section("Equation") { Text("y = a + bT + cT² + dT³").font(.system(.body, design: .monospaced)); LabeledContent("a") { Text(equation.a.formatted()) }; LabeledContent("b") { Text(equation.b.formatted()) }; LabeledContent("c") { Text(equation.c.formatted()) }; LabeledContent("d") { Text(equation.d.formatted()) } } }
    }

    private func resultText(_ r: MaterialPropertyResolution) -> String { guard let value = r.value else { return "—" }; return r.unit.isEmpty ? value.formatted() : "\(value.formatted()) \(r.unit)" }
    private func methodText(_ r: MaterialPropertyResolution) -> String { switch r.method { case .constant: return "Constant"; case .tableExact: return "Tabulated value"; case .linearInterpolation: return "Linear interpolation"; case .equation: return "Equation"; case nil: return "—" } }
    private func rangeText(_ min: Double?, _ max: Double?) -> String { "\(min.map { $0.formatted() } ?? "−∞")–\(max.map { $0.formatted() } ?? "+∞") °C" }
    private func seriesFor(_ p: MaterialPropertyKind, _ m: EngineeringMaterial) -> MaterialPropertySeries? { switch p { case .thermalConductivity: return m.thermalConductivitySeries; case .specificHeatCapacity: return m.specificHeatCapacitySeries; case .thermalExpansion: return m.thermalExpansionSeries; case .youngsModulus: return m.youngsModulusSeries; case .poissonsRatio: return m.poissonsRatioSeries; case .yieldStrength: return m.yieldStrengthSeries; case .ultimateTensileStrength: return m.ultimateTensileStrengthSeries; case .shearModulus: return m.shearModulusSeries; case .electricalResistivity: return m.electricalResistivitySeries; default: return nil } }
}

private struct PropertySeriesChart: View {
    let series: MaterialPropertySeries
    let property: MaterialPropertyKind
    let selectedTemperature: Double?
    let selectedValue: Double?

    private var curve: [InspectorGraphPoint] {
        if !series.temperatureTable.isEmpty {
            return series.temperatureTable
                .sorted { $0.temperatureC < $1.temperatureC }
                .map { InspectorGraphPoint(temperatureC: $0.temperatureC, value: $0.value) }
        }
        guard let equation = series.equation else { return [] }
        let minimum = equation.minimumTemperatureC ?? 0
        let maximum = equation.maximumTemperatureC ?? max(minimum + 100, 300)
        guard maximum > minimum else {
            return [InspectorGraphPoint(temperatureC: minimum, value: equationValue(equation, at: minimum))]
        }
        return (0...80).map { index in
            let t = minimum + (maximum - minimum) * Double(index) / 80.0
            return InspectorGraphPoint(temperatureC: t, value: equationValue(equation, at: t))
        }
    }

    var body: some View {
        Chart {
            ForEach(curve) { point in
                LineMark(
                    x: .value("Temperature", point.temperatureC),
                    y: .value("Property value", point.value)
                )
                .interpolationMethod(.linear)
            }

            ForEach(series.temperatureTable.sorted { $0.temperatureC < $1.temperatureC }) { point in
                PointMark(
                    x: .value("Temperature", point.temperatureC),
                    y: .value("Tabulated value", point.value)
                )
                .symbolSize(45)
            }

            if let t = selectedTemperature, let value = selectedValue {
                RuleMark(x: .value("Selected temperature", t))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)

                PointMark(
                    x: .value("Selected temperature", t),
                    y: .value("Evaluated value", value)
                )
                .symbolSize(100)
                .annotation(position: .top, spacing: 6) {
                    Text(property.unit.isEmpty ? value.formatted() : "\(value.formatted()) \(property.unit)")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
        .chartXAxisLabel("Temperature (°C)")
        .chartYAxisLabel(property.unit.isEmpty ? property.name : "\(property.name) (\(property.unit))")
        .frame(minHeight: 240, idealHeight: 300)
    }

    private func equationValue(_ equation: MaterialPropertyEquation, at temperature: Double) -> Double {
        equation.a
            + equation.b * temperature
            + equation.c * temperature * temperature
            + equation.d * temperature * temperature * temperature
    }
}

private struct InspectorGraphPoint: Identifiable {
    let id = UUID()
    let temperatureC: Double
    let value: Double
}
