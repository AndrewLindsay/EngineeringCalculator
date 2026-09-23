import SwiftUI
import UniformTypeIdentifiers

private struct InitialStandaloneCalculationDocumentKey: EnvironmentKey {
    static let defaultValue: CalculationDocument? = nil
}

/// Context supplied by a project workspace when a calculator is editing a project-owned case.
/// Standalone calculators see nil and retain their normal Save Calculation workflow.
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

/// Reusable UI for opening a portable standalone calculation.
/// File reading and generic document validation live here; each calculator owns
/// the restoration of its own state and returns a user-facing success message.
///
/// A project workspace can also inject an in-memory standalone document through
/// `initialStandaloneCalculationDocument`. This deliberately reuses the exact same
/// calculator restoration path as opening an .eccalc file, so project cases do not
/// develop a second, subtly different loading implementation.
struct StandaloneCalculationOpenModifier: ViewModifier {
    @Environment(\.initialStandaloneCalculationDocument) private var initialDocument
    @State private var showingImporter = false
    @State private var validationMessage: String?
    @State private var validationError: String?
    @State private var didRestoreInitialDocument = false

    let onOpen: (CalculationDocument) throws -> String

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

            // A SwiftUI fileImporter can vend a security-scoped provider URL whose
            // temporary filename has no extension. Selection has already been filtered
            // by UTType, so decode the payload and validate the document kind instead.
            let data = try Data(contentsOf: url)
            let document = try CalculationDocumentFileIO.document(from: data)
            guard document.kind == .standaloneCalculation else {
                throw CalculationDocumentFileError.fileKindDoesNotMatchExtension(
                    expected: .standaloneCalculation,
                    actualExtension: CalculationDocumentFileType.projectExtension
                )
            }

            validationMessage = try onOpen(document)
        } catch {
            validationError = error.localizedDescription
        }
    }
}

extension View {
    func standaloneCalculationOpen(
        onOpen: @escaping (CalculationDocument) throws -> String
    ) -> some View {
        modifier(StandaloneCalculationOpenModifier(onOpen: onOpen))
    }
}
