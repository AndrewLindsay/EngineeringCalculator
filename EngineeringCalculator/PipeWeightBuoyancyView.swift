import SwiftUI

struct PipeWeightBuoyancyView: View {
    @State private var diameterMode: DiameterMode = .diameter
    @State private var insideValueMM = 300.0
    @State private var wallName = "Steel Pipe"
    @State private var wallThicknessMM = 20.0
    @State private var pipeDensity = 7850.0
    @State private var internalDensity = 1000.0
    @State private var externalDensity = 1025.0
    @State private var extraLayers: [EditableLayer] = []
    @State private var showDetails = false

    enum DiameterMode: String, CaseIterable, Identifiable {
        case diameter = "Internal Diameter"
        case radius = "Internal Radius"
        var id: String { rawValue }
    }

    struct EditableLayer: Identifiable {
        let id: UUID
        var name: String
        var thicknessMM: Double
        var density: Double

        init(
            id: UUID = UUID(),
            name: String = "Coating",
            thicknessMM: Double = 3.0,
            density: Double = 1250.0
        ) {
            self.id = id
            self.name = name
            self.thicknessMM = thicknessMM
            self.density = density
        }
    }

    private var internalDiameterM: Double {
        let metres = max(0, insideValueMM) / 1000.0
        return diameterMode == .diameter ? metres : 2.0 * metres
    }

    private var layers: [PipeLayer] {
        var output = [
            PipeLayer(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: wallName,
                thicknessM: max(0, wallThicknessMM) / 1000.0,
                densityKgM3: max(0, pipeDensity)
            )
        ]

        output += extraLayers.map {
            PipeLayer(
                id: $0.id,
                name: $0.name,
                thicknessM: max(0, $0.thicknessMM) / 1000.0,
                densityKgM3: max(0, $0.density)
            )
        }
        return output
    }

    private var result: PipeWeightBuoyancyResult {
        PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: internalDiameterM,
            layers: layers,
            internalFluidDensityKgM3: internalDensity,
            externalFluidDensityKgM3: externalDensity
        )
    }

    var body: some View {
        Form {
            Section("Pipe Geometry") {
                Picker("Inside dimension", selection: $diameterMode) {
                    ForEach(DiameterMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                numericField(diameterMode.rawValue + " (mm)", value: $insideValueMM)
                TextField("Pipe layer name", text: $wallName)
                numericField("Pipe wall thickness (mm)", value: $wallThicknessMM)
                numericField("Pipe density (kg/m³)", value: $pipeDensity)
            }

            Section {
                ForEach($extraLayers) { $layer in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Layer name", text: $layer.name)
                                .font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                deleteLayer(id: layer.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete this layer")
                        }

                        numericField("Thickness (mm)", value: $layer.thicknessMM)
                        numericField("Density (kg/m³)", value: $layer.density)

                        HStack {
                            Button {
                                moveLayer(id: layer.id, offset: -1)
                            } label: {
                                Label("Move Up", systemImage: "arrow.up")
                            }
                            .disabled(isFirst(layer.id))

                            Button {
                                moveLayer(id: layer.id, offset: 1)
                            } label: {
                                Label("Move Down", systemImage: "arrow.down")
                            }
                            .disabled(isLast(layer.id))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 5)
                }

                Button {
                    extraLayers.append(EditableLayer())
                } label: {
                    Label("Add Layer", systemImage: "plus.circle")
                }
            } header: {
                Text("Additional Layers")
            } footer: {
                Text("Layers are calculated from inside to outside. Use Move Up/Down to change the physical layer order, or the trash button to delete a layer.")
            }

            Section("Layer Stack Used in Calculation") {
                layerTable
            }

            Section("Fluids") {
                numericField("Internal fluid density (kg/m³)", value: $internalDensity)
                numericField("External fluid density (kg/m³)", value: $externalDensity)
            }

            Section("Results") {
                resultRow("Final OD", result.finalOuterDiameterM * 1000, "mm")
                resultRow("Dry pipe mass", result.pipeMassKgPerM, "kg/m")
                resultRow("Dry pipe weight", result.pipeWeightKNPerM, "kN/m")
                resultRow("Internal contents", result.contentsMassKgPerM, "kg/m")
                resultRow("Displaced external fluid", result.displacedMassKgPerM, "kg/m")
                resultRow("Submerged equivalent mass", result.submergedEquivalentMassKgPerM, "kg/m")
                resultRow("Submerged weight", result.submergedWeightKNPerM, "kN/m")

                LabeledContent("Condition") {
                    Text(result.submergedWeightKNPerM < 0 ? "Buoyant" : "Sinks")
                        .fontWeight(.semibold)
                }
            }

            Section {
                DisclosureGroup("Calculation Details", isExpanded: $showDetails) {
                    if let details = CalculationRegistry.definition(id: "pipeWeightBuoyancy")?.details {
                        CalculationDetailsView(details: details)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pipe Weight & Buoyancy")
    }

    private var layerTable: some View {
        ScrollView(.horizontal) {
            Grid(
                alignment: .trailing,
                horizontalSpacing: 10,
                verticalSpacing: 5
            ) {
                GridRow {
                    Text("#")
                    Text("Layer")
                        .frame(minWidth: 90, alignment: .leading)
                    Text("ID\n(mm)")
                    Text("t\n(mm)")
                    Text("OD\n(mm)")
                    Text("Density\n(kg/m³)")
                    Text("Area\n(m²)")
                    Text("Mass\n(kg/m)")
                }
                .font(.caption2.bold())
                .multilineTextAlignment(.center)

                Divider()
                    .gridCellColumns(8)

                ForEach(
                    Array(result.layers.enumerated()),
                    id: \.element.id
                ) { index, layer in
                    GridRow {
                        Text("\(index + 1)")

                        Text(layer.name)
                            .frame(minWidth: 90, alignment: .leading)

                        tableNumber(
                            layer.innerDiameterM * 1000,
                            digits: 2
                        )

                        tableNumber(
                            layer.thicknessM * 1000,
                            digits: 2
                        )

                        tableNumber(
                            layer.outerDiameterM * 1000,
                            digits: 2
                        )

                        tableNumber(
                            layer.densityKgM3,
                            digits: 0
                        )

                        tableNumber(
                            layer.areaM2,
                            digits: 5
                        )

                        tableNumber(
                            layer.massKgPerM,
                            digits: 2
                        )
                    }
                    .font(.caption2)
                }

                Divider()
                    .gridCellColumns(8)

                GridRow {
                    Text("")

                    Text("TOTAL")
                        .fontWeight(.semibold)
                        .frame(minWidth: 90, alignment: .leading)

                    Text("")
                    Text("")

                    tableNumber(
                        result.finalOuterDiameterM * 1000,
                        digits: 2
                    )

                    Text("")
                    Text("")

                    tableNumber(
                        result.pipeMassKgPerM,
                        digits: 2
                    )
                    .fontWeight(.semibold)
                }
                .font(.caption2)
            }
            .monospacedDigit()
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func numericField(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField(title, value: value, format: .number.precision(.fractionLength(0...4)))
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .frame(minWidth: 90)
        }
    }

    private func resultRow(_ title: String, _ value: Double, _ unit: String) -> some View {
        LabeledContent(title) {
            Text("\(value, format: .number.precision(.fractionLength(3))) \(unit)")
                .monospacedDigit()
        }
    }

    private func tableNumber(_ value: Double, digits: Int) -> Text {
        Text(value.formatted(.number.precision(.fractionLength(digits))))
    }

    private func deleteLayer(id: UUID) {
        extraLayers.removeAll { $0.id == id }
    }

    private func isFirst(_ id: UUID) -> Bool {
        extraLayers.first?.id == id
    }

    private func isLast(_ id: UUID) -> Bool {
        extraLayers.last?.id == id
    }

    private func moveLayer(id: UUID, offset: Int) {
        guard let current = extraLayers.firstIndex(where: { $0.id == id }) else { return }
        let destination = current + offset
        guard extraLayers.indices.contains(destination) else { return }
        extraLayers.swapAt(current, destination)
    }
}
