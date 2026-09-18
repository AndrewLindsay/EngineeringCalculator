import Foundation
import SwiftUI

enum EngineeringPropertyValue: Hashable, Codable {
    case constant(Double)
    case temperatureTable([TemperaturePropertyPoint])
    private enum CodingKeys: String, CodingKey { case kind, value, points }
    private enum Kind: String, Codable { case constant, temperatureTable }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .constant: self = .constant(try c.decode(Double.self, forKey: .value))
        case .temperatureTable: self = .temperatureTable(try c.decode([TemperaturePropertyPoint].self, forKey: .points))
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .constant(let value): try c.encode(Kind.constant, forKey: .kind); try c.encode(value, forKey: .value)
        case .temperatureTable(let points): try c.encode(Kind.temperatureTable, forKey: .kind); try c.encode(points, forKey: .points)
        }
    }
    var constantValue: Double? { if case .constant(let value) = self { return value }; return nil }
}

struct TemperaturePropertyPoint: Hashable, Codable, Identifiable {
    var id: UUID = UUID()
    var temperatureC: Double
    var value: Double
}

struct MaterialLibraryDocument: Hashable, Codable {
    var format: String = "EngineeringCalculatorMaterialLibrary"
    var formatVersion: Int = 1
    var materials: [EngineeringMaterial]
}

@MainActor
final class MaterialLibraryStore: ObservableObject {
    @Published private(set) var userMaterials: [EngineeringMaterial] = []
    @Published var lastError: String?

    static let standardCategories = ["Steel", "Coating", "Insulation", "Concrete", "Polymer", "Elastomer", "Composite", "Other"]

    let builtInMaterials: [EngineeringMaterial] = [
        EngineeringMaterial(name: "Carbon Steel", category: "Steel", densityKgM3: 7850,
                            thermalConductivityWMK: 45, specificHeatCapacityJkgK: 475,
                            source: "Generic engineering reference values; verify for the selected grade and temperature.",
                            notes: "Thermal properties vary with composition and temperature.", isBuiltIn: true),
        EngineeringMaterial(name: "Concrete", category: "Concrete", densityKgM3: 2400,
                            thermalConductivityWMK: 1.7, specificHeatCapacityJkgK: 880,
                            source: "Generic engineering reference values; verify for the selected mix and condition.",
                            notes: "Density and thermal properties vary substantially with mix and moisture content.", isBuiltIn: true),
        EngineeringMaterial(name: "Polypropylene", category: "Polymer", densityKgM3: 900,
                            thermalConductivityWMK: 0.22, specificHeatCapacityJkgK: 1900,
                            source: "Generic engineering reference values; verify against the product datasheet.",
                            notes: "Use manufacturer data for insulation-system calculations.", isBuiltIn: true)
    ]

    var allMaterials: [EngineeringMaterial] { builtInMaterials + userMaterials }
    var categories: [String] {
        let names = Self.standardCategories + allMaterials.map(\.category)
        var seen = Set<String>()
        return names.compactMap { raw in
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            let key = value.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return value
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    var steelMaterials: [EngineeringMaterial] {
        allMaterials.filter { $0.category.caseInsensitiveCompare("Steel") == .orderedSame }
    }

    init() { load() }

    func canonicalCategory(_ proposed: String) -> String {
        let clean = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = categories.first(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) { return existing }
        return clean.isEmpty ? "Other" : clean
    }

    func add(_ material: EngineeringMaterial) {
        var copy = material; copy.isBuiltIn = false; copy.category = canonicalCategory(copy.category)
        userMaterials.append(copy); save()
    }
    func update(_ material: EngineeringMaterial) {
        guard !material.isBuiltIn, let i = userMaterials.firstIndex(where: { $0.id == material.id }) else { return }
        var copy = material; copy.category = canonicalCategory(copy.category); userMaterials[i] = copy; save()
    }
    func move(_ material: EngineeringMaterial, to category: String) {
        guard !material.isBuiltIn, let i = userMaterials.firstIndex(where: { $0.id == material.id }) else { return }
        userMaterials[i].category = canonicalCategory(category); save()
    }
    func duplicate(_ material: EngineeringMaterial) {
        var copy = material; copy.id = UUID(); copy.name += " Copy"; copy.isBuiltIn = false
        userMaterials.append(copy); save()
    }
    func delete(at offsets: IndexSet) { userMaterials.remove(atOffsets: offsets); save() }
    func delete(id: UUID) { userMaterials.removeAll { $0.id == id }; save() }

    private var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("EngineeringCalculator", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("MaterialLibrary.json")
    }
    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return }
        do { userMaterials = try JSONDecoder().decode(MaterialLibraryDocument.self, from: data).materials }
        catch { lastError = "Could not read the material library: \(error.localizedDescription)" }
    }
    private func save() {
        guard let url = fileURL else { return }
        do { let data = try JSONEncoder.pretty.encode(MaterialLibraryDocument(materials: userMaterials)); try data.write(to: url, options: .atomic) }
        catch { lastError = "Could not save the material library: \(error.localizedDescription)" }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e }
}
