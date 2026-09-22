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

enum MaterialPortableFileKind: String, Codable {
    case material = "EngineeringCalculatorMaterial"
    case library = "EngineeringCalculatorMaterialLibrary"
    var filenameExtension: String { self == .material ? "ecmaterial" : "ecmaterials" }
}

struct MaterialPortableDocument: Hashable, Codable {
    static let currentFormatVersion = 1
    var format: String
    var formatVersion: Int
    var materials: [EngineeringMaterial]
    init(kind: MaterialPortableFileKind, materials: [EngineeringMaterial]) { self.format=kind.rawValue; self.formatVersion=Self.currentFormatVersion; self.materials=materials }
}

enum MaterialImportError: LocalizedError, Equatable {
    case malformedFile, emptyLibrary
    case unsupportedFormat(String), unsupportedVersion(Int), invalidMaterialCount(Int)
    var errorDescription: String? {
        switch self {
        case .malformedFile: return "The selected file is not a valid Engineering Calculator material file."
        case .unsupportedFormat(let value): return "Unsupported material file format: \(value)."
        case .unsupportedVersion(let version): return "This material file uses format version \(version), which is newer than this version of Engineering Calculator supports."
        case .invalidMaterialCount(let count): return "A .ecmaterial file must contain exactly one material; this file contains \(count)."
        case .emptyLibrary: return "The material file does not contain any materials."
        }
    }
}

struct MaterialImportReport: Equatable { var importedCount=0; var regeneratedUUIDCount=0; var renamedCount=0; var importedNames:[String]=[] }

enum MaterialPortableCodec {
    static func encode(material: EngineeringMaterial) throws -> Data { try encoder.encode(MaterialPortableDocument(kind:.material, materials:[portableCopy(material)])) }
    static func encode(library materials:[EngineeringMaterial]) throws -> Data { try encoder.encode(MaterialPortableDocument(kind:.library, materials:materials.map(portableCopy))) }
    static func decode(_ data:Data) throws -> (kind:MaterialPortableFileKind,materials:[EngineeringMaterial]) {
        let document:MaterialPortableDocument
        do { document=try JSONDecoder().decode(MaterialPortableDocument.self,from:data) } catch { throw MaterialImportError.malformedFile }
        guard let kind=MaterialPortableFileKind(rawValue:document.format) else { throw MaterialImportError.unsupportedFormat(document.format) }
        guard document.formatVersion <= MaterialPortableDocument.currentFormatVersion, document.formatVersion > 0 else { throw MaterialImportError.unsupportedVersion(document.formatVersion) }
        guard !document.materials.isEmpty else { throw MaterialImportError.emptyLibrary }
        if kind == .material && document.materials.count != 1 { throw MaterialImportError.invalidMaterialCount(document.materials.count) }
        return (kind,document.materials.map(portableCopy))
    }
    static func merge(imported:[EngineeringMaterial],into existing:[EngineeringMaterial])->(materials:[EngineeringMaterial],report:MaterialImportReport){
        var result=existing;var usedIDs=Set(existing.map(\.id));var usedNames=Set(existing.map{$0.name.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()});var report=MaterialImportReport()
        for source in imported { var material=portableCopy(source);if usedIDs.contains(material.id){material.id=UUID();report.regeneratedUUIDCount += 1};let originalName=material.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "Imported Material":material.name.trimmingCharacters(in:.whitespacesAndNewlines);material.name=uniqueName(originalName,usedNames:usedNames);if material.name != originalName{report.renamedCount += 1};material.isBuiltIn=false;usedIDs.insert(material.id);usedNames.insert(material.name.lowercased());result.append(material);report.importedCount += 1;report.importedNames.append(material.name) }
        return(result,report)
    }
    private static func portableCopy(_ source:EngineeringMaterial)->EngineeringMaterial{var copy=source;copy.isBuiltIn=false;return copy}
    private static func uniqueName(_ requested:String,usedNames:Set<String>)->String{guard usedNames.contains(requested.lowercased()) else{return requested};var index=2;while usedNames.contains("\(requested) (Imported \(index))".lowercased()){index += 1};return "\(requested) (Imported \(index))"}
    private static var encoder:JSONEncoder{let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];return e}
}

struct PortableCalculationMaterialImportReport: Hashable {
    var reconciliation: MaterialReconciliationSummary
    var importedMaterialIDs: [UUID]
    var importedNames: [String]
    var importedCount: Int { importedMaterialIDs.count }
    var identicalCount: Int { reconciliation.identicalMaterials.count }
    var conflictCount: Int { reconciliation.conflicts.count }
}

@MainActor
final class MaterialLibraryStore: ObservableObject {
    @Published private(set) var userMaterials:[EngineeringMaterial]=[]
    @Published var lastError:String?
    static let standardCategories=["Steel","Coating","Insulation","Concrete","Polymer","Elastomer","Composite","Other"]
    private static let alleimaS32760Source="Alleima SAF 32760+ Bar datasheet, updated 2025-05-09"
    private static let alleimaS32760URL="https://www.alleima.com/en/technical-center/material-datasheets/bar-and-hollow-bar/bar/saf-32760/"
    let builtInMaterials:[EngineeringMaterial]=[
        EngineeringMaterial(name:"Carbon Steel",category:"Steel",densityKgM3:7850,thermalConductivityWMK:45,specificHeatCapacityJkgK:475,source:"Generic engineering reference values; verify for the selected grade and temperature.",notes:"Thermal properties vary with composition and temperature.",isBuiltIn:true),
        EngineeringMaterial(name:"UNS S32760 (SAF 32760+)",category:"Steel",densityKgM3:7800,grade:"SAF 32760+",thermalConductivityWMK:15,specificHeatCapacityJkgK:500,thermalExpansionMicrostrainPerK:13.0,youngsModulusGPa:200,electricalResistivityOhmM:0.8e-6,source:"\(alleimaS32760Source) — \(alleimaS32760URL)",notes:"High-alloy duplex (super duplex) stainless steel. Temperature-dependent values are manufacturer datasheet values. Published thermal-expansion values are mean coefficients over 30 °C to the stated upper temperature. Alleima notes that prolonged exposure above 250 °C can change the microstructure and reduce impact strength; this is not stored as a generic maximum service temperature.",isBuiltIn:true,unsDesignation:"S32760",standardDesignation:"EN 1.4501; ASTM A479 / ASME SA-479; ASTM A276 / ASME SA-276",productForm:"Bar",materialCondition:"As covered by Alleima SAF 32760+ bar datasheet",thermalConductivitySeries:MaterialPropertySeries(referenceValue:15,referenceTemperatureC:20,temperatureTable:[MaterialPropertyPoint(temperatureC:20,value:15)],source:"\(alleimaS32760Source) — \(alleimaS32760URL)",basis:"Thermal conductivity, W/(m·K). Datasheet publishes 15 W/(m·°C) at 20 °C."),specificHeatCapacitySeries:MaterialPropertySeries(referenceValue:500,referenceTemperatureC:20,temperatureTable:[MaterialPropertyPoint(temperatureC:20,value:500)],source:"\(alleimaS32760Source) — \(alleimaS32760URL)",basis:"Specific heat capacity, J/(kg·K), published at 20 °C."),thermalExpansionSeries:MaterialPropertySeries(referenceValue:13.0,referenceTemperatureC:100,temperatureTable:[MaterialPropertyPoint(temperatureC:100,value:13.0),MaterialPropertyPoint(temperatureC:200,value:13.5),MaterialPropertyPoint(temperatureC:300,value:14.0)],source:"\(alleimaS32760Source) — \(alleimaS32760URL)",basis:"Mean coefficient of thermal expansion, ×10⁻⁶/K, for published ranges 30-100, 30-200 and 30-300 °C respectively; temperature field is the range upper bound."),youngsModulusSeries:MaterialPropertySeries(referenceValue:200,referenceTemperatureC:20,temperatureTable:[MaterialPropertyPoint(temperatureC:20,value:200),MaterialPropertyPoint(temperatureC:100,value:194),MaterialPropertyPoint(temperatureC:200,value:186),MaterialPropertyPoint(temperatureC:300,value:180)],source:"\(alleimaS32760Source) — \(alleimaS32760URL)",basis:"Modulus of elasticity, GPa (datasheet table is MPa ×10³)."),electricalResistivitySeries:MaterialPropertySeries(referenceValue:0.8e-6,referenceTemperatureC:20,temperatureTable:[MaterialPropertyPoint(temperatureC:20,value:0.8e-6)],source:"\(alleimaS32760Source) — \(alleimaS32760URL)",basis:"Electrical resistivity, Ω·m; datasheet publishes 0.8 μΩ·m at 20 °C.")),
        EngineeringMaterial(name:"Concrete",category:"Concrete",densityKgM3:2400,thermalConductivityWMK:1.7,specificHeatCapacityJkgK:880,source:"Generic engineering reference values; verify for the selected mix and condition.",notes:"Density and thermal properties vary substantially with mix and moisture content.",isBuiltIn:true),
        EngineeringMaterial(name:"Polypropylene",category:"Polymer",densityKgM3:900,thermalConductivityWMK:0.22,specificHeatCapacityJkgK:1900,source:"Generic engineering reference values; verify against the product datasheet.",notes:"Use manufacturer data for insulation-system calculations.",isBuiltIn:true)
    ]
    var allMaterials:[EngineeringMaterial]{builtInMaterials+userMaterials}
    var categories:[String]{let names=Self.standardCategories+allMaterials.map(\.category);var seen=Set<String>();return names.compactMap{raw in let value=raw.trimmingCharacters(in:.whitespacesAndNewlines);guard !value.isEmpty else{return nil};let key=value.lowercased();guard seen.insert(key).inserted else{return nil};return value}.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}}
    var steelMaterials:[EngineeringMaterial]{allMaterials.filter{$0.category.caseInsensitiveCompare("Steel") == .orderedSame}}
    init(){load()}
    func canonicalCategory(_ proposed:String)->String{let clean=proposed.trimmingCharacters(in:.whitespacesAndNewlines);if let existing=categories.first(where:{$0.caseInsensitiveCompare(clean) == .orderedSame}){return existing};return clean.isEmpty ? "Other":clean}
    func add(_ material:EngineeringMaterial){var copy=material;copy.isBuiltIn=false;copy.category=canonicalCategory(copy.category);userMaterials.append(copy);save()}
    func update(_ material:EngineeringMaterial){guard !material.isBuiltIn,let i=userMaterials.firstIndex(where:{$0.id==material.id})else{return};var copy=material;copy.category=canonicalCategory(copy.category);userMaterials[i]=copy;save()}
    func move(_ material:EngineeringMaterial,to category:String){guard !material.isBuiltIn,let i=userMaterials.firstIndex(where:{$0.id==material.id})else{return};userMaterials[i].category=canonicalCategory(category);save()}
    func duplicate(_ material:EngineeringMaterial){duplicate(material,to:material.category)}
    func duplicate(_ material:EngineeringMaterial,to category:String){var copy=material;copy.id=UUID();copy.name += " Copy";copy.isBuiltIn=false;copy.category=canonicalCategory(category);userMaterials.append(copy);save()}
    func delete(at offsets:IndexSet){userMaterials.remove(atOffsets:offsets);save()}
    func delete(id:UUID){userMaterials.removeAll{$0.id==id};save()}
    func exportData(for material:EngineeringMaterial)throws->Data{try MaterialPortableCodec.encode(material:material)}
    func exportUserLibraryData()throws->Data{try MaterialPortableCodec.encode(library:userMaterials)}
    @discardableResult func importPortableData(_ data:Data)throws->MaterialImportReport{let decoded=try MaterialPortableCodec.decode(data);let merged=MaterialPortableCodec.merge(imported:decoded.materials,into:userMaterials);userMaterials=merged.materials.map{var copy=$0;copy.category=canonicalCategory(copy.category);return copy};save();return merged.report}
    @discardableResult
    func importNewMaterials(from document:CalculationDocument)throws->PortableCalculationMaterialImportReport{
        let summary=try MaterialReconciler.reconcile(embeddedMaterials:document.embeddedMaterials,localMaterials:allMaterials)
        let candidates=MaterialReconciler.materialsEligibleForAutomaticImport(from:summary)
        var importedIDs:[UUID]=[];var importedNames:[String]=[]
        for source in candidates{guard !allMaterials.contains(where:{$0.id==source.id})else{continue};var material=source;material.isBuiltIn=false;material.category=canonicalCategory(material.category);userMaterials.append(material);importedIDs.append(material.id);importedNames.append(material.name)}
        if !importedIDs.isEmpty{save()}
        return PortableCalculationMaterialImportReport(reconciliation:summary,importedMaterialIDs:importedIDs,importedNames:importedNames)
    }
    private var fileURL:URL?{guard let base=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first else{return nil};let dir=base.appendingPathComponent("EngineeringCalculator",isDirectory:true);try? FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);return dir.appendingPathComponent("MaterialLibrary.json")}
    private func load(){guard let url=fileURL,let data=try? Data(contentsOf:url)else{return};do{userMaterials=try JSONDecoder().decode(MaterialLibraryDocument.self,from:data).materials}catch{lastError="Could not read the material library: \(error.localizedDescription)"}}
    private func save(){guard let url=fileURL else{return};do{let data=try JSONEncoder.pretty.encode(MaterialLibraryDocument(materials:userMaterials));try data.write(to:url,options:.atomic)}catch{lastError="Could not save the material library: \(error.localizedDescription)"}}
}
private extension JSONEncoder{static var pretty:JSONEncoder{let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];return e}}
