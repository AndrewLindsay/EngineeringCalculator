import XCTest
@testable import EngineeringCalculator

final class PipeHeatTransferCalculatorTests: XCTestCase {
    private let k10 = EngineeringMaterial(name: "TEST k=10", category: "Validation", thermalConductivityWMK: 10)
    private let k20 = EngineeringMaterial(name: "TEST k=20", category: "Validation", thermalConductivityWMK: 20)
    private let densityOnly = EngineeringMaterial(name: "TEST Missing k", category: "Validation", densityKgM3: 1000)

    private var tabulated: EngineeringMaterial {
        EngineeringMaterial(
            name: "TEST Table k",
            category: "Validation",
            thermalConductivitySeries: MaterialPropertySeries(temperatureTable: [
                .init(temperatureC: 0, value: 10),
                .init(temperatureC: 50, value: 15),
                .init(temperatureC: 100, value: 20)
            ])
        )
    }

    private func input(layers: [PipeHeatTransferLayer], inside: Double = 100, outside: Double = 0, length: Double = 1) -> PipeHeatTransferInput {
        PipeHeatTransferInput(internalDiameterM: 0.300, layers: layers, insideBoundaryTemperatureC: inside, outsideBoundaryTemperatureC: outside, lengthM: length)
    }

    func testSingleLayerConstantKMatchesAnalyticalResistance() throws {
        let model = input(layers: [.init(thicknessM: 0.020, material: k10)])
        let result = try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input: model).result)
        let expectedR = log(0.170 / 0.150) / (2 * Double.pi * 10)
        XCTAssertEqual(result.totalResistanceKPerW, expectedR, accuracy: 1e-12)
        XCTAssertEqual(result.heatRateW, 100 / expectedR, accuracy: 1e-9)
        XCTAssertEqual(result.finalOuterDiameterM, 0.340, accuracy: 1e-12)
    }

    func testTwoLayerResistanceIsSumOfCylindricalResistances() throws {
        let model = input(layers: [.init(thicknessM: 0.010, material: k10), .init(thicknessM: 0.020, material: k20)])
        let result = try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input: model).result)
        let r1 = log(0.160 / 0.150) / (2 * Double.pi * 10)
        let r2 = log(0.180 / 0.160) / (2 * Double.pi * 20)
        XCTAssertEqual(result.totalResistanceKPerW, r1 + r2, accuracy: 1e-12)
        XCTAssertEqual(result.heatRateW, 100 / (r1 + r2), accuracy: 1e-9)
    }

    func testMissingConductivityBlocksCalculation() {
        let model = input(layers: [.init(name: "Insulation", thicknessM: 0.020, material: densityOnly)])
        let validated = PipeHeatTransferCalculator.validatedCalculate(input: model)
        XCTAssertFalse(validated.canCalculate)
        XCTAssertNil(validated.result)
        XCTAssertEqual(validated.validation.errors.first?.property, .thermalConductivity)
        XCTAssertEqual(validated.validation.layers.first?.layerName, "Insulation")
    }

    func testDensityIsNotRequiredForHeatConduction() {
        let model = input(layers: [.init(thicknessM: 0.020, material: k10)])
        XCTAssertTrue(PipeHeatTransferCalculator.validatedCalculate(input: model).canCalculate)
    }

    func testTabulatedConductivityInterpolatesAtMeanBoundaryTemperature() throws {
        let model = input(layers: [.init(thicknessM: 0.020, material: tabulated)], inside: 100, outside: 0)
        let result = try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input: model).result)
        XCTAssertEqual(result.layers[0].evaluationTemperatureC, 50, accuracy: 1e-12)
        XCTAssertEqual(result.layers[0].thermalConductivityWMK, 15, accuracy: 1e-12)
        XCTAssertEqual(result.layers[0].conductivityMethod, .tableExact)
    }

    func testTabulatedConductivityLinearInterpolation() throws {
        let model = input(layers: [.init(thicknessM: 0.020, material: tabulated)], inside: 50, outside: 0)
        let result = try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input: model).result)
        XCTAssertEqual(result.layers[0].evaluationTemperatureC, 25, accuracy: 1e-12)
        XCTAssertEqual(result.layers[0].thermalConductivityWMK, 12.5, accuracy: 1e-12)
        XCTAssertEqual(result.layers[0].conductivityMethod, .linearInterpolation)
    }

    func testOutOfRangeTabulatedConductivityBlocksCalculation() {
        let model = input(layers: [.init(thicknessM: 0.020, material: tabulated)], inside: 300, outside: 0)
        let validated = PipeHeatTransferCalculator.validatedCalculate(input: model)
        XCTAssertFalse(validated.canCalculate)
        XCTAssertNil(validated.result)
        XCTAssertEqual(validated.validation.errors.first?.reason, .outsideAvailableRange(minimumC: 0, maximumC: 100))
    }

    func testLayerTemperatureDropsSumToSpecifiedBoundaryDifference() throws {
        let model = input(layers: [.init(thicknessM: 0.010, material: k10), .init(thicknessM: 0.020, material: k20)], inside: 120, outside: 20)
        let result = try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input: model).result)
        XCTAssertEqual(result.layers.reduce(0) { $0 + $1.temperatureDropC }, 100, accuracy: 1e-9)
        XCTAssertEqual(result.layers.last?.outerBoundaryTemperatureC ?? .nan, 20, accuracy: 1e-9)
    }

    func testHeatRateScalesWithLengthButHeatRatePerLengthDoesNot() throws {
        let one = try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input: input(layers: [.init(thicknessM: 0.020, material: k10)], length: 1)).result)
        let five = try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input: input(layers: [.init(thicknessM: 0.020, material: k10)], length: 5)).result)
        XCTAssertEqual(five.heatRateW, one.heatRateW * 5, accuracy: 1e-8)
        XCTAssertEqual(five.heatRatePerLengthWM, one.heatRatePerLengthWM, accuracy: 1e-8)
    }
}
