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
        XCTAssertGreaterThan(result.pipeMassKgPerM, 0)
        XCTAssertGreaterThan(result.displacedMassKgPerM, 0)
    }

    func testAddedCoatingIncreasesODAndPipeMass() {
        let bare = PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: 0.300,
            layers: [PipeLayer(name: "Steel", thicknessM: 0.020, densityKgM3: 7850)],
            internalFluidDensityKgM3: 0,
            externalFluidDensityKgM3: 1025
        )

        let coated = PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: 0.300,
            layers: [
                PipeLayer(name: "Steel", thicknessM: 0.020, densityKgM3: 7850),
                PipeLayer(name: "Coating", thicknessM: 0.050, densityKgM3: 3000)
            ],
            internalFluidDensityKgM3: 0,
            externalFluidDensityKgM3: 1025
        )

        XCTAssertGreaterThan(coated.finalOuterDiameterM, bare.finalOuterDiameterM)
        XCTAssertGreaterThan(coated.pipeMassKgPerM, bare.pipeMassKgPerM)
    }
}
