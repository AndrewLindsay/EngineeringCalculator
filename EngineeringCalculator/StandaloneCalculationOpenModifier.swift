import SwiftUI
import UniformTypeIdentifiers

/// Reusable UI for opening a portable standalone calculation.
/// File reading and generic document validation live here; each calculator owns
/// the restoration of its own state and returns a user-facing success message.
struct StandaloneCalculationOpenModifier: ViewModifier {
    @State private var showingImporter = false
    @State private var validationMessage: String?
    @State private var validationError: String?

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
