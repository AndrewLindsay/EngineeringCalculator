import XCTest
@testable import EngineeringCalculator

final class StandaloneCalculationOpenValidatorTests: XCTestCase {
    private func construction() -> PipeConstruction {
        let material = EngineeringMaterial(
            id: UUID(uuidString: "D1000000-0000-0000-0000-000000000001")!,
            name: "Open Validation Steel",
            category: "Steel",
            densityKgM3: 7850
        )
        return PipeConstruction(
            name: "Validation Pipe",
            internalDiameterM: 0.3,
            layers: [PipeLayer(
                id: UUID(uuidString: "D2000000-0000-0000-0000-000000000001")!,
                name: material.name,
                thicknessM: 0.02,
                material: material
            )],
            internalFluid: FluidDefinition(name: "Internal", densityKgM3: 1000),
            externalFluid: FluidDefinition(name: "External", densityKgM3: 1025)
        )
    }

    private func validDocument() throws -> CalculationDocument {
        let construction = construction()
        return try PipeWeightBuoyancyPersistence.makeDocument(
            name: "Validation Case",
            construction: construction,
            result: PipeWeightBuoyancyCalculator.calculate(construction: construction)
        )
    }

    func testAcceptsValidPipeWeightStandaloneDocument() throws {
        XCTAssertNoThrow(try StandaloneCalculationOpenValidator.validatePipeWeightBuoyancy(validDocument()))
    }

    func testRejectsProjectDocument() throws {
        var document = try validDocument()
        document.kind = .project
        XCTAssertThrowsError(try StandaloneCalculationOpenValidator.validatePipeWeightBuoyancy(document)) { error in
            XCTAssertEqual(error as? StandaloneCalculationOpenValidator.ValidationError, .wrongDocumentKind(.project))
        }
    }

    func testRejectsDocumentWithMoreThanOneCalculation() throws {
        var document = try validDocument()
        document.calculations.append(document.calculations[0])
        XCTAssertThrowsError(try StandaloneCalculationOpenValidator.validatePipeWeightBuoyancy(document)) { error in
            XCTAssertEqual(error as? StandaloneCalculationOpenValidator.ValidationError, .calculationCount(2))
        }
    }

    func testRejectsWrongCalculator() throws {
        var document = try validDocument()
        document.calculations[0].calculatorID = "pipe-heat-transfer"
        XCTAssertThrowsError(try StandaloneCalculationOpenValidator.validatePipeWeightBuoyancy(document)) { error in
            XCTAssertEqual(
                error as? StandaloneCalculationOpenValidator.ValidationError,
                .wrongCalculator(expected: PipeWeightBuoyancyPersistence.calculatorID, actual: "pipe-heat-transfer")
            )
        }
    }

    func testRejectsUnsupportedSchemaVersion() throws {
        var document = try validDocument()
        document.calculations[0].calculatorSchemaVersion = PipeWeightBuoyancyPersistence.schemaVersion + 1
        XCTAssertThrowsError(try StandaloneCalculationOpenValidator.validatePipeWeightBuoyancy(document)) { error in
            XCTAssertEqual(
                error as? StandaloneCalculationOpenValidator.ValidationError,
                .unsupportedCalculatorSchema(expected: PipeWeightBuoyancyPersistence.schemaVersion, actual: PipeWeightBuoyancyPersistence.schemaVersion + 1)
            )
        }
    }

    func testRejectsIncompletePayloadBeforeUIStateCanChange() throws {
        var document = try validDocument()
        document.embeddedMaterials = []
        XCTAssertThrowsError(try StandaloneCalculationOpenValidator.validatePipeWeightBuoyancy(document))
    }
}
