import SwiftUI
import UniformTypeIdentifiers

/// Reusable UI for opening and validating a portable standalone calculation.
/// This phase deliberately does not mutate calculator state after validation.
struct StandaloneCalculationOpenModifier: ViewModifier {
    @State private var showingImporter = false
    @State private var validationMessage: String?
    @State private var validationError: String?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Open Calculation…", systemImage: "folder")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.engineeringCalculation],
                allowsMultipleSelection: false
            ) { result in
                open(result)
            }
            .alert("Calculation Validated", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) { validationMessage = nil }
            } message: {
                Text(validationMessage ?? "")
            }
            .alert("Open Calculation Failed", isPresented: Binding(
                get: { validationError != nil },
                set: { if !$0 { validationError = nil } }
            )) {
                Button("OK", role: .cancel) { validationError = nil }
            } message: {
                Text(validationError ?? "")
            }
    }

    private func open(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }

            let document = try CalculationDocumentFileIO.read(from: url)
            guard document.kind == .standaloneCalculation else {
                throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(
                    expected: .standaloneCalculation,
                    actualExtension: url.pathExtension
                )
            }

            let restored = try PipeWeightBuoyancyPersistence.restore(from: document)
            guard let calculation = document.calculations.first else {
                throw PipeWeightBuoyancyPersistence.RestoreError.missingInput("calculation")
            }

            validationMessage = "\(calculation.name) was successfully opened and validated. \(document.embeddedMaterials.count) embedded material\(document.embeddedMaterials.count == 1 ? "" : "s") and \(calculation.inputs.count) calculation input\(calculation.inputs.count == 1 ? "" : "s") were found. \(restored.construction.layers.count) pipe layer\(restored.construction.layers.count == 1 ? "" : "s") were reconstructed. No current inputs have been changed."
        } catch {
            validationError = error.localizedDescription
        }
    }
}

extension View {
    func standaloneCalculationOpenValidation() -> some View {
        modifier(StandaloneCalculationOpenModifier())
    }
}
