import XCTest
@testable import EngineeringCalculator

final class CalculationDocumentFileIOTests: XCTestCase {
    private func calculation(name: String = "Build Comparison Case") -> SavedCalculation {
        SavedCalculation(
            name: name,
            calculatorID: "testCalculator",
            inputs: [
                SavedCalculationInput(id: "pressure", displayName: "Pressure", source: .literal(.number(128)), unitSymbol: "bar(a)"),
                SavedCalculationInput(id: "temperature", displayName: "Temperature", source: .literal(.number(80)), unitSymbol: "°C")
            ],
            outputs: [
                SavedCalculationOutput(id: "result", displayName: "Result", value: .number(42.0), unitSymbol: "kg/m")
            ]
        )
    }

    private func material() -> EngineeringMaterial {
        EngineeringMaterial(
            id: UUID(uuidString: "F1000000-0000-0000-0000-000000000001")!,
            name: "File I/O Test Steel",
            category: "Steel",
            densityKgM3: 7850,
            thermalConductivityWMK: 45,
            source: "File I/O regression fixture"
        )
    }

    private func standalone() throws -> CalculationDocument {
        CalculationDocument.standalone(
            calculation(),
            embeddedMaterials: [try EmbeddedMaterial.fingerprinted(material())]
        )
    }

    private func temporaryURL(_ filename: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(filename)
    }

    private func createParentDirectory(for url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    func testStandaloneSuggestedFilenameUsesEccalcExtension() throws {
        let document = try standalone()
        XCTAssertEqual(CalculationDocumentFileType.suggestedFilename(for: document), "Build Comparison Case.eccalc")
    }

    func testSuggestedFilenameSanitizesUnsafeCharacters() {
        let document = CalculationDocument.standalone(calculation(name: "Case 1 / 128 bar: baseline"))
        XCTAssertEqual(CalculationDocumentFileType.suggestedFilename(for: document), "Case 1 - 128 bar- baseline.eccalc")
    }

    func testStandaloneDataRoundTripPreservesExactInputsOutputsAndMaterials() throws {
        let original = try standalone()
        let data = try CalculationDocumentFileIO.data(for: original)
        let restored = try CalculationDocumentFileIO.document(from: data)
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.calculations[0].inputs, original.calculations[0].inputs)
        XCTAssertEqual(restored.calculations[0].outputs, original.calculations[0].outputs)
        XCTAssertEqual(restored.embeddedMaterials, original.embeddedMaterials)
    }

    func testStandaloneDiskRoundTripPreservesExactDocument() throws {
        let original = try standalone()
        let url = temporaryURL("comparison.eccalc")
        try createParentDirectory(for: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try CalculationDocumentFileIO.write(original, to: url)
        let restored = try CalculationDocumentFileIO.read(from: url)
        XCTAssertEqual(restored, original)
    }

    func testWritingStandaloneWithWrongExtensionIsRejected() throws {
        let document = try standalone()
        let url = temporaryURL("wrong.ecproject")
        XCTAssertThrowsError(try CalculationDocumentFileIO.write(document, to: url)) { error in
            XCTAssertEqual(error as? CalculationDocumentFileError,
                           .fileKindDoesNotMatchExtension(expected: .standaloneCalculation, actualExtension: "ecproject"))
        }
    }

    func testUnsupportedExtensionIsRejected() throws {
        let document = try standalone()
        let url = temporaryURL("wrong.json")
        XCTAssertThrowsError(try CalculationDocumentFileIO.write(document, to: url)) { error in
            XCTAssertEqual(error as? CalculationDocumentFileError, .unsupportedFileExtension("json"))
        }
    }

    func testProjectUsesEcprojectExtensionAndRoundTrips() throws {
        let project = CalculationDocument(kind: .project, title: "Pipeline Study", calculations: [calculation(), calculation(name: "Second Case")])
        XCTAssertEqual(CalculationDocumentFileType.suggestedFilename(for: project), "Pipeline Study.ecproject")
        let url = temporaryURL("Pipeline Study.ecproject")
        try createParentDirectory(for: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try CalculationDocumentFileIO.write(project, to: url)
        XCTAssertEqual(try CalculationDocumentFileIO.read(from: url), project)
    }

    func testReadingContentWithMismatchedExtensionIsRejected() throws {
        let project = CalculationDocument(kind: .project, title: "Project", calculations: [calculation()])
        let url = temporaryURL("pretending-to-be-calculation.eccalc")
        try createParentDirectory(for: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try CalculationDocumentFileIO.data(for: project).write(to: url)
        XCTAssertThrowsError(try CalculationDocumentFileIO.read(from: url)) { error in
            XCTAssertEqual(error as? CalculationDocumentFileError,
                           .fileKindDoesNotMatchExtension(expected: .project, actualExtension: "eccalc"))
        }
    }
}
