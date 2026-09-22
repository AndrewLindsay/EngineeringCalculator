import Foundation

/// Performs the non-UI validation used before an imported standalone calculation
/// is allowed to modify a calculator view.
enum StandaloneCalculationOpenValidator {
    enum ValidationError: Error, Equatable {
        case wrongDocumentKind(CalculationDocumentKind)
        case calculationCount(Int)
        case wrongCalculator(expected: String, actual: String)
        case unsupportedCalculatorSchema(expected: Int, actual: Int)
    }

    static func validatePipeWeightBuoyancy(_ document: CalculationDocument) throws {
        guard document.kind == .standaloneCalculation else {
            throw ValidationError.wrongDocumentKind(document.kind)
        }
        guard document.calculations.count == 1 else {
            throw ValidationError.calculationCount(document.calculations.count)
        }
        let calculation = document.calculations[0]
        guard calculation.calculatorID == PipeWeightBuoyancyPersistence.calculatorID else {
            throw ValidationError.wrongCalculator(
                expected: PipeWeightBuoyancyPersistence.calculatorID,
                actual: calculation.calculatorID
            )
        }
        guard calculation.calculatorSchemaVersion == PipeWeightBuoyancyPersistence.schemaVersion else {
            throw ValidationError.unsupportedCalculatorSchema(
                expected: PipeWeightBuoyancyPersistence.schemaVersion,
                actual: calculation.calculatorSchemaVersion
            )
        }

        // Parsing the persisted inputs here deliberately validates embedded material
        // availability and the complete calculator payload without changing UI state.
        _ = try PipeWeightBuoyancyPersistence.restore(from: document)
    }
}

extension StandaloneCalculationOpenValidator.ValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .wrongDocumentKind(kind):
            return "This file is a \(kind) document, not a standalone calculation."
        case let .calculationCount(count):
            return "A standalone calculation must contain exactly one calculation; this file contains \(count)."
        case let .wrongCalculator(expected, actual):
            return "This calculation belongs to '\(actual)' and cannot be opened in this calculator (expected '\(expected)')."
        case let .unsupportedCalculatorSchema(expected, actual):
            return "This calculation uses schema version \(actual), but this build supports version \(expected)."
        }
    }
}
