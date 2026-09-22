import Foundation

enum MaterialRequirementLevel: String, Codable, Hashable { case required, optional }

struct MaterialPropertyRequirement: Hashable, Codable, Identifiable {
    var property: MaterialPropertyKind
    var level: MaterialRequirementLevel
    var temperatureC: Double?
    var purpose: String?
    var id: String { "\(property.rawValue)-\(level.rawValue)-\(temperatureC.map(String.init) ?? "calculation")" }
    init(_ property: MaterialPropertyKind, level: MaterialRequirementLevel = .required, temperatureC: Double? = nil, purpose: String? = nil) { self.property=property; self.level=level; self.temperatureC=temperatureC; self.purpose=purpose }
}

struct MaterialRequirementSet: Hashable, Codable, Identifiable {
    var id: String; var name: String; var requirements: [MaterialPropertyRequirement]
    init(id: String, name: String, requirements: [MaterialPropertyRequirement]) { self.id=id; self.name=name; self.requirements=requirements }
}

enum MaterialValidationSeverity: String, Codable, Hashable { case error, warning }
enum MaterialValidationIssueReason: Hashable, Codable {
    case missing
    case temperatureRequired
    case outsideAvailableRange(minimumC: Double, maximumC: Double)
    case outsideEquationRange(minimumC: Double?, maximumC: Double?)
}

struct MaterialValidationIssue: Hashable, Codable, Identifiable {
    var materialID: UUID; var materialName: String; var property: MaterialPropertyKind
    var severity: MaterialValidationSeverity; var reason: MaterialValidationIssueReason
    var temperatureC: Double?; var purpose: String?
    var id: String { "\(materialID.uuidString)-\(property.rawValue)-\(severity.rawValue)-\(String(describing: reason))" }
    var message: String {
        let prefix="\(materialName): \(property.name)"
        switch reason {
        case .missing: return "\(prefix) is not defined."
        case .temperatureRequired: return "\(prefix) requires a calculation temperature."
        case .outsideAvailableRange(let min, let max): return "\(prefix) cannot be evaluated at \(temperatureText); available tabulated data cover \(min.formatted()) to \(max.formatted()) °C."
        case .outsideEquationRange(let min, let max):
            let range:String
            switch (min,max) { case let (a?,b?): range="\(a.formatted()) to \(b.formatted()) °C"; case let (a?,nil): range="temperatures at or above \(a.formatted()) °C"; case let (nil,b?): range="temperatures at or below \(b.formatted()) °C"; case (nil,nil): range="the defined equation range" }
            return "\(prefix) cannot be evaluated at \(temperatureText); the correlation is valid for \(range)."
        }
    }
    private var temperatureText:String { temperatureC.map{"\($0.formatted()) °C"} ?? "the requested temperature" }
}

struct MaterialValidationResult: Hashable, Codable {
    var requirementSetID:String; var issues:[MaterialValidationIssue]
    var errors:[MaterialValidationIssue] { issues.filter{$0.severity == .error} }
    var warnings:[MaterialValidationIssue] { issues.filter{$0.severity == .warning} }
    var canCalculate:Bool { errors.isEmpty }
}

enum MaterialRequirementValidator {
    static func validate(material:EngineeringMaterial, against set:MaterialRequirementSet, calculationTemperatureC:Double?=nil)->MaterialValidationResult { validate(materials:[material],against:set,calculationTemperatureC:calculationTemperatureC) }
    static func validate(materials:[EngineeringMaterial], against set:MaterialRequirementSet, calculationTemperatureC:Double?=nil)->MaterialValidationResult {
        var issues:[MaterialValidationIssue]=[]
        for material in materials { for requirement in set.requirements {
            let temperature=requirement.temperatureC ?? calculationTemperatureC
            let resolution=MaterialPropertyResolver.resolve(requirement.property,in:material,atTemperatureC:temperature)
            guard !resolution.isResolved else { continue }
            let severity:MaterialValidationSeverity=requirement.level == .required ? .error : .warning
            let reason:MaterialValidationIssueReason
            switch resolution.status {
            case .resolved: continue
            case .missing: reason = .missing
            case .temperatureRequired: reason = .temperatureRequired
            case .outsideAvailableRange(let min,let max): reason = .outsideAvailableRange(minimumC:min,maximumC:max)
            case .outsideEquationRange(let min,let max): reason = .outsideEquationRange(minimumC:min,maximumC:max)
            }
            issues.append(.init(materialID:material.id,materialName:material.name,property:requirement.property,severity:severity,reason:reason,temperatureC:temperature,purpose:requirement.purpose))
        }}
        return .init(requirementSetID:set.id,issues:issues)
    }
}

enum StandardMaterialRequirementSets {
    static let mass = MaterialRequirementSet(id:"mass",name:"Mass / weight",requirements:[.init(.density,purpose:"Material mass")])
    static let steadyStateConduction = MaterialRequirementSet(id:"steady-state-conduction",name:"Steady-state heat conduction",requirements:[.init(.thermalConductivity,purpose:"Conductive heat transfer")])
    static let transientThermal = MaterialRequirementSet(id:"transient-thermal",name:"Transient thermal calculation",requirements:[.init(.density,purpose:"Thermal mass"),.init(.specificHeatCapacity,purpose:"Thermal mass"),.init(.thermalConductivity,purpose:"Heat transfer")])
    static let linearElastic = MaterialRequirementSet(id:"linear-elastic",name:"Linear elastic calculation",requirements:[.init(.youngsModulus,purpose:"Elastic response"),.init(.poissonsRatio,purpose:"Elastic response")])
}
