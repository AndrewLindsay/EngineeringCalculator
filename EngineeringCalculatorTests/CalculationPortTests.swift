import XCTest
@testable import EngineeringCalculator

final class CalculationPortTests: XCTestCase {
    func testStablePortRawValuesAreExplicitContracts() {
        XCTAssertEqual(StandardCalculationPorts.PipeWeightBuoyancy.internalDiameter.rawValue, "input.internalDiameter")
        XCTAssertEqual(StandardCalculationPorts.PipeWeightBuoyancy.finalOuterDiameter.rawValue, "output.finalOuterDiameter")
        XCTAssertEqual(StandardCalculationPorts.PipeHeatTransfer.insideBoundaryTemperature.rawValue, "input.insideBoundaryTemperature")
        XCTAssertEqual(StandardCalculationPorts.PipeHeatTransfer.heatRatePerLength.rawValue, "output.heatRatePerLength")
    }

    func testPortIDsAreUniqueWithinEachCalculator() {
        for calculationID in ["pipeWeightBuoyancy", "pipeHeatTransfer"] {
            let ports = CalculationPortRegistry.ports(for: calculationID)
            XCTAssertFalse(ports.isEmpty)
            XCTAssertEqual(Set(ports.map(\.id)).count, ports.count, "Duplicate port ID in \(calculationID)")
        }
    }

    func testPortIdentifierPrefixMatchesDirection() {
        for calculationID in ["pipeWeightBuoyancy", "pipeHeatTransfer"] {
            for port in CalculationPortRegistry.ports(for: calculationID) {
                switch port.direction {
                case .input:
                    XCTAssertTrue(port.id.rawValue.hasPrefix("input."), "\(port.id.rawValue) must retain its input prefix")
                case .output:
                    XCTAssertTrue(port.id.rawValue.hasPrefix("output."), "\(port.id.rawValue) must retain its output prefix")
                }
            }
        }
    }

    func testUnknownCalculatorHasNoPorts() {
        XCTAssertTrue(CalculationPortRegistry.ports(for: "placeholder").isEmpty)
        XCTAssertTrue(CalculationPortRegistry.ports(for: "unknown").isEmpty)
    }

    func testKnownPortCanBeResolvedByStableIdentifier() {
        let port = CalculationPortRegistry.port(
            calculationID: "pipeHeatTransfer",
            id: StandardCalculationPorts.PipeHeatTransfer.heatRate
        )
        XCTAssertEqual(port?.direction, .output)
        XCTAssertEqual(port?.quantity, .heatRate)
        XCTAssertEqual(port?.displayUnit, "W")
    }

    func testCompatibilityUsesEngineeringQuantityNotDisplayText() {
        let weightOD = CalculationPortRegistry.port(
            calculationID: "pipeWeightBuoyancy",
            id: StandardCalculationPorts.PipeWeightBuoyancy.finalOuterDiameter
        )!
        let heatID = CalculationPortRegistry.port(
            calculationID: "pipeHeatTransfer",
            id: StandardCalculationPorts.PipeHeatTransfer.internalDiameter
        )!
        XCTAssertTrue(weightOD.isCompatible(with: heatID))

        let heatRate = CalculationPortRegistry.port(
            calculationID: "pipeHeatTransfer",
            id: StandardCalculationPorts.PipeHeatTransfer.heatRate
        )!
        XCTAssertFalse(heatRate.isCompatible(with: heatID))
    }

    func testSameDirectionPortsAreNotLinkCompatible() {
        let weightOD = CalculationPortRegistry.port(
            calculationID: "pipeWeightBuoyancy",
            id: StandardCalculationPorts.PipeWeightBuoyancy.finalOuterDiameter
        )!
        let heatOD = CalculationPortRegistry.port(
            calculationID: "pipeHeatTransfer",
            id: StandardCalculationPorts.PipeHeatTransfer.finalOuterDiameter
        )!
        XCTAssertEqual(weightOD.quantity, heatOD.quantity)
        XCTAssertFalse(weightOD.isCompatible(with: heatOD))
    }

    func testEngineeringQuantitiesHaveCanonicalSIUnits() {
        XCTAssertEqual(EngineeringQuantity.length.canonicalSIUnit, "m")
        XCTAssertEqual(EngineeringQuantity.temperature.canonicalSIUnit, "K")
        XCTAssertEqual(EngineeringQuantity.massPerLength.canonicalSIUnit, "kg/m")
        XCTAssertEqual(EngineeringQuantity.forcePerLength.canonicalSIUnit, "N/m")
        XCTAssertEqual(EngineeringQuantity.thermalResistance.canonicalSIUnit, "K/W")
        XCTAssertEqual(EngineeringQuantity.heatRate.canonicalSIUnit, "W")
        XCTAssertEqual(EngineeringQuantity.heatRatePerLength.canonicalSIUnit, "W/m")
    }
}
