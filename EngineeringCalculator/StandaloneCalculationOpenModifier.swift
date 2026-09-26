import SwiftUI
import UniformTypeIdentifiers

private struct InitialStandaloneCalculationDocumentKey: EnvironmentKey {
    static let defaultValue: CalculationDocument? = nil
}

struct ProjectCalculationUpdateContext {
    let calculationID: UUID
    let calculationName: String
    let update: (CalculationDocument) throws -> Void
}

private struct ProjectCalculationUpdateContextKey: EnvironmentKey {
    static let defaultValue: ProjectCalculationUpdateContext? = nil
}

extension EnvironmentValues {
    var initialStandaloneCalculationDocument: CalculationDocument? {
        get { self[InitialStandaloneCalculationDocumentKey.self] }
        set { self[InitialStandaloneCalculationDocumentKey.self] = newValue }
    }

    var projectCalculationUpdateContext: ProjectCalculationUpdateContext? {
        get { self[ProjectCalculationUpdateContextKey.self] }
        set { self[ProjectCalculationUpdateContextKey.self] = newValue }
    }
}

/// Reusable state for a standalone calculation that was opened from a file.
/// It preserves document/calculation identity and performs a true in-place Save.
struct StandaloneCalculationDocumentSession {
    var url: URL?
    var originalDocument: CalculationDocument?

    var canSaveInPlace: Bool { url != nil && originalDocument != nil }

    mutating func opened(document: CalculationDocument, at url: URL) {
        originalDocument = document
        self.url = url
    }

    mutating func save(_ updatedDocument: CalculationDocument) throws {
        guard let url, let originalDocument else {
            throw CalculationDocumentFileError.cannotWrite("No existing calculation file is open. Use Save As to choose a location first.")
        }

        let document = preservingIdentity(of: originalDocument, in: updatedDocument)
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }

        try CalculationDocumentFileIO.write(document, to: url)
        self.originalDocument = document
    }

    func preservingIdentity(of original: CalculationDocument, in updated: CalculationDocument) -> CalculationDocument {
        var result = updated
        result = CalculationDocument(
            id: original.id,
            documentFormatVersion: updated.documentFormatVersion,
            kind: updated.kind,
            title: updated.title,
            createdAt: original.createdAt,
            modifiedAt: updated.modifiedAt,
            calculations: updated.calculations,
            embeddedMaterials: updated.embeddedMaterials,
            notes: updated.notes
        )

        if original.calculations.count == 1, result.calculations.count == 1 {
            let oldCalculation = original.calculations[0]
            let newCalculation = result.calculations[0]
            result.calculations[0] = SavedCalculation(
                id: oldCalculation.id,
                name: newCalculation.name,
                calculatorID: newCalculation.calculatorID,
                calculatorSchemaVersion: newCalculation.calculatorSchemaVersion,
                createdAt: oldCalculation.createdAt,
                modifiedAt: newCalculation.modifiedAt,
                inputs: newCalculation.inputs,
                outputs: newCalculation.outputs,
                assumptions: newCalculation.assumptions,
                validationMessages: newCalculation.validationMessages,
                notes: newCalculation.notes
            )
        }
        return result
    }
}

struct StandaloneCalculationOpenModifier: ViewModifier {
    @Environment(\.initialStandaloneCalculationDocument) private var initialDocument
    @State private var showingImporter = false
    @State private var validationMessage: String?
    @State private var validationError: String?
    @State private var didRestoreInitialDocument = false

    let onOpen: (CalculationDocument) throws -> String
    let onOpenURL: ((URL, CalculationDocument) -> Void)?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Open Calculation…", systemImage: "folder")
                    }
                    .help(String(localized: "tooltip.openCalculation"))
                    .accessibilityLabel(String(localized: "tooltip.openCalculation"))
                }
            }
            .onAppear { restoreInitialDocumentIfNeeded() }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.engineeringCalculation],
                allowsMultipleSelection: false
            ) { result in
                open(result)
            }
            .alert("Calculation Opened", isPresented: Binding(
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

    private func restoreInitialDocumentIfNeeded() {
        guard !didRestoreInitialDocument, let initialDocument else { return }
        didRestoreInitialDocument = true
        do {
            guard initialDocument.kind == .standaloneCalculation else {
                throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(
                    expected: .standaloneCalculation,
                    actualExtension: CalculationDocumentFileType.projectExtension
                )
            }
            validationMessage = try onOpen(initialDocument)
        } catch {
            validationError = error.localizedDescription
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

            let data = try Data(contentsOf: url)
            let document = try CalculationDocumentFileIO.document(from: data)
            guard document.kind == .standaloneCalculation else {
                throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(
                    expected: .standaloneCalculation,
                    actualExtension: CalculationDocumentFileType.projectExtension
                )
            }

            validationMessage = try onOpen(document)
            onOpenURL?(url, document)
        } catch {
            validationError = error.localizedDescription
        }
    }
}

extension View {
    func standaloneCalculationOpen(
        onOpenURL: ((URL, CalculationDocument) -> Void)? = nil,
        onOpen: @escaping (CalculationDocument) throws -> String
    ) -> some View {
        modifier(StandaloneCalculationOpenModifier(onOpen: onOpen, onOpenURL: onOpenURL))
    }
}
