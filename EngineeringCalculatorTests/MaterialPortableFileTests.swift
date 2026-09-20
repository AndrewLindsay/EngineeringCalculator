import XCTest
@testable import EngineeringCalculator

final class MaterialPortableFileTests: XCTestCase {
    private func fixture(id: UUID = UUID(), name: String = "Portable Test Material", builtIn: Bool = false) -> EngineeringMaterial {
        EngineeringMaterial(
            id: id,
            name: name,
            category: "Validation",
            densityKgM3: 8123,
            grade: "TEST-GRADE",
            thermalConductivityWMK: 12.5,
            specificHeatCapacityJkgK: 456,
            thermalExpansionMicrostrainPerK: 11.2,
            minimumServiceTemperatureC: -40,
            maximumServiceTemperatureC: 300,
            youngsModulusGPa: 205,
            poissonsRatio: 0.29,
            yieldStrengthMPa: 550,
            ultimateTensileStrengthMPa: 720,
            shearModulusGPa: 79,
            compressiveStrengthMPa: 600,
            electricalResistivityOhmM: 1.1e-6,
            source: "Portable test fixture",
            notes: "Must survive portable-file round trip.",
            isBuiltIn: builtIn,
            unsDesignation: "S00000",
            standardDesignation: "TEST 123",
            productForm: "Bar",
            materialCondition: "Test condition",
            thermalConductivitySeries: MaterialPropertySeries(
                referenceValue: 10,
                referenceTemperatureC: 20,
                equation: MaterialPropertyEquation(a: 10, b: 0.1, c: 0.001, d: 0, minimumTemperatureC: 0, maximumTemperatureC: 200, allowsExtrapolation: false, kind: .polynomial),
                source: "Polynomial fixture",
                basis: "k(T) = 10 + 0.1T + 0.001T²"
            ),
            specificHeatCapacitySeries: MaterialPropertySeries(
                referenceValue: 450,
                referenceTemperatureC: 20,
                equation: MaterialPropertyEquation(minimumTemperatureC: -40, maximumTemperatureC: 300, allowsExtrapolation: false, kind: .linearReference, referenceValue: 450, referenceTemperatureC: 20, slope: 0.25),
                source: "Linear-reference fixture"
            ),
            youngsModulusSeries: MaterialPropertySeries(
                referenceValue: 205,
                referenceTemperatureC: 20,
                temperatureTable: [
                    MaterialPropertyPoint(temperatureC: 20, value: 205),
                    MaterialPropertyPoint(temperatureC: 100, value: 198),
                    MaterialPropertyPoint(temperatureC: 200, value: 188)
                ],
                source: "Table fixture"
            ),
            electricalResistivitySeries: MaterialPropertySeries(
                referenceValue: 1.0e-6,
                referenceTemperatureC: 20,
                equation: MaterialPropertyEquation(minimumTemperatureC: -50, maximumTemperatureC: 250, allowsExtrapolation: false, kind: .relativeLinear, referenceValue: 1.0e-6, referenceTemperatureC: 20, temperatureCoefficient: 0.004),
                source: "TCR fixture"
            )
        )
    }

    func testSingleMaterialRoundTripPreservesCompletePropertyData() throws {
        let original = fixture()
        let data = try MaterialPortableCodec.encode(material: original)
        let decoded = try MaterialPortableCodec.decode(data)
        XCTAssertEqual(decoded.kind, .material)
        XCTAssertEqual(decoded.materials.count, 1)
        var expected = original
        expected.isBuiltIn = false
        XCTAssertEqual(decoded.materials[0], expected)
    }

    func testLibraryRoundTripPreservesMultipleMaterials() throws {
        let originals = [fixture(name: "Alpha"), fixture(name: "Beta")]
        let data = try MaterialPortableCodec.encode(library: originals)
        let decoded = try MaterialPortableCodec.decode(data)
        XCTAssertEqual(decoded.kind, .library)
        XCTAssertEqual(decoded.materials, originals)
    }

    func testEquationKindsAndTemperatureTableSurviveRoundTrip() throws {
        let data = try MaterialPortableCodec.encode(material: fixture())
        let material = try XCTUnwrap(MaterialPortableCodec.decode(data).materials.first)
        XCTAssertEqual(material.thermalConductivitySeries?.equation?.effectiveKind, .polynomial)
        XCTAssertEqual(material.specificHeatCapacitySeries?.equation?.effectiveKind, .linearReference)
        XCTAssertEqual(material.electricalResistivitySeries?.equation?.effectiveKind, .relativeLinear)
        XCTAssertEqual(material.youngsModulusSeries?.temperatureTable.count, 3)
        XCTAssertEqual(material.youngsModulusSeries?.value(atTemperatureC: 150), 193, accuracy: 1e-12)
        XCTAssertEqual(material.electricalResistivitySeries?.value(atTemperatureC: 120), 1.4e-6, accuracy: 1e-15)
    }

    func testMalformedJSONIsRejected() {
        XCTAssertThrowsError(try MaterialPortableCodec.decode(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? MaterialImportError, .malformedFile)
        }
    }

    func testUnsupportedFormatIsRejected() throws {
        let data = Data("{\"format\":\"OtherFormat\",\"formatVersion\":1,\"materials\":[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"X\",\"category\":\"Other\",\"isBuiltIn\":false}]}".utf8)
        XCTAssertThrowsError(try MaterialPortableCodec.decode(data)) { error in
            XCTAssertEqual(error as? MaterialImportError, .unsupportedFormat("OtherFormat"))
        }
    }

    func testFutureFormatVersionIsRejected() throws {
        let encoder = JSONEncoder()
        let document = MaterialPortableDocument(kind: .library, materials: [fixture()])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(document)) as? [String: Any])
        object["formatVersion"] = MaterialPortableDocument.currentFormatVersion + 1
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try MaterialPortableCodec.decode(data)) { error in
            XCTAssertEqual(error as? MaterialImportError, .unsupportedVersion(MaterialPortableDocument.currentFormatVersion + 1))
        }
    }

    func testEmptyLibraryIsRejected() throws {
        let data = try JSONEncoder().encode(MaterialPortableDocument(kind: .library, materials: []))
        XCTAssertThrowsError(try MaterialPortableCodec.decode(data)) { error in
            XCTAssertEqual(error as? MaterialImportError, .emptyLibrary)
        }
    }

    func testSingleMaterialDocumentRejectsMultipleMaterials() throws {
        let data = try JSONEncoder().encode(MaterialPortableDocument(kind: .material, materials: [fixture(name: "A"), fixture(name: "B")]))
        XCTAssertThrowsError(try MaterialPortableCodec.decode(data)) { error in
            XCTAssertEqual(error as? MaterialImportError, .invalidMaterialCount(2))
        }
    }

    func testMergeRegeneratesDuplicateUUID() {
        let id = UUID()
        let existing = fixture(id: id, name: "Existing")
        let incoming = fixture(id: id, name: "Incoming")
        let merged = MaterialPortableCodec.merge(imported: [incoming], into: [existing])
        XCTAssertEqual(merged.materials.count, 2)
        XCTAssertEqual(merged.materials[0].id, id)
        XCTAssertNotEqual(merged.materials[1].id, id)
        XCTAssertEqual(merged.report.regeneratedUUIDCount, 1)
        XCTAssertEqual(merged.report.importedCount, 1)
    }

    func testMergeRenamesDuplicateNamesCaseInsensitively() {
        let existing = fixture(name: "Duplex Steel")
        let incoming = fixture(name: "duplex steel")
        let merged = MaterialPortableCodec.merge(imported: [incoming], into: [existing])
        XCTAssertEqual(merged.materials[1].name, "duplex steel (Imported 2)")
        XCTAssertEqual(merged.report.renamedCount, 1)
        XCTAssertEqual(merged.report.importedNames, ["duplex steel (Imported 2)"])
    }

    func testMergeUsesNextAvailableImportedSuffix() {
        let existing = [fixture(name: "Steel"), fixture(name: "Steel (Imported 2)"), fixture(name: "Steel (Imported 3)")]
        let merged = MaterialPortableCodec.merge(imported: [fixture(name: "Steel")], into: existing)
        XCTAssertEqual(merged.materials.last?.name, "Steel (Imported 4)")
    }

    func testBuiltInFlagIsRemovedOnExportAndImport() throws {
        let builtIn = fixture(name: "Built In Source", builtIn: true)
        let data = try MaterialPortableCodec.encode(material: builtIn)
        let decoded = try XCTUnwrap(MaterialPortableCodec.decode(data).materials.first)
        XCTAssertFalse(decoded.isBuiltIn)
        let merged = MaterialPortableCodec.merge(imported: [builtIn], into: [])
        XCTAssertFalse(try XCTUnwrap(merged.materials.first).isBuiltIn)
    }
}
