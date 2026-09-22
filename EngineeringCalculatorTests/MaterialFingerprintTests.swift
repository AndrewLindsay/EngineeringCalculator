import XCTest
@testable import EngineeringCalculator

final class MaterialFingerprintTests: XCTestCase {
    private func material(id: UUID = UUID(), builtIn: Bool = false) -> EngineeringMaterial {
        EngineeringMaterial(
            id: id,
            name: "Fingerprint Steel",
            category: "Steel",
            densityKgM3: 7850,
            grade: "FP-1",
            thermalConductivityWMK: 45,
            specificHeatCapacityJkgK: 475,
            source: "Fingerprint fixture",
            notes: "Regression material",
            isBuiltIn: builtIn,
            thermalConductivitySeries: MaterialPropertySeries(
                referenceValue: 45,
                referenceTemperatureC: 20,
                temperatureTable: [
                    MaterialPropertyPoint(temperatureC: 20, value: 45),
                    MaterialPropertyPoint(temperatureC: 100, value: 41)
                ],
                source: "Table source",
                basis: "Measured"
            )
        )
    }

    func testSameEngineeringContentProducesSameFingerprint() throws {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let first = material(id: id)
        let second = first
        XCTAssertEqual(try MaterialFingerprint.make(for: first), try MaterialFingerprint.make(for: second))
    }

    func testMaterialUUIDDoesNotAffectFingerprint() throws {
        let first = material(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        var second = first
        second.id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        XCTAssertEqual(try MaterialFingerprint.make(for: first), try MaterialFingerprint.make(for: second))
    }

    func testBuiltInStatusDoesNotAffectEngineeringFingerprint() throws {
        let first = material(builtIn: false)
        var second = first
        second.isBuiltIn = true
        XCTAssertEqual(try MaterialFingerprint.make(for: first), try MaterialFingerprint.make(for: second))
    }

    func testChangedEngineeringPropertyChangesFingerprint() throws {
        let first = material()
        var second = first
        second.densityKgM3 = 7800
        XCTAssertNotEqual(try MaterialFingerprint.make(for: first), try MaterialFingerprint.make(for: second))
    }

    func testChangedTemperatureDependentValueChangesFingerprint() throws {
        let first = material()
        var second = first
        second.thermalConductivitySeries?.temperatureTable[1].value = 40
        XCTAssertNotEqual(try MaterialFingerprint.make(for: first), try MaterialFingerprint.make(for: second))
    }

    func testTemperaturePointUUIDDoesNotAffectFingerprint() throws {
        let first = material()
        var second = first
        second.thermalConductivitySeries?.temperatureTable[0].id = UUID()
        second.thermalConductivitySeries?.temperatureTable[1].id = UUID()
        XCTAssertEqual(try MaterialFingerprint.make(for: first), try MaterialFingerprint.make(for: second))
    }

    func testFingerprintIsStableSHA256Hex() throws {
        let fingerprint = try MaterialFingerprint.make(for: material())
        XCTAssertEqual(fingerprint.count, 64)
        XCTAssertTrue(fingerprint.allSatisfy { $0.isHexDigit })
        XCTAssertEqual(MaterialFingerprint.algorithmName, "sha256-material-v1")
    }

    func testFingerprintedEmbeddedMaterialStoresVerifiedFingerprint() throws {
        let source = material(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!)
        let embedded = try EmbeddedMaterial.fingerprinted(source)
        XCTAssertEqual(embedded.fingerprintAlgorithm, MaterialFingerprint.algorithmName)
        XCTAssertEqual(embedded.contentFingerprint, try MaterialFingerprint.make(for: source))
        XCTAssertEqual(try embedded.verifiedFingerprint(), embedded.contentFingerprint)
    }

    func testTamperedFingerprintedMaterialIsRejectedByDocumentCodec() throws {
        let source = material(id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!)
        var embedded = try EmbeddedMaterial.fingerprinted(source)
        embedded.material.densityKgM3 = 1234
        let calculation = SavedCalculation(name: "Fingerprint tamper test", calculatorID: "test")
        let document = CalculationDocument.standalone(calculation, embeddedMaterials: [embedded])

        XCTAssertThrowsError(try CalculationDocumentCodec.encode(document)) { error in
            XCTAssertEqual(error as? CalculationDocumentCodecError, .embeddedMaterialFingerprintMismatch(source.id))
        }
    }

    func testLegacyEmbeddedMaterialWithoutFingerprintRemainsReadable() throws {
        let source = material()
        let calculation = SavedCalculation(name: "Legacy v1", calculatorID: "test")
        let document = CalculationDocument.standalone(calculation, embeddedMaterials: [EmbeddedMaterial(material: source)])
        let data = try CalculationDocumentCodec.encode(document)
        let decoded = try CalculationDocumentCodec.decode(data)
        XCTAssertNil(decoded.embeddedMaterials[0].contentFingerprint)
        XCTAssertEqual(decoded.embeddedMaterials[0].material, source)
    }
}
