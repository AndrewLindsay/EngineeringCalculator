import Foundation

enum EngineeringNumberFormatter {
    static func string(_ value: Double, significantDigits: Int = 4) -> String {
        guard value.isFinite else { return value.formatted() }
        if value == 0 { return "0" }
        let magnitude = abs(value)
        if magnitude < 0.001 || magnitude >= 1_000_000 {
            let exponent = Int(floor(log10(magnitude)))
            let coefficient = value / pow(10.0, Double(exponent))
            let coefficientText = coefficient.formatted(.number.precision(.significantDigits(1...significantDigits)))
            return "\(coefficientText) × 10\(superscript(exponent))"
        }
        return value.formatted(.number.precision(.significantDigits(1...significantDigits)).grouping(.automatic))
    }
    private static func superscript(_ value: Int) -> String { let map: [Character: Character] = ["-":"⁻","+":"⁺","0":"⁰","1":"¹","2":"²","3":"³","4":"⁴","5":"⁵","6":"⁶","7":"⁷","8":"⁸","9":"⁹"]; return String(String(value).compactMap { map[$0] }) }
    static func parse(_ text: String) -> Double? { let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "−", with: "-"); guard !cleaned.isEmpty else { return nil }; return Double(cleaned) }
    static func editableString(_ value: Double?) -> String { guard let value else { return "" }; return String(value) }
}

enum EngineeringDataSchema { static let currentVersion = 5 }

struct MaterialPropertyPoint: Identifiable, Hashable, Codable { var id: UUID = UUID(); var temperatureC: Double; var value: Double }

enum MaterialEquationKind: String, CaseIterable, Identifiable, Codable {
    case polynomial = "Polynomial"
    case linearReference = "Linear reference"
    case relativeLinear = "Relative linear / TCR"
    var id: Self { self }
    var formula: String { switch self { case .polynomial: return "y(T) = a + bT + cT² + dT³"; case .linearReference: return "y(T) = y₀ + k(T − T₀)"; case .relativeLinear: return "y(T) = y₀[1 + α(T − T₀)]" } }
}

/// Temperature correlation. `kind == nil` represents legacy polynomial data so
/// previously saved material libraries remain decodable without migration.
struct MaterialPropertyEquation: Hashable, Codable {
    var a: Double; var b: Double; var c: Double; var d: Double
    var minimumTemperatureC: Double?; var maximumTemperatureC: Double?; var allowsExtrapolation: Bool
    var kind: MaterialEquationKind?
    var referenceValue: Double?; var referenceTemperatureC: Double?; var slope: Double?; var temperatureCoefficient: Double?

    init(a: Double = 0, b: Double = 0, c: Double = 0, d: Double = 0, minimumTemperatureC: Double? = nil, maximumTemperatureC: Double? = nil, allowsExtrapolation: Bool = false, kind: MaterialEquationKind? = .polynomial, referenceValue: Double? = nil, referenceTemperatureC: Double? = nil, slope: Double? = nil, temperatureCoefficient: Double? = nil) {
        self.a=a; self.b=b; self.c=c; self.d=d; self.minimumTemperatureC=minimumTemperatureC; self.maximumTemperatureC=maximumTemperatureC; self.allowsExtrapolation=allowsExtrapolation; self.kind=kind; self.referenceValue=referenceValue; self.referenceTemperatureC=referenceTemperatureC; self.slope=slope; self.temperatureCoefficient=temperatureCoefficient
    }
    var effectiveKind: MaterialEquationKind { kind ?? .polynomial }
    func value(atTemperatureC t: Double) -> Double? {
        if !allowsExtrapolation { if let min=minimumTemperatureC, t < min { return nil }; if let max=maximumTemperatureC, t > max { return nil } }
        switch effectiveKind {
        case .polynomial: let t2=t*t; let t3=t2*t; return a + b*t + c*t2 + d*t3
        case .linearReference: guard let y0=referenceValue, let t0=referenceTemperatureC, let k=slope else { return nil }; return y0 + k*(t-t0)
        case .relativeLinear: guard let y0=referenceValue, let t0=referenceTemperatureC, let alpha=temperatureCoefficient else { return nil }; return y0 * (1 + alpha*(t-t0))
        }
    }
}

struct MaterialPropertySeries: Hashable, Codable {
    var referenceValue: Double?; var referenceTemperatureC: Double?; var temperatureTable: [MaterialPropertyPoint]; var equation: MaterialPropertyEquation?; var source: String?; var basis: String?
    init(referenceValue: Double? = nil, referenceTemperatureC: Double? = nil, temperatureTable: [MaterialPropertyPoint] = [], equation: MaterialPropertyEquation? = nil, source: String? = nil, basis: String? = nil) { self.referenceValue=referenceValue; self.referenceTemperatureC=referenceTemperatureC; self.temperatureTable=temperatureTable; self.equation=equation; self.source=source; self.basis=basis }
    func value(atTemperatureC t: Double) -> Double? { if let equation { return equation.value(atTemperatureC:t) }; let points=temperatureTable.sorted{$0.temperatureC<$1.temperatureC}; guard !points.isEmpty else{return referenceValue}; if points.count==1{return points[0].temperatureC==t ? points[0].value:nil}; guard t>=points[0].temperatureC,t<=points[points.count-1].temperatureC else{return nil}; if let exact=points.first(where:{$0.temperatureC==t}){return exact.value}; for i in 0..<(points.count-1){let lo=points[i],hi=points[i+1]; if t>lo.temperatureC && t<hi.temperatureC { let f=(t-lo.temperatureC)/(hi.temperatureC-lo.temperatureC); return lo.value+f*(hi.value-lo.value)}}; return nil }
}

struct EngineeringMaterial: Identifiable, Hashable, Codable {
    var id: UUID; var name:String; var category:String; var densityKgM3:Double?; var grade:String?; var isBuiltIn:Bool; var unsDesignation:String?; var standardDesignation:String?; var productForm:String?; var materialCondition:String?
    var thermalConductivityWMK:Double?; var specificHeatCapacityJkgK:Double?; var thermalExpansionMicrostrainPerK:Double?; var minimumServiceTemperatureC:Double?; var maximumServiceTemperatureC:Double?; var youngsModulusGPa:Double?; var poissonsRatio:Double?; var yieldStrengthMPa:Double?; var ultimateTensileStrengthMPa:Double?; var shearModulusGPa:Double?; var compressiveStrengthMPa:Double?; var electricalResistivityOhmM:Double?; var smysMPa:Double?; var smtsMPa:Double?
    var thermalConductivitySeries:MaterialPropertySeries?; var specificHeatCapacitySeries:MaterialPropertySeries?; var thermalExpansionSeries:MaterialPropertySeries?; var youngsModulusSeries:MaterialPropertySeries?; var poissonsRatioSeries:MaterialPropertySeries?; var yieldStrengthSeries:MaterialPropertySeries?; var ultimateTensileStrengthSeries:MaterialPropertySeries?; var shearModulusSeries:MaterialPropertySeries?; var electricalResistivitySeries:MaterialPropertySeries?; var source:String?; var notes:String?
    init(id:UUID=UUID(),name:String,category:String="General",densityKgM3:Double?=nil,grade:String?=nil,thermalConductivityWMK:Double?=nil,specificHeatCapacityJkgK:Double?=nil,thermalExpansionMicrostrainPerK:Double?=nil,minimumServiceTemperatureC:Double?=nil,maximumServiceTemperatureC:Double?=nil,youngsModulusGPa:Double?=nil,poissonsRatio:Double?=nil,yieldStrengthMPa:Double?=nil,ultimateTensileStrengthMPa:Double?=nil,shearModulusGPa:Double?=nil,compressiveStrengthMPa:Double?=nil,electricalResistivityOhmM:Double?=nil,source:String?=nil,notes:String?=nil,isBuiltIn:Bool=false,unsDesignation:String?=nil,standardDesignation:String?=nil,productForm:String?=nil,materialCondition:String?=nil,smysMPa:Double?=nil,smtsMPa:Double?=nil,thermalConductivitySeries:MaterialPropertySeries?=nil,specificHeatCapacitySeries:MaterialPropertySeries?=nil,thermalExpansionSeries:MaterialPropertySeries?=nil,youngsModulusSeries:MaterialPropertySeries?=nil,poissonsRatioSeries:MaterialPropertySeries?=nil,yieldStrengthSeries:MaterialPropertySeries?=nil,ultimateTensileStrengthSeries:MaterialPropertySeries?=nil,shearModulusSeries:MaterialPropertySeries?=nil,electricalResistivitySeries:MaterialPropertySeries?=nil) {
        self.id=id;self.name=name;self.category=category;self.densityKgM3=densityKgM3;self.grade=grade;self.isBuiltIn=isBuiltIn;self.unsDesignation=unsDesignation;self.standardDesignation=standardDesignation;self.productForm=productForm;self.materialCondition=materialCondition;self.thermalConductivityWMK=thermalConductivityWMK;self.specificHeatCapacityJkgK=specificHeatCapacityJkgK;self.thermalExpansionMicrostrainPerK=thermalExpansionMicrostrainPerK;self.minimumServiceTemperatureC=minimumServiceTemperatureC;self.maximumServiceTemperatureC=maximumServiceTemperatureC;self.youngsModulusGPa=youngsModulusGPa;self.poissonsRatio=poissonsRatio;self.yieldStrengthMPa=yieldStrengthMPa;self.ultimateTensileStrengthMPa=ultimateTensileStrengthMPa;self.shearModulusGPa=shearModulusGPa;self.compressiveStrengthMPa=compressiveStrengthMPa;self.electricalResistivityOhmM=electricalResistivityOhmM;self.smysMPa=smysMPa;self.smtsMPa=smtsMPa;self.thermalConductivitySeries=thermalConductivitySeries;self.specificHeatCapacitySeries=specificHeatCapacitySeries;self.thermalExpansionSeries=thermalExpansionSeries;self.youngsModulusSeries=youngsModulusSeries;self.poissonsRatioSeries=poissonsRatioSeries;self.yieldStrengthSeries=yieldStrengthSeries;self.ultimateTensileStrengthSeries=ultimateTensileStrengthSeries;self.shearModulusSeries=shearModulusSeries;self.electricalResistivitySeries=electricalResistivitySeries;self.source=source;self.notes=notes
    }
}

struct FluidDefinition: Identifiable, Hashable, Codable { var id:UUID;var name:String;var densityKgM3:Double;var thermalConductivityWMK:Double?;var specificHeatCapacityJkgK:Double?; init(id:UUID=UUID(),name:String,densityKgM3:Double,thermalConductivityWMK:Double?=nil,specificHeatCapacityJkgK:Double?=nil){self.id=id;self.name=name;self.densityKgM3=densityKgM3;self.thermalConductivityWMK=thermalConductivityWMK;self.specificHeatCapacityJkgK=specificHeatCapacityJkgK} }
struct PipeLayer: Identifiable, Hashable, Codable { var id:UUID;var name:String;var thicknessM:Double;var material:EngineeringMaterial; init(id:UUID=UUID(),name:String,thicknessM:Double,densityKgM3:Double){self.id=id;self.name=name;self.thicknessM=thicknessM;self.material=EngineeringMaterial(name:name,densityKgM3:densityKgM3)}; init(id:UUID=UUID(),name:String,thicknessM:Double,material:EngineeringMaterial){self.id=id;self.name=name;self.thicknessM=thicknessM;self.material=material}; var densityKgM3:Double{material.densityKgM3 ?? 0};var thermalConductivityWMK:Double?{material.thermalConductivityWMK};var specificHeatCapacityJkgK:Double?{material.specificHeatCapacityJkgK} }
struct PipeConstruction: Identifiable, Hashable, Codable { var id:UUID;var name:String;var internalDiameterM:Double;var layers:[PipeLayer];var internalFluid:FluidDefinition;var externalFluid:FluidDefinition; init(id:UUID=UUID(),name:String="Untitled Pipe",internalDiameterM:Double,layers:[PipeLayer],internalFluid:FluidDefinition,externalFluid:FluidDefinition){self.id=id;self.name=name;self.internalDiameterM=internalDiameterM;self.layers=layers;self.internalFluid=internalFluid;self.externalFluid=externalFluid} }
