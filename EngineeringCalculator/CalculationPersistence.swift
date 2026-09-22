import Foundation

/// Versioning for the portable calculation document format.
///
/// `documentFormatVersion` changes only when the outer document representation changes.
/// Individual calculator payloads are independently versioned by `calculatorSchemaVersion`.
enum CalculationPersistenceSchema {
    static let documentFormatVersion = 1
    static let minimumReadableDocumentFormatVersion = 1
}

/// Stable machine-readable identifier for a persisted calculator input or output.
/// Display labels are deliberately not used as identity so labels can change without
/// breaking saved documents, project parameters or future calculation chaining.
struct CalculationFieldID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: StringLiteralType) { self.rawValue = value }
}

/// Extensible source of an input value.
///
/// Version 1 writes literal values only, but the representation deliberately reserves
/// stable cases for project parameters and calculation-output links so persistence does
/// not need to be redesigned when those features are implemented.
enum PersistedInputSource: Codable, Hashable, Sendable {
    case literal(PersistedValue)
    case projectParameter(UUID)
    case calculationOutput(calculationID: UUID, outputID: CalculationFieldID)
}

/// Type-safe, Codable engineering value used by portable calculations.
/// New cases can be added through a document-format migration without reducing all
/// engineering data to strings or untyped dictionaries.
enum PersistedValue: Codable, Hashable, Sendable {
    case number(Double)
    case integer(Int)
    case boolean(Bool)
    case text(String)
    case uuid(UUID)
    case numbers([Double])
    case strings([String])
}

/// A persisted input retains both machine identity and the user's selected/display unit.
/// `displayName` is historical/reporting metadata only; `id` is the stable identity.
struct SavedCalculationInput: Codable, Hashable, Identifiable, Sendable {
    let id: CalculationFieldID
    var displayName: String
    var source: PersistedInputSource
    var unitSymbol: String?

    init(id: CalculationFieldID, displayName: String, source: PersistedInputSource, unitSymbol: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.source = source
        self.unitSymbol = unitSymbol
    }
}

/// A persisted output is a snapshot of the result at save time. Future recalculation may
/// replace it, but the saved value remains available for audit/migration decisions.
struct SavedCalculationOutput: Codable, Hashable, Identifiable, Sendable {
    let id: CalculationFieldID
    var displayName: String
    var value: PersistedValue
    var unitSymbol: String?

    init(id: CalculationFieldID, displayName: String, value: PersistedValue, unitSymbol: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.value = value
        self.unitSymbol = unitSymbol
    }
}

enum SavedValidationSeverity: String, Codable, Hashable, Sendable {
    case information
    case warning
    case error
}

/// Validation messages are persisted because they form part of the engineering record.
struct SavedValidationMessage: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var severity: SavedValidationSeverity
    var code: String
    var message: String

    init(id: UUID = UUID(), severity: SavedValidationSeverity, code: String, message: String) {
        self.id = id
        self.severity = severity
        self.code = code
        self.message = message
    }
}

/// Portable representation of one calculation.
///
/// `calculatorID` is the stable registry identity (for example `pipeWeightBuoyancy`).
/// `calculatorSchemaVersion` belongs to that calculator and is independent of the outer
/// document format version.
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

    init(
        id: UUID = UUID(),
        name: String,
        calculatorID: String,
        calculatorSchemaVersion: Int = 1,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        inputs: [SavedCalculationInput] = [],
        outputs: [SavedCalculationOutput] = [],
        assumptions: [String] = [],
        validationMessages: [SavedValidationMessage] = [],
        notes: String? = nil
    ) {
        precondition(calculatorSchemaVersion > 0, "Calculator schema version must be positive")
        self.id = id
        self.name = name
        self.calculatorID = calculatorID
        self.calculatorSchemaVersion = calculatorSchemaVersion
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.inputs = inputs
        self.outputs = outputs
        self.assumptions = assumptions
        self.validationMessages = validationMessages
        self.notes = notes
    }
}

enum CalculationDocumentKind: String, Codable, Hashable, Sendable {
    case standaloneCalculation
    case project
}

/// Version-1 portable calculation container.
///
/// The container supports one standalone calculation or multiple project calculations.
/// Embedded materials are intentionally added in the next persistence milestone; the
/// document model is separated from runtime calculator objects now so that addition is
/// a format evolution rather than a calculator rewrite.
struct CalculationDocument: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let documentFormatVersion: Int
    var kind: CalculationDocumentKind
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var calculations: [SavedCalculation]
    var notes: String?

    init(
        id: UUID = UUID(),
        documentFormatVersion: Int = CalculationPersistenceSchema.documentFormatVersion,
        kind: CalculationDocumentKind,
        title: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        calculations: [SavedCalculation],
        notes: String? = nil
    ) {
        precondition(documentFormatVersion > 0, "Document format version must be positive")
        self.id = id
        self.documentFormatVersion = documentFormatVersion
        self.kind = kind
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.calculations = calculations
        self.notes = notes
    }

    static func standalone(_ calculation: SavedCalculation, title: String? = nil) -> CalculationDocument {
        CalculationDocument(
            kind: .standaloneCalculation,
            title: title ?? calculation.name,
            createdAt: calculation.createdAt,
            modifiedAt: calculation.modifiedAt,
            calculations: [calculation]
        )
    }
}

enum CalculationDocumentCodecError: Error, Equatable, LocalizedError {
    case unsupportedDocumentVersion(found: Int, supportedThrough: Int)
    case invalidStandaloneCalculationCount(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedDocumentVersion(found, supportedThrough):
            return "Calculation document version \(found) is newer than this app supports (through version \(supportedThrough))."
        case let .invalidStandaloneCalculationCount(count):
            return "A standalone calculation document must contain exactly one calculation; found \(count)."
        }
    }
}

/// Centralised deterministic JSON codec for portable calculation documents.
/// Keeping encoder/decoder policy here avoids file-format drift between macOS/iOS UI paths.
enum CalculationDocumentCodec {
    static func encode(_ document: CalculationDocument, prettyPrinted: Bool = true) throws -> Data {
        try validate(document)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return try encoder.encode(document)
    }

    static func decode(_ data: Data) throws -> CalculationDocument {
        // Decode a tiny envelope first so a future/newer document gets a deliberate
        // compatibility error rather than a misleading generic decoding failure.
        let envelopeDecoder = JSONDecoder()
        let envelope = try envelopeDecoder.decode(VersionEnvelope.self, from: data)
        guard envelope.documentFormatVersion <= CalculationPersistenceSchema.documentFormatVersion else {
            throw CalculationDocumentCodecError.unsupportedDocumentVersion(
                found: envelope.documentFormatVersion,
                supportedThrough: CalculationPersistenceSchema.documentFormatVersion
            )
        }
        guard envelope.documentFormatVersion >= CalculationPersistenceSchema.minimumReadableDocumentFormatVersion else {
            throw CalculationDocumentCodecError.unsupportedDocumentVersion(
                found: envelope.documentFormatVersion,
                supportedThrough: CalculationPersistenceSchema.documentFormatVersion
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(CalculationDocument.self, from: data)
        try validate(document)
        return document
    }

    private static func validate(_ document: CalculationDocument) throws {
        if document.kind == .standaloneCalculation, document.calculations.count != 1 {
            throw CalculationDocumentCodecError.invalidStandaloneCalculationCount(document.calculations.count)
        }
    }

    private struct VersionEnvelope: Decodable {
        let documentFormatVersion: Int
    }
}
