import XCTest
@testable import EngineeringCalculator

final class MaterialRequirementValidatorTests: XCTestCase {
    func testCompleteTransientThermalMaterialPasses() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.complete,against:StandardMaterialRequirementSets.transientThermal,calculationTemperatureC:50)
        XCTAssertTrue(result.canCalculate); XCTAssertTrue(result.issues.isEmpty)
    }
    func testMissingDensityBlocksCalculation() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.missingDensity,against:StandardMaterialRequirementSets.transientThermal,calculationTemperatureC:50)
        XCTAssertFalse(result.canCalculate); XCTAssertEqual(result.errors.map(\.property),[.density])
    }
    func testMissingConductivityBlocksCalculation() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.missingK,against:StandardMaterialRequirementSets.transientThermal,calculationTemperatureC:50)
        XCTAssertFalse(result.canCalculate); XCTAssertEqual(result.errors.map(\.property),[.thermalConductivity])
    }
    func testMissingHeatCapacityBlocksCalculation() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.missingCp,against:StandardMaterialRequirementSets.transientThermal,calculationTemperatureC:50)
        XCTAssertFalse(result.canCalculate); XCTAssertEqual(result.errors.map(\.property),[.specificHeatCapacity])
    }
    func testMultipleMissingPropertiesAreReportedTogether() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.empty,against:StandardMaterialRequirementSets.transientThermal,calculationTemperatureC:50)
        XCTAssertEqual(Set(result.errors.map(\.property)),Set([.density,.specificHeatCapacity,.thermalConductivity])); XCTAssertEqual(result.errors.count,3)
    }
    func testTemperatureRequiredIsReported() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.tabulatedK,against:StandardMaterialRequirementSets.steadyStateConduction)
        XCTAssertFalse(result.canCalculate); XCTAssertEqual(result.errors.first?.reason,.temperatureRequired)
    }
    func testTableInsideRangePasses() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.tabulatedK,against:StandardMaterialRequirementSets.steadyStateConduction,calculationTemperatureC:50)
        XCTAssertTrue(result.canCalculate)
    }
    func testTableOutsideRangeBlocksCalculation() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.tabulatedK,against:StandardMaterialRequirementSets.steadyStateConduction,calculationTemperatureC:150)
        XCTAssertFalse(result.canCalculate); XCTAssertEqual(result.errors.first?.reason,.outsideAvailableRange(minimumC:0,maximumC:100))
    }
    func testEquationInsideRangePasses() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.equationK,against:StandardMaterialRequirementSets.steadyStateConduction,calculationTemperatureC:80)
        XCTAssertTrue(result.canCalculate)
    }
    func testEquationOutsideRangeBlocksWithoutExtrapolation() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.equationK,against:StandardMaterialRequirementSets.steadyStateConduction,calculationTemperatureC:150)
        XCTAssertFalse(result.canCalculate); XCTAssertEqual(result.errors.first?.reason,.outsideEquationRange(minimumC:0,maximumC:100))
    }
    func testEquationOutsideRangePassesWhenExtrapolationAllowed() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.extrapolatingK,against:StandardMaterialRequirementSets.steadyStateConduction,calculationTemperatureC:150)
        XCTAssertTrue(result.canCalculate)
    }
    func testOptionalMissingPropertyWarnsButDoesNotBlock() {
        let set=MaterialRequirementSet(id:"optional",name:"Optional",requirements:[.init(.density),.init(.youngsModulus,level:.optional)])
        let result=MaterialRequirementValidator.validate(material:Fixtures.densityOnly,against:set)
        XCTAssertTrue(result.canCalculate); XCTAssertEqual(result.warnings.count,1); XCTAssertEqual(result.warnings.first?.property,.youngsModulus)
    }
    func testOnlyInvalidMaterialInMultipleMaterialsIsNamed() {
        let result=MaterialRequirementValidator.validate(materials:[Fixtures.complete,Fixtures.missingDensity],against:StandardMaterialRequirementSets.transientThermal,calculationTemperatureC:50)
        XCTAssertFalse(result.canCalculate); XCTAssertEqual(result.errors.count,1); XCTAssertEqual(result.errors.first?.materialName,"Test - Missing Density")
    }
    func testLinearElasticRequiresYoungsModulusAndPoissonsRatio() {
        let result=MaterialRequirementValidator.validate(material:Fixtures.complete,against:StandardMaterialRequirementSets.linearElastic)
        XCTAssertTrue(result.canCalculate)
        let bad=MaterialRequirementValidator.validate(material:Fixtures.densityOnly,against:StandardMaterialRequirementSets.linearElastic)
        XCTAssertEqual(Set(bad.errors.map(\.property)),Set([.youngsModulus,.poissonsRatio]))
    }
}

private enum Fixtures {
    static let complete=EngineeringMaterial(name:"Test - Complete",densityKgM3:1000,thermalConductivityWMK:10,specificHeatCapacityJkgK:1000,youngsModulusGPa:100,poissonsRatio:0.3)
    static let densityOnly=EngineeringMaterial(name:"Test - Density Only",densityKgM3:1000)
    static let missingDensity=EngineeringMaterial(name:"Test - Missing Density",thermalConductivityWMK:10,specificHeatCapacityJkgK:1000)
    static let missingK=EngineeringMaterial(name:"Test - Missing Conductivity",densityKgM3:1000,specificHeatCapacityJkgK:1000)
    static let missingCp=EngineeringMaterial(name:"Test - Missing Heat Capacity",densityKgM3:1000,thermalConductivityWMK:10)
    static let empty=EngineeringMaterial(name:"Test - Empty")
    static let tabulatedK=EngineeringMaterial(name:"Test - Tabulated K",thermalConductivitySeries:MaterialPropertySeries(temperatureTable:[.init(temperatureC:0,value:10),.init(temperatureC:100,value:20)]))
    static let equationK=EngineeringMaterial(name:"Test - Equation K",thermalConductivitySeries:MaterialPropertySeries(equation:MaterialPropertyEquation(a:10,b:0.1,minimumTemperatureC:0,maximumTemperatureC:100,allowsExtrapolation:false)))
    static let extrapolatingK=EngineeringMaterial(name:"Test - Extrapolating K",thermalConductivitySeries:MaterialPropertySeries(equation:MaterialPropertyEquation(a:10,b:0.1,minimumTemperatureC:0,maximumTemperatureC:100,allowsExtrapolation:true)))
}
