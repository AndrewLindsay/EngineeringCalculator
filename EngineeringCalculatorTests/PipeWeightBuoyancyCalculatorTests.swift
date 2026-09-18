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

extension PipeWeightBuoyancyCalculatorTests {
    func testSharedPipeConstructionMatchesLegacyInputs() {
        let layers = [
            PipeLayer(name: "Steel", thicknessM: 0.020, densityKgM3: 7850),
            PipeLayer(name: "Coating", thicknessM: 0.003, densityKgM3: 1250)
        ]

        let legacy = PipeWeightBuoyancyCalculator.calculate(
            internalDiameterM: 0.300,
            layers: layers,
            internalFluidDensityKgM3: 1000,
            externalFluidDensityKgM3: 1025
        )

        let construction = PipeConstruction(
            name: "Regression Pipe",
            internalDiameterM: 0.300,
            layers: layers,
            internalFluid: FluidDefinition(name: "Water", densityKgM3: 1000),
            externalFluid: FluidDefinition(name: "Seawater", densityKgM3: 1025)
        )
        let shared = PipeWeightBuoyancyCalculator.calculate(construction: construction)

        XCTAssertEqual(shared.finalOuterDiameterM, legacy.finalOuterDiameterM, accuracy: 1e-12)
        XCTAssertEqual(shared.pipeMassKgPerM, legacy.pipeMassKgPerM, accuracy: 1e-12)
        XCTAssertEqual(shared.contentsMassKgPerM, legacy.contentsMassKgPerM, accuracy: 1e-12)
        XCTAssertEqual(shared.displacedMassKgPerM, legacy.displacedMassKgPerM, accuracy: 1e-12)
        XCTAssertEqual(shared.submergedWeightKNPerM, legacy.submergedWeightKNPerM, accuracy: 1e-12)
    }

    func testPipeConstructionRoundTripsThroughJSON() throws {
        let steel = EngineeringMaterial(
            name: "Carbon Steel",
            category: "Metal",
            densityKgM3: 7850,
            thermalConductivityWMK: 45,
            specificHeatCapacityJkgK: 475,
            source: "Editable engineering default"
        )
        let original = PipeConstruction(
            name: "12-inch Flowline",
            internalDiameterM: 0.300,
            layers: [PipeLayer(name: "Steel Pipe", thicknessM: 0.020, material: steel)],
            internalFluid: FluidDefinition(name: "Process Fluid", densityKgM3: 900, thermalConductivityWMK: 0.12, specificHeatCapacityJkgK: 2200),
            externalFluid: FluidDefinition(name: "Seawater", densityKgM3: 1025, thermalConductivityWMK: 0.60, specificHeatCapacityJkgK: 3990)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PipeConstruction.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
