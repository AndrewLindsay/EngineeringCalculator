import Foundation

enum MaterialPropertyKind: String, CaseIterable, Identifiable, Codable {
    case density, thermalConductivity, specificHeatCapacity, thermalExpansion, youngsModulus, poissonsRatio, yieldStrength, ultimateTensileStrength, shearModulus, compressiveStrength, electricalResistivity, smys, smts
    var id: String { rawValue }
    var name: String {
        switch self { case .density: return "Density"; case .thermalConductivity: return "Thermal conductivity"; case .specificHeatCapacity: return "Specific heat capacity"; case .thermalExpansion: return "Thermal expansion"; case .youngsModulus: return "Young's modulus"; case .poissonsRatio: return "Poisson's ratio"; case .yieldStrength: return "Yield strength"; case .ultimateTensileStrength: return "Ultimate tensile strength"; case .shearModulus: return "Shear modulus"; case .compressiveStrength: return "Compressive strength"; case .electricalResistivity: return "Electrical resistivity"; case .smys: return "SMYS"; case .smts: return "SMTS" }
    }
    var unit: String {
        switch self { case .density: return "kg/m³"; case .thermalConductivity: return "W/(m·K)"; case .specificHeatCapacity: return "J/(kg·K)"; case .thermalExpansion: return "µm/(m·K)"; case .youngsModulus, .shearModulus: return "GPa"; case .poissonsRatio: return ""; case .yieldStrength, .ultimateTensileStrength, .compressiveStrength, .smys, .smts: return "MPa"; case .electricalResistivity: return "Ω·m" }
    }
}

enum MaterialPropertyResolutionMethod: String, Codable { case constant, tableExact, linearInterpolation, equation }
enum MaterialPropertyResolutionStatus: Equatable, Codable { case resolved, missing, temperatureRequired, outsideAvailableRange(minimumC: Double, maximumC: Double), outsideEquationRange(minimumC: Double?, maximumC: Double?) }
struct MaterialPropertyResolution: Equatable, Codable { var property: MaterialPropertyKind; var value: Double?; var unit: String; var temperatureC: Double?; var method: MaterialPropertyResolutionMethod?; var status: MaterialPropertyResolutionStatus; var lowerPoint: MaterialPropertyPoint?; var upperPoint: MaterialPropertyPoint?; var source: String?; var basis: String?; var isExtrapolated: Bool; var isResolved: Bool { value != nil && status == .resolved } }

enum MaterialPropertyResolver {
    static func availableProperties(in material: EngineeringMaterial) -> [MaterialPropertyKind] { MaterialPropertyKind.allCases.filter { let d = propertyData($0, material: material); return d.scalar != nil || d.series?.referenceValue != nil || !(d.series?.temperatureTable.isEmpty ?? true) || d.series?.equation != nil } }
    static func resolve(_ property: MaterialPropertyKind, in material: EngineeringMaterial, atTemperatureC temperatureC: Double? = nil) -> MaterialPropertyResolution {
        let data = propertyData(property, material: material)
        guard let series = data.series else { guard let scalar = data.scalar else { return make(property, temperatureC, nil, nil, .missing) }; return make(property, temperatureC, scalar, .constant, .resolved, source: material.source) }
        if let equation = series.equation { guard let temperatureC else { return make(property, nil, nil, nil, .temperatureRequired, source: series.source ?? material.source, basis: series.basis) }; let outside = (equation.minimumTemperatureC.map { temperatureC < $0 } ?? false) || (equation.maximumTemperatureC.map { temperatureC > $0 } ?? false); if outside && !equation.allowsExtrapolation { return make(property, temperatureC, nil, nil, .outsideEquationRange(minimumC: equation.minimumTemperatureC, maximumC: equation.maximumTemperatureC), source: series.source ?? material.source, basis: series.basis) }; return make(property, temperatureC, equation.value(atTemperatureC: temperatureC), .equation, .resolved, source: series.source ?? material.source, basis: series.basis, extrapolated: outside) }
        let points = series.temperatureTable.sorted { $0.temperatureC < $1.temperatureC }
        if !points.isEmpty { guard let temperatureC else { if points.count == 1, let p = points.first { return make(property, p.temperatureC, p.value, .tableExact, .resolved, lower: p, upper: p, source: series.source ?? material.source, basis: series.basis) }; return make(property, nil, nil, nil, .temperatureRequired, source: series.source ?? material.source, basis: series.basis) }; let first = points[0], last = points[points.count - 1]; guard temperatureC >= first.temperatureC, temperatureC <= last.temperatureC else { return make(property, temperatureC, nil, nil, .outsideAvailableRange(minimumC: first.temperatureC, maximumC: last.temperatureC), source: series.source ?? material.source, basis: series.basis) }; if let exact = points.first(where: { $0.temperatureC == temperatureC }) { return make(property, temperatureC, exact.value, .tableExact, .resolved, lower: exact, upper: exact, source: series.source ?? material.source, basis: series.basis) }; for i in 0..<(points.count - 1) { let lo = points[i], hi = points[i + 1]; if temperatureC > lo.temperatureC && temperatureC < hi.temperatureC { let f = (temperatureC - lo.temperatureC) / (hi.temperatureC - lo.temperatureC); return make(property, temperatureC, lo.value + f * (hi.value - lo.value), .linearInterpolation, .resolved, lower: lo, upper: hi, source: series.source ?? material.source, basis: series.basis) } } }
        if let reference = series.referenceValue ?? data.scalar { return make(property, series.referenceTemperatureC ?? temperatureC, reference, .constant, .resolved, source: series.source ?? material.source, basis: series.basis) }
        return make(property, temperatureC, nil, nil, .missing, source: series.source ?? material.source, basis: series.basis)
    }
    private static func make(_ property: MaterialPropertyKind, _ temperatureC: Double?, _ value: Double?, _ method: MaterialPropertyResolutionMethod?, _ status: MaterialPropertyResolutionStatus, lower: MaterialPropertyPoint? = nil, upper: MaterialPropertyPoint? = nil, source: String? = nil, basis: String? = nil, extrapolated: Bool = false) -> MaterialPropertyResolution { MaterialPropertyResolution(property: property, value: value, unit: property.unit, temperatureC: temperatureC, method: method, status: status, lowerPoint: lower, upperPoint: upper, source: source, basis: basis, isExtrapolated: extrapolated) }
    private static func propertyData(_ kind: MaterialPropertyKind, material: EngineeringMaterial) -> (scalar: Double?, series: MaterialPropertySeries?) { switch kind { case .density: return (material.densityKgM3,nil); case .thermalConductivity: return (material.thermalConductivityWMK,material.thermalConductivitySeries); case .specificHeatCapacity: return (material.specificHeatCapacityJkgK,material.specificHeatCapacitySeries); case .thermalExpansion: return (material.thermalExpansionMicrostrainPerK,material.thermalExpansionSeries); case .youngsModulus: return (material.youngsModulusGPa,material.youngsModulusSeries); case .poissonsRatio: return (material.poissonsRatio,material.poissonsRatioSeries); case .yieldStrength: return (material.yieldStrengthMPa,material.yieldStrengthSeries); case .ultimateTensileStrength: return (material.ultimateTensileStrengthMPa,material.ultimateTensileStrengthSeries); case .shearModulus: return (material.shearModulusGPa,material.shearModulusSeries); case .compressiveStrength: return (material.compressiveStrengthMPa,nil); case .electricalResistivity: return (material.electricalResistivityOhmM,material.electricalResistivitySeries); case .smys: return (material.smysMPa,nil); case .smts: return (material.smtsMPa,nil) } }
}

// MARK: - Calculation material requirements

enum MaterialRequirementLevel: String, Codable, Hashable { case required, optional }
struct MaterialPropertyRequirement: Hashable, Codable, Identifiable {
    var property: MaterialPropertyKind; var level: MaterialRequirementLevel; var temperatureC: Double?; var purpose: String?
    var id: String { "\(property.rawValue)-\(level.rawValue)-\(temperatureC.map(String.init) ?? "calculation")" }
    init(_ property: MaterialPropertyKind, level: MaterialRequirementLevel = .required, temperatureC: Double? = nil, purpose: String? = nil) { self.property=property; self.level=level; self.temperatureC=temperatureC; self.purpose=purpose }
}
struct MaterialRequirementSet: Hashable, Codable, Identifiable { var id:String; var name:String; var requirements:[MaterialPropertyRequirement] }
enum MaterialValidationSeverity: String, Codable, Hashable { case error, warning }
enum MaterialValidationIssueReason: Hashable, Codable { case missing, temperatureRequired, outsideAvailableRange(minimumC:Double,maximumC:Double), outsideEquationRange(minimumC:Double?,maximumC:Double?) }
struct MaterialValidationIssue: Hashable, Codable, Identifiable {
    var materialID:UUID; var materialName:String; var property:MaterialPropertyKind; var severity:MaterialValidationSeverity; var reason:MaterialValidationIssueReason; var temperatureC:Double?; var purpose:String?
    var id:String { "\(materialID.uuidString)-\(property.rawValue)-\(severity.rawValue)-\(String(describing:reason))" }
    var message:String {
        let prefix="\(materialName): \(property.name)"
        switch reason {
        case .missing: return "\(prefix) is not defined."
        case .temperatureRequired: return "\(prefix) requires a calculation temperature."
        case .outsideAvailableRange(let min,let max): return "\(prefix) cannot be evaluated at \(temperatureText); available tabulated data cover \(min.formatted()) to \(max.formatted()) °C."
        case .outsideEquationRange(let min,let max):
            let range:String; switch(min,max){case let(a?,b?):range="\(a.formatted()) to \(b.formatted()) °C";case let(a?,nil):range="temperatures at or above \(a.formatted()) °C";case let(nil,b?):range="temperatures at or below \(b.formatted()) °C";case(nil,nil):range="the defined equation range"}
            return "\(prefix) cannot be evaluated at \(temperatureText); the correlation is valid for \(range)."
        }
    }
    private var temperatureText:String { temperatureC.map{"\($0.formatted()) °C"} ?? "the requested temperature" }
}
struct MaterialValidationResult: Hashable, Codable { var requirementSetID:String; var issues:[MaterialValidationIssue]; var errors:[MaterialValidationIssue]{issues.filter{$0.severity == .error}}; var warnings:[MaterialValidationIssue]{issues.filter{$0.severity == .warning}}; var canCalculate:Bool{errors.isEmpty} }

enum MaterialRequirementValidator {
    static func validate(material:EngineeringMaterial,against set:MaterialRequirementSet,calculationTemperatureC:Double?=nil)->MaterialValidationResult { validate(materials:[material],against:set,calculationTemperatureC:calculationTemperatureC) }
    static func validate(materials:[EngineeringMaterial],against set:MaterialRequirementSet,calculationTemperatureC:Double?=nil)->MaterialValidationResult {
        var issues:[MaterialValidationIssue]=[]
        for material in materials { for requirement in set.requirements {
            let temperature=requirement.temperatureC ?? calculationTemperatureC
            let resolution=MaterialPropertyResolver.resolve(requirement.property,in:material,atTemperatureC:temperature)
            guard !resolution.isResolved else { continue }
            let severity:MaterialValidationSeverity=requirement.level == .required ? .error : .warning
            let reason:MaterialValidationIssueReason
            switch resolution.status { case .resolved:continue;case .missing:reason = .missing;case .temperatureRequired:reason = .temperatureRequired;case .outsideAvailableRange(let min,let max):reason = .outsideAvailableRange(minimumC:min,maximumC:max);case .outsideEquationRange(let min,let max):reason = .outsideEquationRange(minimumC:min,maximumC:max) }
            issues.append(.init(materialID:material.id,materialName:material.name,property:requirement.property,severity:severity,reason:reason,temperatureC:temperature,purpose:requirement.purpose))
        }}
        return .init(requirementSetID:set.id,issues:issues)
    }
}

enum StandardMaterialRequirementSets {
    static let mass=MaterialRequirementSet(id:"mass",name:"Mass / weight",requirements:[.init(.density,purpose:"Material mass")])
    static let steadyStateConduction=MaterialRequirementSet(id:"steady-state-conduction",name:"Steady-state heat conduction",requirements:[.init(.thermalConductivity,purpose:"Conductive heat transfer")])
    static let transientThermal=MaterialRequirementSet(id:"transient-thermal",name:"Transient thermal calculation",requirements:[.init(.density,purpose:"Thermal mass"),.init(.specificHeatCapacity,purpose:"Thermal mass"),.init(.thermalConductivity,purpose:"Heat transfer")])
    static let linearElastic=MaterialRequirementSet(id:"linear-elastic",name:"Linear elastic calculation",requirements:[.init(.youngsModulus,purpose:"Elastic response"),.init(.poissonsRatio,purpose:"Elastic response")])
}
