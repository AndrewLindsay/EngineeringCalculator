import SwiftUI
import UniformTypeIdentifiers

struct MaterialImportExportView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = MaterialPortableFileDocument()
    @State private var exportContentType: UTType = .engineeringCalculatorMaterialLibrary
    @State private var exportFilename = "EngineeringCalculatorMaterials"
    @State private var importSummary: MaterialImportSummary?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Import") {
                    Button { showingImporter = true } label: { Label("Import Materials…", systemImage: "square.and.arrow.down") }
                        .help("Import materials from an .ecmaterial or .ecmaterials file")
                    Text("Import a .ecmaterial or .ecmaterials file. Imported materials are added to My Materials; existing materials are not replaced.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Export Libraries") {
                    Button { exportLibrary(store.userMaterials, filename: "EngineeringCalculator-My-Materials") } label: { Label("Export My Materials…", systemImage: "square.and.arrow.up") }
                        .disabled(store.userMaterials.isEmpty).help("Export all user-defined materials to a material library file")
                    Button { exportLibrary(store.builtInMaterials, filename: "EngineeringCalculator-Built-In-Materials") } label: { Label("Export Built-in Materials…", systemImage: "checkmark.seal") }
                        .help("Export the built-in material library for review or transfer")
                    Button { exportLibrary(store.allMaterials, filename: "EngineeringCalculator-All-Materials") } label: { Label("Export All Materials…", systemImage: "square.stack.3d.up") }
                        .help("Export built-in and user-defined materials together")
                    Text("Built-in materials may be exported for independent review and checking. Exporting does not make any changes to the built-in library.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Individual Materials") {
                    ForEach(store.allMaterials) { material in
                        Button { export(material) } label: { HStack { VStack(alignment: .leading, spacing: 2) { Text(material.name); Text("\(material.category) • \(material.isBuiltIn ? "Built-in" : "My Material")").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "square.and.arrow.up").foregroundStyle(.secondary) } }
                            .buttonStyle(.plain).help("Export \(material.name) as an individual material file")
                    }
                }
            }
            .navigationTitle("Material Files")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.help("Close Material Files") } }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.engineeringCalculatorMaterial, .engineeringCalculatorMaterialLibrary, .json], allowsMultipleSelection: false) { result in
            switch result { case .success(let urls): guard let url = urls.first else { return }; importFile(url); case .failure(let error): errorMessage = error.localizedDescription }
        }
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: exportContentType, defaultFilename: exportFilename) { result in if case .failure(let error) = result { errorMessage = error.localizedDescription } }
        .alert(item: $importSummary) { summary in Alert(title: Text("Import Complete"), message: Text(summary.message), dismissButton: .default(Text("OK"))) }
        .alert("Material File Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) { errorMessage = nil } } message: { Text(errorMessage ?? "Unknown error") }
    }

    private func importFile(_ url: URL) { let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }; do { let data = try Data(contentsOf: url); let report = try store.importPortableData(data); importSummary = MaterialImportSummary(report: report) } catch { errorMessage = error.localizedDescription } }
    private func exportLibrary(_ materials: [EngineeringMaterial], filename: String) { do { exportDocument = MaterialPortableFileDocument(data: try MaterialPortableCodec.encode(library: materials)); exportContentType = .engineeringCalculatorMaterialLibrary; exportFilename = filename; showingExporter = true } catch { errorMessage = error.localizedDescription } }
    private func export(_ material: EngineeringMaterial) { do { exportDocument = MaterialPortableFileDocument(data: try store.exportData(for: material)); exportContentType = .engineeringCalculatorMaterial; exportFilename = safeFilename(material.name); showingExporter = true } catch { errorMessage = error.localizedDescription } }
    private func safeFilename(_ name: String) -> String { let forbidden = CharacterSet(charactersIn: "/:\\?%*|\"<>"); let cleaned = name.components(separatedBy: forbidden).joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines); return cleaned.isEmpty ? "Material" : cleaned }
}
