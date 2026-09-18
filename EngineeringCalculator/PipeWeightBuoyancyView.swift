import SwiftUI

struct PipeWeightBuoyancyView: View {
    @State private var diameterMode: DiameterMode = .diameter
    @State private var insideValueMM = 300.0
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
        let id = UUID()
        var name = "Coating"
        var thicknessMM = 3.0
        var density = 1250.0
    }

    private var internalDiameterM: Double {
        let metres = max(0, insideValueMM) / 1000.0
        return diameterMode == .diameter ? metres : 2.0 * metres
    }

    private var layers: [PipeLayer] {
        var output = [
            PipeLayer(
                name: "Pipe wall",
                thicknessM: max(0, wallThicknessMM) / 1000.0,
                densityKgM3: max(0, pipeDensity)
            )
        ]
        output += extraLayers.map {
            PipeLayer(
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
                numericField("Pipe wall thickness (mm)", value: $wallThicknessMM)
                numericField("Pipe density (kg/m³)", value: $pipeDensity)
            }

            Section("Additional Layers") {
                ForEach($extraLayers) { $layer in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Layer name", text: $layer.name)
                        numericField("Thickness (mm)", value: $layer.thicknessMM)
                        numericField("Density (kg/m³)", value: $layer.density)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { extraLayers.remove(atOffsets: $0) }

                Button {
                    extraLayers.append(EditableLayer())
                } label: {
                    Label("Add Layer", systemImage: "plus.circle")
                }
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
                    Text("Dry pipe mass is the sum of each concentric solid layer. Internal contents are excluded from the dry pipe result.")
                    Text("Buoyancy uses the displaced external-fluid volume based on the final outside diameter.")
                    Text("Net submerged weight = (pipe mass + contents mass − displaced external-fluid mass) × g.")
                    Text("g = 9.80665 m/s²")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pipe Weight & Buoyancy")
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
}
