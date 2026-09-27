import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    // These identifiers are exported by the EngineeringCalculator app target.
    // Keep the identifiers here exactly aligned with the target's Info settings:
    //   .ecmaterial  -> com.andrewlindsay.engineeringcalculator.material
    //   .ecmaterials -> com.andrewlindsay.engineeringcalculator.material-library
    static let engineeringCalculatorMaterial = UTType(exportedAs: "com.andrewlindsay.engineeringcalculator.material", conformingTo: .json)
    static let engineeringCalculatorMaterialLibrary = UTType(exportedAs: "com.andrewlindsay.engineeringcalculator.material-library", conformingTo: .json)
}

struct MaterialPortableFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.engineeringCalculatorMaterial, .engineeringCalculatorMaterialLibrary, .json] }
    static var writableContentTypes: [UTType] { [.engineeringCalculatorMaterial, .engineeringCalculatorMaterialLibrary] }

    var data: Data

    init(data: Data = Data()) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct MaterialImportSummary: Identifiable {
    let id = UUID()
    let report: MaterialImportReport

    var message: String {
        var lines = ["Imported \(report.importedCount) material\(report.importedCount == 1 ? "" : "s")."]
        if report.renamedCount > 0 {
            lines.append("\(report.renamedCount) material name\(report.renamedCount == 1 ? " was" : "s were") renamed to avoid duplicates.")
        }
        if report.regeneratedUUIDCount > 0 {
            lines.append("\(report.regeneratedUUIDCount) internal identifier\(report.regeneratedUUIDCount == 1 ? " was" : "s were") regenerated to avoid conflicts.")
        }
        if !report.importedNames.isEmpty {
            lines.append("\n" + report.importedNames.joined(separator: "\n"))
        }
        return lines.joined(separator: "\n")
    }
}
