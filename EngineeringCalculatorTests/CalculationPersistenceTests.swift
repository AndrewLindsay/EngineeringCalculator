import XCTest
@testable import EngineeringCalculator

final class CalculationPersistenceTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)

    private func sampleCalculation() -> SavedCalculation {
        SavedCalculation(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "8-inch pipe weight",
            calculatorID: "pipeWeightBuoyancy",
            calculatorSchemaVersion: 1,
            createdAt: fixedDate,
            modifiedAt: fixedDate,
            inputs: [
                SavedCalculationInput(
                    id: "internalDiameter",
                    displayName: "Internal diameter",
                    source: .literal(.number(0.2032)),
                    unitSymbol: "m"
                ),
                SavedCalculationInput(
                    id: "flooded",
                    displayName: "Flooded",
                    source: .literal(.boolean(true))
                )
            ],
            outputs: [
                SavedCalculationOutput(
                    id: "pipeMassPerLength",
                    displayName: "Dry pipe mass",
                    value: .number(42.5),
                    unitSymbol: "kg/m"
                )
            ],
            assumptions: ["Calculation is per metre of pipe length."],
            validationMessages: [
                SavedValidationMessage(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    severity: .information,
                    code: "materials.valid",
                    message: "All required material properties are available."
                )
            ],
            notes: "Regression fixture"
        )
    }

    func testStandaloneDocumentRoundTripPreservesEngineeringRecord() throws {
        let calculation = sampleCalculation()
        let document = CalculationDocument(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            kind: .standaloneCalculation,
            title: calculation.name,
            createdAt: fixedDate,
            modifiedAt: fixedDate,
            calculations: [calculation],
            notes: "Portable calculation"
        )

        let data = try CalculationDocumentCodec.encode(document)
        let decoded = try CalculationDocumentCodec.decode(data)

        XCTAssertEqual(decoded, document)
        XCTAssertEqual(decoded.documentFormatVersion, 1)
        XCTAssertEqual(decoded.calculations.first?.calculatorID, "pipeWeightBuoyancy")
        XCTAssertEqual(decoded.calculations.first?.inputs.first?.id.rawValue, "internalDiameter")
        XCTAssertEqual(decoded.calculations.first?.outputs.first?.id.rawValue, "pipeMassPerLength")
    }

    func testStableIdentityDoesNotDependOnDisplayName() {
        let original = SavedCalculationInput(
            id: "insideTemperature",
            displayName: "Inside temperature",
            source: .literal(.number(80)),
            unitSymbol: "°C"
        )
        let renamed = SavedCalculationInput(
            id: "insideTemperature",
            displayName: "Internal boundary temperature",
            source: .literal(.number(80)),
            unitSymbol: "°C"
        )

        XCTAssertEqual(original.id, renamed.id)
        XCTAssertNotEqual(original.displayName, renamed.displayName)
    }

    func testInputSourceSupportsFutureProjectParameterReference() throws {
        let parameterID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let input = SavedCalculationInput(
            id: "designTemperature",
            displayName: "Design temperature",
            source: .projectParameter(parameterID),
            unitSymbol: "°C"
        )
        let calculation = SavedCalculation(
            name: "Future project parameter test",
            calculatorID: "test",
            inputs: [input]
        )
        let data = try CalculationDocumentCodec.encode(.standalone(calculation))
        let decoded = try CalculationDocumentCodec.decode(data)

        XCTAssertEqual(decoded.calculations[0].inputs[0].source, .projectParameter(parameterID))
    }

    func testInputSourceSupportsFutureCalculationChainingReference() throws {
        let upstreamID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let input = SavedCalculationInput(
            id: "outsideDiameter",
            displayName: "Outside diameter",
            source: .calculationOutput(calculationID: upstreamID, outputID: "finalOutsideDiameter"),
            unitSymbol: "m"
        )
        let calculation = SavedCalculation(name: "Linked calculation", calculatorID: "test", inputs: [input])
        let data = try CalculationDocumentCodec.encode(.standalone(calculation))
        let decoded = try CalculationDocumentCodec.decode(data)

        XCTAssertEqual(
            decoded.calculations[0].inputs[0].source,
            .calculationOutput(calculationID: upstreamID, outputID: "finalOutsideDiameter")
        )
    }

    func testStandaloneDocumentRejectsMultipleCalculations() {
        let document = CalculationDocument(
            kind: .standaloneCalculation,
            title: "Invalid standalone",
            calculations: [sampleCalculation(), sampleCalculation()]
        )

        XCTAssertThrowsError(try CalculationDocumentCodec.encode(document)) { error in
            XCTAssertEqual(error as? CalculationDocumentCodecError, .invalidStandaloneCalculationCount(2))
        }
    }

    func testProjectDocumentAllowsMultipleCalculations() throws {
        let document = CalculationDocument(
            kind: .project,
            title: "Export Pipeline",
            calculations: [sampleCalculation(), sampleCalculation()]
        )

        let data = try CalculationDocumentCodec.encode(document)
        let decoded = try CalculationDocumentCodec.decode(data)
        XCTAssertEqual(decoded.kind, .project)
        XCTAssertEqual(decoded.calculations.count, 2)
    }

    func testNewerDocumentVersionProducesExplicitCompatibilityError() throws {
        let document = CalculationDocument(kind: .project, title: "Version test", calculations: [])
        let data = try CalculationDocumentCodec.encode(document)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["documentFormatVersion"] = CalculationPersistenceSchema.documentFormatVersion + 1
        let newerData = try JSONSerialization.data(withJSONObject: json)

        XCTAssertThrowsError(try CalculationDocumentCodec.decode(newerData)) { error in
            XCTAssertEqual(
                error as? CalculationDocumentCodecError,
                .unsupportedDocumentVersion(
                    found: CalculationPersistenceSchema.documentFormatVersion + 1,
                    supportedThrough: CalculationPersistenceSchema.documentFormatVersion
                )
            )
        }
    }

    func testDeterministicEncodingForUnchangedDocument() throws {
        let document = CalculationDocument(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            kind: .standaloneCalculation,
            title: "Deterministic",
            createdAt: fixedDate,
            modifiedAt: fixedDate,
            calculations: [sampleCalculation()]
        )

        let first = try CalculationDocumentCodec.encode(document)
        let second = try CalculationDocumentCodec.encode(document)
        XCTAssertEqual(first, second)
    }
}
