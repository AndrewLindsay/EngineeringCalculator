import XCTest
@testable import EngineeringCalculator

final class PipeWeightBuoyancyCalculatorTests: XCTestCase {
    func testBareSteelPipe() {
        let result = PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: 0.300,
            layers: [
                PipeLayer(name: "Steel", thicknessM: 0.020, densityKgM3: 7850)
            ],
            internalFluidDensityKgM3: 1000,
            externalFluidDensityKgM3: 1025
        )

        XCTAssertEqual(result.finalOuterDiameterM, 0.340, accuracy: 1e-12)
        XCTAssertEqual(result.layers.count, 1)
        XCTAssertEqual(result.layers[0].innerDiameterM, 0.300, accuracy: 1e-12)
        XCTAssertEqual(result.layers[0].outerDiameterM, 0.340, accuracy: 1e-12)
        XCTAssertGreaterThan(result.pipeMassKgPerM, 0)
    }

    func testCalculatedLayerStackIsContinuous() {
        let result = PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: 0.300,
            layers: [
                PipeLayer(name: "Steel", thicknessM: 0.020, densityKgM3: 7850),
                PipeLayer(name: "Coating", thicknessM: 0.003, densityKgM3: 1250),
                PipeLayer(name: "Concrete", thicknessM: 0.050, densityKgM3: 3040)
            ],
            internalFluidDensityKgM3: 1000,
            externalFluidDensityKgM3: 1025
        )

        XCTAssertEqual(result.layers.count, 3)
        XCTAssertEqual(result.layers[0].outerDiameterM, result.layers[1].innerDiameterM, accuracy: 1e-12)
        XCTAssertEqual(result.layers[1].outerDiameterM, result.layers[2].innerDiameterM, accuracy: 1e-12)
        XCTAssertEqual(result.finalOuterDiameterM, 0.446, accuracy: 1e-12)
    }

    func testPipeMassEqualsSumOfLayerMasses() {
        let result = PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: 0.250,
            layers: [
                PipeLayer(name: "Steel", thicknessM: 0.015, densityKgM3: 7850),
                PipeLayer(name: "Coating", thicknessM: 0.004, densityKgM3: 1200)
            ],
            internalFluidDensityKgM3: 900,
            externalFluidDensityKgM3: 1025
        )

        let sum = result.layers.reduce(0) { $0 + $1.massKgPerM }
        XCTAssertEqual(result.pipeMassKgPerM, sum, accuracy: 1e-12)
    }

    func testReorderingDifferentDensityLayersChangesMassDistributionButNotFinalOD() {
        let a = PipeLayer(name: "A", thicknessM: 0.010, densityKgM3: 1000)
        let b = PipeLayer(name: "B", thicknessM: 0.020, densityKgM3: 3000)

        let first = PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: 0.300,
            layers: [a, b],
            internalFluidDensityKgM3: 0,
            externalFluidDensityKgM3: 1025
        )
        let second = PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: 0.300,
            layers: [b, a],
            internalFluidDensityKgM3: 0,
            externalFluidDensityKgM3: 1025
        )

        XCTAssertEqual(first.finalOuterDiameterM, second.finalOuterDiameterM, accuracy: 1e-12)
        XCTAssertNotEqual(first.pipeMassKgPerM, second.pipeMassKgPerM)
    }
}
