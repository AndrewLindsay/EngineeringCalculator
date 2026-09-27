import Foundation

/// File-level policy for portable Engineering Calculator documents.
/// Standalone calculations and projects intentionally use different extensions while
/// sharing the same versioned `CalculationDocument` payload.
enum CalculationDocumentFileType {
    static let standaloneExtension = "eccalc"
    static let projectExtension = "ecproject"

    static func filenameExtension(for kind: CalculationDocumentKind) -> String {
        switch kind {
        case .standaloneCalculation: return standaloneExtension
        case .project: return projectExtension
        }
    }

    static func suggestedFilename(for document: CalculationDocument) -> String {
        let base = sanitizedFilenameComponent(document.title)
        return "\(base).\(filenameExtension(for: document.kind))"
    }

    private static func sanitizedFilenameComponent(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let parts = value.components(separatedBy: invalid)
        let joined = parts.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? "Untitled Calculation" : joined
    }
}

enum CalculationDocumentFileError: Error, Equatable, LocalizedError {
    case unsupportedFileExtension(String)
    case fileKindDoesNotMatchExtension(expected: CalculationDocumentKind, actualExtension: String)
    case cannotRead(String)
    case cannotWrite(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedFileExtension(ext):
            return "Unsupported Engineering Calculator document extension '.\(ext)'."
        case let .fileKindDoesNotMatchExtension(expected, actualExtension):
            return "The document content is \(expected.rawValue), but the file extension is '.\(actualExtension)'."
        case let .cannotRead(message):
            return "The calculation document could not be read: \(message)"
        case let .cannotWrite(message):
            return "The calculation document could not be written: \(message)"
        }
    }
}

/// Central file I/O service. UI code should use this rather than duplicating encoder,
/// decoder or extension policy in individual calculator screens.
enum CalculationDocumentFileIO {
    static func data(for document: CalculationDocument) throws -> Data {
        try CalculationDocumentCodec.encode(document)
    }

    static func document(from data: Data) throws -> CalculationDocument {
        try CalculationDocumentCodec.decode(data)
    }

    static func write(_ document: CalculationDocument, to url: URL) throws {
        try validate(url: url, for: document.kind)
        do {
            try data(for: document).write(to: url, options: .atomic)
        } catch let error as CalculationDocumentCodecError {
            throw error
        } catch {
            throw CalculationDocumentFileError.cannotWrite(error.localizedDescription)
        }
    }

    static func read(from url: URL) throws -> CalculationDocument {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CalculationDocumentFileError.cannotRead(error.localizedDescription)
        }
        let document = try self.document(from: data)
        try validate(url: url, for: document.kind)
        return document
    }

    static func validate(url: URL, for kind: CalculationDocumentKind) throws {
        let ext = url.pathExtension.lowercased()
        guard ext == CalculationDocumentFileType.standaloneExtension || ext == CalculationDocumentFileType.projectExtension else {
            throw CalculationDocumentFileError.unsupportedFileExtension(ext)
        }
        let expected = CalculationDocumentFileType.filenameExtension(for: kind)
        guard ext == expected else {
            throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(expected: kind, actualExtension: ext)
        }
    }
}
