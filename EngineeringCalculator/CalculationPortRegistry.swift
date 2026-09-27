import Foundation

/// Stable chaining contracts for calculators that opt into project parameters/chaining.
///
/// These contracts deliberately live outside CalculationDetails so equation/variable IDs
/// remain free to serve presentation and documentation without becoming persistence keys.
enum CalculationPortRegistry {
    static let pipeWeightBuoyancy: [CalculationPortDefinition] = [
        .init(id: StandardCalculationPorts.PipeWeightBuoyancy.internalDiameter, direction: .input, quantity: .length, name: "Internal Diameter", displayUnit: "m"),
        .init(id: StandardCalculationPorts.PipeWeightBuoyancy.finalOuterDiameter, direction: .output, quantity: .length, name: "Final Outside Diameter", displayUnit: "m"),
        .init(id: StandardCalculationPorts.PipeWeightBuoyancy.pipeMassPerLength, direction: .output, quantity: .massPerLength, name: "Dry Pipe Mass", displayUnit: "kg/m"),
        .init(id: StandardCalculationPorts.PipeWeightBuoyancy.pipeWeightPerLength, direction: .output, quantity: .forcePerLength, name: "Dry Pipe Weight", displayUnit: "kN/m"),
        .init(id: StandardCalculationPorts.PipeWeightBuoyancy.contentsMassPerLength, direction: .output, quantity: .massPerLength, name: "Contents Mass", displayUnit: "kg/m"),
        .init(id: StandardCalculationPorts.PipeWeightBuoyancy.displacedMassPerLength, direction: .output, quantity: .massPerLength, name: "Displaced Fluid Mass", displayUnit: "kg/m"),
        .init(id: StandardCalculationPorts.PipeWeightBuoyancy.submergedEquivalentMassPerLength, direction: .output, quantity: .massPerLength, name: "Submerged Equivalent Mass", displayUnit: "kg/m"),
        .init(id: StandardCalculationPorts.PipeWeightBuoyancy.submergedWeightPerLength, direction: .output, quantity: .forcePerLength, name: "Submerged Weight", displayUnit: "kN/m")
    ]

    static let pipeHeatTransfer: [CalculationPortDefinition] = [
        .init(id: StandardCalculationPorts.PipeHeatTransfer.internalDiameter, direction: .input, quantity: .length, name: "Internal Diameter", displayUnit: "m"),
        .init(id: StandardCalculationPorts.PipeHeatTransfer.insideBoundaryTemperature, direction: .input, quantity: .temperature, name: "Inside Boundary Temperature", displayUnit: "°C"),
        .init(id: StandardCalculationPorts.PipeHeatTransfer.outsideBoundaryTemperature, direction: .input, quantity: .temperature, name: "Outside Boundary Temperature", displayUnit: "°C"),
        .init(id: StandardCalculationPorts.PipeHeatTransfer.length, direction: .input, quantity: .length, name: "Calculation Length", displayUnit: "m"),
        .init(id: StandardCalculationPorts.PipeHeatTransfer.finalOuterDiameter, direction: .output, quantity: .length, name: "Final Outside Diameter", displayUnit: "m"),
        .init(id: StandardCalculationPorts.PipeHeatTransfer.totalThermalResistance, direction: .output, quantity: .thermalResistance, name: "Total Thermal Resistance", displayUnit: "K/W"),
        .init(id: StandardCalculationPorts.PipeHeatTransfer.heatRate, direction: .output, quantity: .heatRate, name: "Heat-transfer Rate", displayUnit: "W"),
        .init(id: StandardCalculationPorts.PipeHeatTransfer.heatRatePerLength, direction: .output, quantity: .heatRatePerLength, name: "Heat-transfer Rate per Length", displayUnit: "W/m")
    ]

    static func ports(for calculationID: String) -> [CalculationPortDefinition] {
        switch calculationID {
        case "pipeWeightBuoyancy": return pipeWeightBuoyancy
        case "pipeHeatTransfer": return pipeHeatTransfer
        default: return []
        }
    }

    static func port(calculationID: String, id: CalculationPortID) -> CalculationPortDefinition? {
        ports(for: calculationID).first { $0.id == id }
    }
}
