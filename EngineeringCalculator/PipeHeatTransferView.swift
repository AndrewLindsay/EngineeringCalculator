import SwiftUI
import Charts

struct PipeHeatTransferView: View {
    @EnvironmentObject private var materialStore: MaterialLibraryStore
    @State private var internalDiameterMM = 300.0
    @State private var insideTemperatureC = 100.0
    @State private var outsideTemperatureC = 20.0
    @State private var lengthM = 1.0
    @State private var editableLayers: [EditableHeatLayer] = []
    @State private var showingAddLayer = false
    @State private var showDetails = false
    @State private var showSolverDetails = false

    struct EditableHeatLayer: Identifiable {
        let id: UUID
        var material: EngineeringMaterial
        var thicknessMM: Double

        init(id: UUID = UUID(), material: EngineeringMaterial, thicknessMM: Double = 10) {
            self.id = id
            self.material = material
            self.thicknessMM = thicknessMM
        }
    }

    private var input: PipeHeatTransferInput {
        .init(
            internalDiameterM: max(0, internalDiameterMM) / 1000,
            layers: editableLayers.map {
                .init(
                    id: $0.id,
                    name: $0.material.name,
                    thicknessM: max(0, $0.thicknessMM) / 1000,
                    material: $0.material
                )
            },
            insideBoundaryTemperatureC: insideTemperatureC,
            outsideBoundaryTemperatureC: outsideTemperatureC,
            lengthM: max(0, lengthM)
        )
    }

    private var validated: ValidatedPipeHeatTransferResult {
        PipeHeatTransferCalculator.validatedCalculate(input: input)
    }

    var body: some View {
        Form {
            Section("Geometry & Boundary Conditions") {
                numericField("Internal diameter (mm)", value: $internalDiameterMM)
                numericField("Inside boundary temperature (°C)", value: $insideTemperatureC)
                numericField("Outside boundary temperature (°C)", value: $outsideTemperatureC)
                numericField("Calculation length (m)", value: $lengthM)
            }
            layersSection
            materialRequirementsSection
            resultsSection
            temperatureProfileSection
            layerResultsSection
            solverSection
            Section {
                DisclosureGroup("Calculation Details", isExpanded: $showDetails) {
                    if let details = CalculationRegistry.definition(id: "pipeHeatTransfer")?.details {
                        CalculationDetailsView(details: details)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pipe Heat Transfer")
        .sheet(isPresented: $showingAddLayer) {
            NavigationStack {
                AddHeatTransferLayerView { material, thickness in
                    editableLayers.append(.init(material: material, thicknessMM: thickness))
                }
                .environmentObject(materialStore)
            }
        }
    }

    private var layersSection: some View {
        Section {
            if editableLayers.isEmpty {
                ContentUnavailableView(
                    "No Layers",
                    systemImage: "square.stack.3d.up.slash",
                    description: Text("Add at least one solid layer to calculate radial heat transfer.")
                )
            } else {
                ForEach(editableLayers.map(\.id), id: \.self) { id in
                    if let layer = binding(for: id) { layerRow(layer) }
                }
            }
            Button { showingAddLayer = true } label: {
                Label("Add Layer", systemImage: "plus.circle")
            }
        } header: {
            Text("Pipe / Insulation Layers")
        } footer: {
            Text("Physical layers are ordered from the internal bore outwards. Temperature-dependent layers are automatically subdivided into computational cells until the conductivity variation and heat-rate solution converge.")
        }
    }

    @ViewBuilder
    private var materialRequirementsSection: some View {
        let validation = validated.validation
        if !validation.canCalculate {
            Section {
                ForEach(validation.layers.filter { !$0.canCalculate }) { layer in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(layer.layerName, systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text("Material: \(layer.materialName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(layer.result.errors) { issue in
                            Text(issue.message).font(.callout)
                        }
                    }
                    .padding(.vertical, 3)
                }
            } header: {
                Text("Material Requirements")
            } footer: {
                Text("Results are blocked until every physical layer has usable thermal conductivity data over the temperatures required by the adaptive solution.")
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        Section("Results") {
            if editableLayers.isEmpty {
                Label("Add at least one layer to calculate heat transfer.", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            } else if let result = validated.result {
                resultRow("Final OD", result.finalOuterDiameterM * 1000, "mm", digits: 2)
                resultRow("Total conduction resistance", result.totalResistanceKPerW, "K/W", digits: 6)
                resultRow("Overall conductance (UA)", 1 / result.totalResistanceKPerW, "W/K", digits: 3)
                if input.lengthM > 0 {
                    let ai = Double.pi * input.internalDiameterM * input.lengthM
                    let ao = Double.pi * result.finalOuterDiameterM * input.lengthM
                    if ai > 0 {
                        resultRow("Overall U — inside area basis", 1 / (result.totalResistanceKPerW * ai), "W/(m²·K)", digits: 3)
                    }
                    if ao > 0 {
                        resultRow("Overall U — outside area basis", 1 / (result.totalResistanceKPerW * ao), "W/(m²·K)", digits: 3)
                    }
                }
                resultRow("Heat rate", result.heatRateW, "W", digits: 3)
                resultRow("Heat rate per length", result.heatRatePerLengthWM, "W/m", digits: 3)
                LabeledContent("Heat-flow direction") {
                    Text(result.heatRateW >= 0 ? "Inside → outside" : "Outside → inside")
                        .fontWeight(.semibold)
                }
            } else if let failure = validated.solverFailure {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Heat-transfer calculation blocked", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                    Text(failure.message).font(.callout)
                }
                .foregroundStyle(.orange)
                .padding(.vertical, 3)
            } else if validated.validation.canCalculate {
                Label("The adaptive solution could not be completed.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Label("Results blocked until material requirements are satisfied.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private struct TemperaturePoint: Identifiable {
        let id: Int
        let diameterMM: Double
        let radialBuildMM: Double
        let temperatureC: Double
        let label: String
    }

    private struct LayerBand: Identifiable {
        let id: UUID
        let name: String
        let innerRadialBuildMM: Double
        let outerRadialBuildMM: Double
    }

    private func temperaturePoints(_ result: PipeHeatTransferResult) -> [TemperaturePoint] {
        guard let first = result.layers.first else { return [] }

        let datumDiameterMM = first.innerRadiusM * 2000

        var points: [TemperaturePoint] = [
            .init(
                id: 0,
                diameterMM: datumDiameterMM,
                radialBuildMM: 0,
                temperatureC: first.innerBoundaryTemperatureC,
                label: "Inside surface"
            )
        ]

        for (i, layer) in result.layers.enumerated() {
            let diameterMM = layer.outerRadiusM * 2000

            points.append(
                .init(
                    id: i + 1,
                    diameterMM: diameterMM,
                    radialBuildMM: (diameterMM - datumDiameterMM) / 2,
                    temperatureC: layer.outerBoundaryTemperatureC,
                    label: i == result.layers.count - 1
                        ? "Outside surface"
                        : "After \(layer.name)"
                )
            )
        }

        return points
    }

    private func layerBands(_ result: PipeHeatTransferResult) -> [LayerBand] {
        guard let first = result.layers.first else { return [] }

        let datumRadiusMM = first.innerRadiusM * 1000

        return result.layers.map {
            .init(
                id: $0.id,
                name: $0.name,
                innerRadialBuildMM: ($0.innerRadiusM * 1000) - datumRadiusMM,
                outerRadialBuildMM: ($0.outerRadiusM * 1000) - datumRadiusMM
            )
        }
    }

    private func temperatureDomain(_ result: PipeHeatTransferResult) -> ClosedRange<Double> {
        let values = temperaturePoints(result).map(\.temperatureC)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let span = max(high - low, 1)
        let padding = max(span * 0.10, 1)
        return (low - padding)...(high + padding)
    }

    private func annotationPosition(
        for point: TemperaturePoint,
        in points: [TemperaturePoint]
    ) -> AnnotationPosition {
        // Keep endpoint labels inside the chart bounds.

        if point.id == points.first?.id {

            return .topTrailing

        }

        if point.id == points.last?.id {

            return .topLeading

        }
        guard let index = points.firstIndex(where: { $0.id == point.id }) else {
            return .top
        }

        let minimumSeparationC = 5.0

        let closeToPrevious: Bool = {
            guard index > 0 else { return false }
            return abs(
                point.temperatureC - points[index - 1].temperatureC
            ) < minimumSeparationC
        }()

        let closeToNext: Bool = {
            guard index < points.count - 1 else { return false }
            return abs(
                point.temperatureC - points[index + 1].temperatureC
            ) < minimumSeparationC
        }()

        if closeToPrevious || closeToNext {
            return index.isMultiple(of: 2) ? .top : .bottom
        }

        return .top
    }
    
    @ViewBuilder
    private var temperatureProfileSection: some View {
        if let result = validated.result {
            let points = temperaturePoints(result)
            let bands = layerBands(result)
            let temperatureDomain = temperatureDomain(result)
            let radialBuildDomain = 0.0...(points.map(\.radialBuildMM).max() ?? 1.0)

            Section {
                Chart {
                    // Physical-layer bands are deliberately based on the engineering
                    // layers, not the adaptive computational cells used by the solver.
                    ForEach(bands) { band in
                        RectangleMark(
                            xStart: .value("Layer start", band.innerRadialBuildMM),
                            xEnd: .value("Layer end", band.outerRadialBuildMM),
                            yStart: .value("Plot minimum", temperatureDomain.lowerBound),
                            yEnd: .value("Plot maximum", temperatureDomain.upperBound)
                        )
                        .foregroundStyle(by: .value("Layer", band.name))
                        .opacity(0.16)
                    }

                    // Mark every physical interface explicitly.
                    ForEach(Array(bands.enumerated()), id: \.element.id) { index, band in
                        if index > 0 {
                            RuleMark(x: .value("Interface", band.innerRadialBuildMM))
                                .foregroundStyle(.secondary.opacity(0.65))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }

                    ForEach(points) { point in
                        LineMark(
                            x: .value("Radial build (mm)", point.radialBuildMM),
                            y: .value("Temperature (°C)", point.temperatureC),
                            series: .value("Profile", "Temperature")
                        )
                        .foregroundStyle(.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Radial build (mm)", point.radialBuildMM),
                            y: .value("Temperature (°C)", point.temperatureC)
                        )
                        .foregroundStyle(.primary)
                        .annotation(
                            position: annotationPosition(for: point, in: points),
                            alignment: .center
                        ) {
                            Text(point.temperatureC.formatted(.number.precision(.fractionLength(1))))
                                .font(.caption2)
                                .monospacedDigit()
                        }
                    }
                }
                .chartXScale(domain: radialBuildDomain)
                .chartYScale(domain: temperatureDomain)
                .chartXAxisLabel("Radial build from internal surface (mm)")
                .chartYAxisLabel("Temperature (°C)")
                .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
                .frame(minHeight: 280)

                ForEach(points) { point in
                    LabeledContent(point.label) {
                        Text(
                            "\(point.diameterMM.formatted(.number.precision(.fractionLength(0...2)))) mm  •  " +
                            "\(point.temperatureC.formatted(.number.precision(.fractionLength(0...2)))) °C"
                        )
                        .monospacedDigit()
                    }
                }
            } header: {
                Text("Interface Temperature Profile")
            } footer: {
                Text(
                    "The horizontal axis shows radial build measured outward from the internal pipe surface. " +
                    "Shaded bands identify the physical pipe or coating layers. Dashed vertical lines mark " +
                    "layer interfaces. Points show the solved interface temperatures; adaptive computational " +
                    "cells are intentionally not shown."
                )
            }
        }
    }

    @ViewBuilder
    private var layerResultsSection: some View {
        if let result = validated.result {
            Section("Physical Layer Results") {
                ScrollView(.horizontal) {
                    Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
                        GridRow {
                            Text("Layer").frame(minWidth: 130, alignment: .leading)
                            Text("ID\n(mm)")
                            Text("OD\n(mm)")
                            Text("T in\n(°C)")
                            Text("T out\n(°C)")
                            Text("k eff\n(W/m·K)")
                            Text("k min\n(W/m·K)")
                            Text("k max\n(W/m·K)")
                            Text("R\n(K/W)")
                            Text("Cells")
                        }
                        .font(.caption2.bold())
                        .multilineTextAlignment(.center)
                        Divider().gridCellColumns(10)
                        ForEach(result.layers) { layer in
                            GridRow {
                                Text(layer.name).frame(minWidth: 130, alignment: .leading)
                                number(layer.innerRadiusM * 2000, digits: 2)
                                number(layer.outerRadiusM * 2000, digits: 2)
                                number(layer.innerBoundaryTemperatureC, digits: 2)
                                number(layer.outerBoundaryTemperatureC, digits: 2)
                                number(layer.thermalConductivityWMK, digits: 5)
                                number(layer.minimumConductivityWMK, digits: 5)
                                number(layer.maximumConductivityWMK, digits: 5)
                                number(layer.resistanceKPerW, digits: 6)
                                Text("\(layer.computationalCellCount)")
                            }
                            .font(.caption2)
                        }
                    }
                    .monospacedDigit()
                    .padding(.vertical, 4)
                }
                Text("k eff is the resistance-weighted conductivity reported for the physical layer. k min/max show the range resolved across its adaptive computational cells.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var solverSection: some View {
        if let result = validated.result {
            Section {
                DisclosureGroup("Adaptive Solver", isExpanded: $showSolverDetails) {
                    LabeledContent("Physical layers", value: "\(result.layers.count)")
                    LabeledContent("Computational cells", value: "\(result.totalComputationalCells)")
                    LabeledContent("Refinement passes", value: "\(result.refinementPasses)")
                    LabeledContent("Maximum k variation per cell") {
                        Text("\((PipeHeatTransferCalculator.maximumRelativeConductivityVariation * 100).formatted(.number.precision(.fractionLength(2)))) %")
                    }
                    LabeledContent("Heat-rate refinement tolerance") {
                        Text(PipeHeatTransferCalculator.heatRateConvergenceTolerance.formatted(.number.notation(.scientific).precision(.significantDigits(2))))
                    }
                    LabeledContent("Last heat-rate change") {
                        Text("\((result.heatRateConvergenceFraction * 100).formatted(.number.precision(.significantDigits(1...4)))) %")
                            .monospacedDigit()
                    }
                    Text("The solver starts with one computational cell per physical layer. Cells are refined automatically where thermal conductivity varies materially over the local temperature span. Constant-property layers normally remain as one cell.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func layerRow(_ layer: Binding<EditableHeatLayer>) -> some View {
        let id = layer.wrappedValue.id
        let calculated = validated.result?.layers.first { $0.id == id }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(layer.wrappedValue.material.name).font(.headline)
                    if let calculated {
                        if calculated.computationalCellCount == 1 {
                            Text("k = \(calculated.thermalConductivityWMK.formatted(.number.precision(.significantDigits(1...5)))) W/(m·K) • T \(calculated.innerBoundaryTemperatureC.formatted(.number.precision(.fractionLength(1)))) → \(calculated.outerBoundaryTemperatureC.formatted(.number.precision(.fractionLength(1)))) °C • 1 cell")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("k = \(calculated.minimumConductivityWMK.formatted(.number.precision(.significantDigits(1...5))))–\(calculated.maximumConductivityWMK.formatted(.number.precision(.significantDigits(1...5)))) W/(m·K) • T \(calculated.innerBoundaryTemperatureC.formatted(.number.precision(.fractionLength(1)))) → \(calculated.outerBoundaryTemperatureC.formatted(.number.precision(.fractionLength(1)))) °C • \(calculated.computationalCellCount) cells")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else if let text = localFailureText(for: layer.wrappedValue.material) {
                        Label(text, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.red)
                    } else if !MaterialPropertyResolver.availableProperties(in: layer.wrappedValue.material).contains(.thermalConductivity) {
                        Label("Thermal conductivity missing", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.red)
                    } else {
                        Text("Thermal conductivity available; adaptive solution pending.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(role: .destructive) { editableLayers.removeAll { $0.id == id } } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            numericField("Thickness (mm)", value: layer.thicknessMM)
            HStack {
                Button { moveLayer(id: id, offset: -1) } label: { Label("Move Up", systemImage: "arrow.up") }
                    .disabled(editableLayers.first?.id == id)
                Button { moveLayer(id: id, offset: 1) } label: { Label("Move Down", systemImage: "arrow.down") }
                    .disabled(editableLayers.last?.id == id)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func localFailureText(for material: EngineeringMaterial) -> String? {
        guard case let .thermalConductivityUnavailable(name, t, status)? = validated.solverFailure,
              name == material.name else { return nil }
        switch status {
        case let .outsideAvailableRange(a, b):
            return "k unavailable at calculated local temperature \(t.formatted(.number.precision(.fractionLength(0...2)))) °C (available \(a.formatted())–\(b.formatted()) °C)"
        case let .outsideEquationRange(a, b):
            let lo = a.map { $0.formatted() } ?? "−∞"
            let hi = b.map { $0.formatted() } ?? "+∞"
            return "k correlation invalid at calculated local temperature \(t.formatted(.number.precision(.fractionLength(0...2)))) °C (valid \(lo)–\(hi) °C)"
        case .missing:
            return "Thermal conductivity missing"
        case .temperatureRequired:
            return "Thermal conductivity requires temperature"
        case .resolved:
            return nil
        }
    }

    private func binding(for id: UUID) -> Binding<EditableHeatLayer>? {
        guard editableLayers.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { editableLayers.first(where: { $0.id == id }) ?? .init(material: EngineeringMaterial(name: "Unavailable")) },
            set: { value in
                if let i = editableLayers.firstIndex(where: { $0.id == id }) { editableLayers[i] = value }
            }
        )
    }

    private func moveLayer(id: UUID, offset: Int) {
        guard let i = editableLayers.firstIndex(where: { $0.id == id }) else { return }
        let d = i + offset
        guard editableLayers.indices.contains(d) else { return }
        editableLayers.swapAt(i, d)
    }

    @ViewBuilder
    private func numericField(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField("", value: value, format: .number.precision(.fractionLength(0...4)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif
                .frame(minWidth: 90)
        }
    }

    private func resultRow(_ title: String, _ value: Double, _ unit: String, digits: Int) -> some View {
        LabeledContent(title) {
            Text("\(value.formatted(.number.precision(.fractionLength(0...digits)))) \(unit)")
                .monospacedDigit()
        }
    }

    private func number(_ value: Double, digits: Int) -> Text {
        Text(value.formatted(.number.precision(.fractionLength(0...digits))))
    }
}

private struct AddHeatTransferLayerView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMaterialID: UUID?
    @State private var thicknessMM = 10.0
    @State private var showingNewMaterial = false
    let onAdd: (EngineeringMaterial, Double) -> Void

    private var selectedMaterial: EngineeringMaterial? {
        store.allMaterials.first { $0.id == selectedMaterialID }
    }

    var body: some View {
        Form {
            Section("Material") {
                Picker("Material", selection: $selectedMaterialID) {
                    Text("Select a material").tag(nil as UUID?)
                    ForEach(store.categories, id: \.self) { category in
                        Section(category) {
                            ForEach(materials(in: category)) { material in
                                Text(material.name).tag(Optional(material.id))
                            }
                        }
                    }
                }
                if let material = selectedMaterial {
                    LabeledContent("Category", value: material.category)
                    LabeledContent("Thermal conductivity") {
                        if MaterialPropertyResolver.availableProperties(in: material).contains(.thermalConductivity) {
                            Text("Available").foregroundStyle(.secondary)
                        } else {
                            Label("Missing — calculation will be blocked", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
                Button { showingNewMaterial = true } label: {
                    Label("Create New Material…", systemImage: "plus")
                }
            }
            Section("Layer") {
                LabeledContent("Thickness (mm)") {
                    TextField("", value: $thicknessMM, format: .number.precision(.fractionLength(0...4)))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .navigationTitle("Add Heat Transfer Layer")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    guard let material = selectedMaterial else { return }
                    onAdd(material, max(0, thicknessMM))
                    dismiss()
                }
                .disabled(selectedMaterial == nil || thicknessMM <= 0)
            }
        }
        .sheet(isPresented: $showingNewMaterial) {
            NavigationStack { MaterialEditorView().environmentObject(store) }
        }
    }

    private func materials(in category: String) -> [EngineeringMaterial] {
        store.allMaterials.filter { $0.category.caseInsensitiveCompare(category) == ComparisonResult.orderedSame }
    }
}
