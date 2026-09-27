import Foundation

/// Stable machine identifier for a calculation input or output.
///
/// Raw values are persistence/chaining contracts. Once a port is referenced by a
/// saved project its identifier must not be renamed merely because UI wording changes.
struct CalculationPortID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "Calculation port identifiers must not be empty")
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

enum CalculationPortDirection: String, Codable, Hashable, Sendable {
    case input
    case output
}

/// Engineering meaning carried by a calculation port.
/// Compatibility is based on quantity, not the display label or display unit.
enum EngineeringQuantity: String, Codable, CaseIterable, Hashable, Sendable {
    case length
    case temperature
    case massPerLength
    case forcePerLength
    case thermalResistance
    case heatRate
    case heatRatePerLength

    var canonicalSIUnit: String {
        switch self {
        case .length: return "m"
        case .temperature: return "K"
        case .massPerLength: return "kg/m"
        case .forcePerLength: return "N/m"
        case .thermalResistance: return "K/W"
        case .heatRate: return "W"
        case .heatRatePerLength: return "W/m"
        }
    }
}

/// A public, stable input/output contract exposed by a calculator.
/// `name` and `displayUnit` are presentation metadata and are deliberately separate
/// from the stable ID and engineering quantity used for persistence and compatibility.
struct CalculationPortDefinition: Identifiable, Hashable, Sendable {
    let id: CalculationPortID
    let direction: CalculationPortDirection
    let quantity: EngineeringQuantity
    let name: String
    let displayUnit: String

    init(
        id: CalculationPortID,
        direction: CalculationPortDirection,
        quantity: EngineeringQuantity,
        name: String,
        displayUnit: String
    ) {
        self.id = id
        self.direction = direction
        self.quantity = quantity
        self.name = name
        self.displayUnit = displayUnit
    }

    func isCompatible(with other: CalculationPortDefinition) -> Bool {
        direction != other.direction && quantity == other.quantity
    }
}

enum StandardCalculationPorts {
    enum PipeWeightBuoyancy {
        static let internalDiameter: CalculationPortID = "input.internalDiameter"
        static let finalOuterDiameter: CalculationPortID = "output.finalOuterDiameter"
        static let pipeMassPerLength: CalculationPortID = "output.pipeMassPerLength"
        static let pipeWeightPerLength: CalculationPortID = "output.pipeWeightPerLength"
        static let contentsMassPerLength: CalculationPortID = "output.contentsMassPerLength"
        static let displacedMassPerLength: CalculationPortID = "output.displacedMassPerLength"
        static let submergedEquivalentMassPerLength: CalculationPortID = "output.submergedEquivalentMassPerLength"
        static let submergedWeightPerLength: CalculationPortID = "output.submergedWeightPerLength"
    }

    enum PipeHeatTransfer {
        static let internalDiameter: CalculationPortID = "input.internalDiameter"
        static let insideBoundaryTemperature: CalculationPortID = "input.insideBoundaryTemperature"
        static let outsideBoundaryTemperature: CalculationPortID = "input.outsideBoundaryTemperature"
        static let length: CalculationPortID = "input.length"
        static let finalOuterDiameter: CalculationPortID = "output.finalOuterDiameter"
        static let totalThermalResistance: CalculationPortID = "output.totalThermalResistance"
        static let heatRate: CalculationPortID = "output.heatRate"
        static let heatRatePerLength: CalculationPortID = "output.heatRatePerLength"
    }
}
