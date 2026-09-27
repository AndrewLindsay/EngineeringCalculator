import Foundation

enum CalculationPersistenceSchema {
    static let documentFormatVersion = 1
    static let minimumReadableDocumentFormatVersion = 1
}

struct CalculationFieldID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: StringLiteralType) { self.rawValue = value }
}

enum PersistedInputSource: Codable, Hashable, Sendable {
    case literal(PersistedValue)
    case projectParameter(UUID)
    case calculationOutput(calculationID: UUID, outputID: CalculationFieldID)
}

enum PersistedValue: Codable, Hashable, Sendable {
    case number(Double)
    case integer(Int)
    case boolean(Bool)
    case text(String)
    case uuid(UUID)
    case numbers([Double])
    case strings([String])
}

struct SavedCalculationInput: Codable, Hashable, Identifiable, Sendable {
    let id: CalculationFieldID
    var displayName: String
    var source: PersistedInputSource
    var unitSymbol: String?
    init(id: CalculationFieldID, displayName: String, source: PersistedInputSource, unitSymbol: String? = nil) {
        self.id = id; self.displayName = displayName; self.source = source; self.unitSymbol = unitSymbol
    }
}

struct SavedCalculationOutput: Codable, Hashable, Identifiable, Sendable {
    let id: CalculationFieldID
    var displayName: String
    var value: PersistedValue
    var unitSymbol: String?
    init(id: CalculationFieldID, displayName: String, value: PersistedValue, unitSymbol: String? = nil) {
        self.id = id; self.displayName = displayName; self.value = value; self.unitSymbol = unitSymbol
    }
}

enum SavedValidationSeverity: String, Codable, Hashable, Sendable { case information, warning, error }

struct SavedValidationMessage: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var severity: SavedValidationSeverity
    var code: String
    var message: String
    init(id: UUID = UUID(), severity: SavedValidationSeverity, code: String, message: String) {
        self.id = id; self.severity = severity; self.code = code; self.message = message
    }
}

/// Complete material snapshot carried by a portable calculation document.
/// `contentFingerprint` describes engineering content independently of UUID/library status.
struct EmbeddedMaterial: Codable, Hashable, Identifiable {
    var material: EngineeringMaterial
    var fingerprintAlgorithm: String?
    var contentFingerprint: String?
    var id: UUID { material.id }

    init(material: EngineeringMaterial, fingerprintAlgorithm: String? = nil, contentFingerprint: String? = nil) {
        self.material = material
        self.fingerprintAlgorithm = fingerprintAlgorithm
        self.contentFingerprint = contentFingerprint
    }

    /// Preferred constructor for newly saved documents. Older version-1 documents may
    /// legitimately contain no fingerprint and remain readable.
    static func fingerprinted(_ material: EngineeringMaterial) throws -> EmbeddedMaterial {
        EmbeddedMaterial(
            material: material,
            fingerprintAlgorithm: MaterialFingerprint.algorithmName,
            contentFingerprint: try MaterialFingerprint.make(for: material)
        )
    }

    /// Recomputes the fingerprint from the embedded definition. This is used instead of
    /// blindly trusting the stored fingerprint when a document is opened/reconciled.
    func verifiedFingerprint() throws -> String {
        try MaterialFingerprint.make(for: material)
    }
}

struct SavedCalculation: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var calculatorID: String
    var calculatorSchemaVersion: Int
    var createdAt: Date
    var modifiedAt: Date
    var inputs: [SavedCalculationInput]
    var outputs: [SavedCalculationOutput]
    var assumptions: [String]
    var validationMessages: [SavedValidationMessage]
    var notes: String?

    init(id: UUID = UUID(), name: String, calculatorID: String, calculatorSchemaVersion: Int = 1,
         createdAt: Date = Date(), modifiedAt: Date = Date(), inputs: [SavedCalculationInput] = [],
         outputs: [SavedCalculationOutput] = [], assumptions: [String] = [],
         validationMessages: [SavedValidationMessage] = [], notes: String? = nil) {
        precondition(calculatorSchemaVersion > 0, "Calculator schema version must be positive")
        self.id=id; self.name=name; self.calculatorID=calculatorID; self.calculatorSchemaVersion=calculatorSchemaVersion
        self.createdAt=createdAt; self.modifiedAt=modifiedAt; self.inputs=inputs; self.outputs=outputs
        self.assumptions=assumptions; self.validationMessages=validationMessages; self.notes=notes
    }
}

enum CalculationDocumentKind: String, Codable, Hashable, Sendable { case standaloneCalculation, project }

struct CalculationDocument: Codable, Hashable, Identifiable {
    let id: UUID
    let documentFormatVersion: Int
    var kind: CalculationDocumentKind
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var calculations: [SavedCalculation]
    var embeddedMaterials: [EmbeddedMaterial]
    var notes: String?

    init(id: UUID = UUID(), documentFormatVersion: Int = CalculationPersistenceSchema.documentFormatVersion,
         kind: CalculationDocumentKind, title: String, createdAt: Date = Date(), modifiedAt: Date = Date(),
         calculations: [SavedCalculation], embeddedMaterials: [EmbeddedMaterial] = [], notes: String? = nil) {
        precondition(documentFormatVersion > 0, "Document format version must be positive")
        self.id=id; self.documentFormatVersion=documentFormatVersion; self.kind=kind; self.title=title
        self.createdAt=createdAt; self.modifiedAt=modifiedAt; self.calculations=calculations
        self.embeddedMaterials=embeddedMaterials; self.notes=notes
    }

    static func standalone(_ calculation: SavedCalculation, title: String? = nil,
                           embeddedMaterials: [EmbeddedMaterial] = []) -> CalculationDocument {
        CalculationDocument(kind: .standaloneCalculation, title: title ?? calculation.name,
                            createdAt: calculation.createdAt, modifiedAt: calculation.modifiedAt,
                            calculations: [calculation], embeddedMaterials: embeddedMaterials)
    }
}

enum CalculationDocumentCodecError: Error, Equatable, LocalizedError {
    case unsupportedDocumentVersion(found: Int, supportedThrough: Int)
    case invalidStandaloneCalculationCount(Int)
    case duplicateEmbeddedMaterialID(UUID)
    case embeddedMaterialFingerprintMismatch(UUID)

    var errorDescription: String? {
        switch self {
        case let .unsupportedDocumentVersion(found, supportedThrough):
            return "Calculation document version \(found) is newer than this app supports (through version \(supportedThrough))."
        case let .invalidStandaloneCalculationCount(count):
            return "A standalone calculation document must contain exactly one calculation; found \(count)."
        case let .duplicateEmbeddedMaterialID(id):
            return "The calculation document contains more than one embedded material with UUID \(id.uuidString)."
        case let .embeddedMaterialFingerprintMismatch(id):
            return "The embedded definition for material UUID \(id.uuidString) does not match its stored fingerprint."
        }
    }
}

enum CalculationDocumentCodec {
    static func encode(_ document: CalculationDocument, prettyPrinted: Bool = true) throws -> Data {
        try validate(document)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return try encoder.encode(document)
    }

    static func decode(_ data: Data) throws -> CalculationDocument {
        let envelopeDecoder = JSONDecoder()
        let envelope = try envelopeDecoder.decode(VersionEnvelope.self, from: data)
        guard envelope.documentFormatVersion <= CalculationPersistenceSchema.documentFormatVersion,
              envelope.documentFormatVersion >= CalculationPersistenceSchema.minimumReadableDocumentFormatVersion else {
            throw CalculationDocumentCodecError.unsupportedDocumentVersion(found: envelope.documentFormatVersion,
                                                                             supportedThrough: CalculationPersistenceSchema.documentFormatVersion)
        }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(CalculationDocument.self, from: data)
        try validate(document)
        return document
    }

    private static func validate(_ document: CalculationDocument) throws {
        if document.kind == .standaloneCalculation, document.calculations.count != 1 {
            throw CalculationDocumentCodecError.invalidStandaloneCalculationCount(document.calculations.count)
        }
        var materialIDs = Set<UUID>()
        for embedded in document.embeddedMaterials {
            guard materialIDs.insert(embedded.id).inserted else {
                throw CalculationDocumentCodecError.duplicateEmbeddedMaterialID(embedded.id)
            }
            if let stored = embedded.contentFingerprint {
                let verified = try embedded.verifiedFingerprint()
                guard stored == verified else {
                    throw CalculationDocumentCodecError.embeddedMaterialFingerprintMismatch(embedded.id)
                }
            }
        }
    }

    private struct VersionEnvelope: Decodable { let documentFormatVersion: Int }
}
