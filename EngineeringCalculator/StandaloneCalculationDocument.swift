import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Portable, self-contained Engineering Calculator calculation.
    static var engineeringCalculation: UTType {
        UTType(exportedAs: "com.andrewlindsay.engineeringcalculator.calculation", conformingTo: .json)
    }
}

/// SwiftUI file-document wrapper around the versioned CalculationDocument payload.
/// Keeping this generic allows every calculator adapter to use the same Save/Open UI.
struct StandaloneCalculationFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.engineeringCalculation] }
    static var writableContentTypes: [UTType] { [.engineeringCalculation] }

    var document: CalculationDocument

    init(document: CalculationDocument) {
        self.document = document
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CalculationDocumentFileError.cannotRead("The selected file does not contain readable data.")
        }
        let decoded = try CalculationDocumentFileIO.document(from: data)
        guard decoded.kind == .standaloneCalculation else {
            throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(expected: .standaloneCalculation, actualExtension: CalculationDocumentFileType.projectExtension)
        }
        document = decoded
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try CalculationDocumentFileIO.data(for: document))
    }
}
