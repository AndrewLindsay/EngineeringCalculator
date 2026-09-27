import XCTest
@testable import EngineeringCalculator

final class PipeWeightMaterialValidationTests: XCTestCase {
    private let valid1000 = EngineeringMaterial(name: "TEST - Pipe Layer 1000", category: "Validation", densityKgM3: 1000)
    private let valid3000 = EngineeringMaterial(name: "TEST - Pipe Layer 3000", category: "Validation", densityKgM3: 3000)
    private let missingDensity = EngineeringMaterial(name: "TEST - Missing Density", category: "Validation", thermalConductivityWMK: 45, specificHeatCapacityJkgK: 475)
    private let missingK = EngineeringMaterial(name: "TEST - Missing Thermal Conductivity", category: "Validation", densityKgM3: 1200, specificHeatCapacityJkgK: 1800)
    private let missingCp = EngineeringMaterial(name: "TEST - Missing Heat Capacity", category: "Validation", densityKgM3: 1100, thermalConductivityWMK: 0.25)

    private func construction(_ materials: [(String, Double, EngineeringMaterial)]) -> PipeConstruction {
        PipeConstruction(
            name: "Validation Pipe",
            internalDiameterM: 0.300,
            layers: materials.map { PipeLayer(name: $0.0, thicknessM: $0.1, material: $0.2) },
            internalFluid: FluidDefinition(name: "Water", densityKgM3: 1000),
            externalFluid: FluidDefinition(name: "Seawater", densityKgM3: 1025)
        )
    }

    func testValidSingleLayerPassesDensityValidation() {
        let c = construction([("Pipe", 0.020, valid1000)])
        let validation = PipeWeightBuoyancyCalculator.validateMaterials(construction: c)
        XCTAssertTrue(validation.canCalculate)
        XCTAssertTrue(validation.errors.isEmpty)
    }

    func testValidMultilayerConstructionPasses() {
        let c = construction([("Pipe", 0.020, valid1000), ("Outer Layer", 0.010, valid3000)])
        let validated = PipeWeightBuoyancyCalculator.validatedCalculate(construction: c)
        XCTAssertTrue(validated.canCalculate)
        XCTAssertNotNil(validated.result)
        XCTAssertEqual(validated.result?.layers.count, 2)
    }

    func testMissingPipeDensityFailsAndReportsDensity() {
        let c = construction([("Pipe", 0.020, missingDensity)])
        let validated = PipeWeightBuoyancyCalculator.validatedCalculate(construction: c)
        XCTAssertFalse(validated.canCalculate)
        XCTAssertNil(validated.result)
        XCTAssertEqual(validated.validation.errors.count, 1)
        XCTAssertEqual(validated.validation.errors.first?.property, .density)
        XCTAssertEqual(validated.validation.layers.first?.layerName, "Pipe")
    }

    func testMissingAdditionalLayerDensityIdentifiesLayer() {
        let c = construction([("Pipe", 0.020, valid1000), ("Invalid Coating", 0.005, missingDensity)])
        let validation = PipeWeightBuoyancyCalculator.validateMaterials(construction: c)
        XCTAssertFalse(validation.canCalculate)
        XCTAssertEqual(validation.errors.count, 1)
        let failed = validation.layers.filter { !$0.canCalculate }
        XCTAssertEqual(failed.count, 1)
        XCTAssertEqual(failed.first?.layerName, "Invalid Coating")
        XCTAssertEqual(failed.first?.materialName, "TEST - Missing Density")
    }

    func testMultipleInvalidLayersProduceMultipleErrors() {
        let c = construction([("Invalid Pipe", 0.020, missingDensity), ("Invalid Layer", 0.005, missingDensity)])
        let validation = PipeWeightBuoyancyCalculator.validateMaterials(construction: c)
        XCTAssertFalse(validation.canCalculate)
        XCTAssertEqual(validation.errors.count, 2)
        XCTAssertEqual(validation.layers.filter { !$0.canCalculate }.count, 2)
        XCTAssertTrue(validation.errors.allSatisfy { $0.property == .density })
    }

    func testMissingThermalConductivityDoesNotBlockPipeWeight() {
        let c = construction([("Pipe", 0.020, missingK)])
        let validated = PipeWeightBuoyancyCalculator.validatedCalculate(construction: c)
        XCTAssertTrue(validated.canCalculate)
        XCTAssertNotNil(validated.result)
    }

    func testMissingHeatCapacityDoesNotBlockPipeWeight() {
        let c = construction([("Pipe", 0.020, missingCp)])
        let validated = PipeWeightBuoyancyCalculator.validatedCalculate(construction: c)
        XCTAssertTrue(validated.canCalculate)
        XCTAssertNotNil(validated.result)
    }

    func testReplacingInvalidMaterialRestoresCalculation() {
        let invalid = construction([("Pipe", 0.020, missingDensity)])
        XCTAssertNil(PipeWeightBuoyancyCalculator.validatedCalculate(construction: invalid).result)

        let repaired = construction([("Pipe", 0.020, valid1000)])
        let validated = PipeWeightBuoyancyCalculator.validatedCalculate(construction: repaired)
        XCTAssertTrue(validated.canCalculate)
        XCTAssertNotNil(validated.result)
    }

    func testDeterministicTwoLayerMassAndDiameter() throws {
        let c = construction([("Inner", 0.010, valid1000), ("Outer", 0.020, valid3000)])
        let validated = PipeWeightBuoyancyCalculator.validatedCalculate(construction: c)
        let result = try XCTUnwrap(validated.result)

        XCTAssertEqual(result.finalOuterDiameterM, 0.360, accuracy: 1e-12)

        let area1 = Double.pi / 4 * (0.320 * 0.320 - 0.300 * 0.300)
        let area2 = Double.pi / 4 * (0.360 * 0.360 - 0.320 * 0.320)
        let expectedMass = area1 * 1000 + area2 * 3000
        XCTAssertEqual(result.pipeMassKgPerM, expectedMass, accuracy: 1e-12)
        XCTAssertEqual(result.layers[0].massKgPerM, area1 * 1000, accuracy: 1e-12)
        XCTAssertEqual(result.layers[1].massKgPerM, area2 * 3000, accuracy: 1e-12)
    }
}
