import XCTest
@testable import EngineeringCalculator

final class PipeHeatTransferCalculatorTests: XCTestCase {
    private let k10=EngineeringMaterial(name:"TEST k=10",category:"Validation",thermalConductivityWMK:10)
    private let k20=EngineeringMaterial(name:"TEST k=20",category:"Validation",thermalConductivityWMK:20)
    private let densityOnly=EngineeringMaterial(name:"TEST Missing k",category:"Validation",densityKgM3:1000)
    private let lowK=EngineeringMaterial(name:"TEST Low k",category:"Validation",thermalConductivityWMK:0.05)
    private var tabulated:EngineeringMaterial{EngineeringMaterial(name:"TEST Table k",category:"Validation",thermalConductivitySeries:MaterialPropertySeries(temperatureTable:[.init(temperatureC:0,value:10),.init(temperatureC:50,value:15),.init(temperatureC:100,value:20)]))}
    private var steep:EngineeringMaterial{EngineeringMaterial(name:"TEST Steep k(T)",category:"Validation",thermalConductivitySeries:MaterialPropertySeries(temperatureTable:[.init(temperatureC:0,value:1),.init(temperatureC:100,value:5)]))}
    private var limited:EngineeringMaterial{EngineeringMaterial(name:"TEST Limited k(T)",category:"Validation",thermalConductivitySeries:MaterialPropertySeries(temperatureTable:[.init(temperatureC:20,value:0.8),.init(temperatureC:40,value:0.9),.init(temperatureC:60,value:1.0)]))}
    private var coldLimited:EngineeringMaterial{EngineeringMaterial(name:"TEST Cold Limited k(T)",category:"Validation",thermalConductivitySeries:MaterialPropertySeries(temperatureTable:[.init(temperatureC:0,value:1.0),.init(temperatureC:25,value:1.05),.init(temperatureC:50,value:1.1)]))}
    private func input(layers:[PipeHeatTransferLayer],inside:Double=100,outside:Double=0,length:Double=1)->PipeHeatTransferInput{.init(internalDiameterM:0.300,layers:layers,insideBoundaryTemperatureC:inside,outsideBoundaryTemperatureC:outside,lengthM:length)}

    func testSingleLayerConstantKMatchesAnalyticalResistance() throws {let result=try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.020,material:k10)])).result);let r=log(0.170/0.150)/(2*Double.pi*10);XCTAssertEqual(result.totalResistanceKPerW,r,accuracy:1e-12);XCTAssertEqual(result.heatRateW,100/r,accuracy:1e-8);XCTAssertEqual(result.finalOuterDiameterM,0.340,accuracy:1e-12);XCTAssertEqual(result.totalComputationalCells,1)}
    func testTwoLayerResistanceIsSumOfCylindricalResistances() throws {let result=try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.010,material:k10),.init(thicknessM:0.020,material:k20)])).result);let r1=log(0.160/0.150)/(2*Double.pi*10),r2=log(0.180/0.160)/(2*Double.pi*20);XCTAssertEqual(result.totalResistanceKPerW,r1+r2,accuracy:1e-12);XCTAssertEqual(result.heatRateW,100/(r1+r2),accuracy:1e-8)}
    func testMissingConductivityBlocksCalculation(){let v=PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(name:"Insulation",thicknessM:0.020,material:densityOnly)]));XCTAssertFalse(v.canCalculate);XCTAssertNil(v.result);XCTAssertEqual(v.validation.errors.first?.property,.thermalConductivity);XCTAssertEqual(v.validation.layers.first?.layerName,"Insulation")}
    func testDensityIsNotRequiredForHeatConduction(){XCTAssertTrue(PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.020,material:k10)])).canCalculate)}
    func testTemperatureDependentSingleLayerUsesAdaptiveCells() throws {let r=try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.100,material:steep)])).result);XCTAssertGreaterThan(r.layers[0].computationalCellCount,1);XCTAssertGreaterThan(r.layers[0].maximumConductivityWMK,r.layers[0].minimumConductivityWMK);XCTAssertEqual(r.layers[0].innerBoundaryTemperatureC,100,accuracy:1e-7);XCTAssertEqual(r.layers[0].outerBoundaryTemperatureC,0,accuracy:1e-7)}
    func testLinearKSingleLayerMatchesConductivityIntegral(){let model=input(layers:[.init(thicknessM:0.100,material:steep)]);let v=PipeHeatTransferCalculator.validatedCalculate(input:model);guard let r=v.result else{return XCTFail("Expected adaptive result")};let integralK=300.0;let expected=2*Double.pi*model.lengthM*integralK/log(0.250/0.150);XCTAssertEqual(r.heatRateW,expected,accuracy:expected*0.003)}
    func testConstantKThickLayerDoesNotNeedSubdivision() throws {let r=try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.500,material:k10)])).result);XCTAssertEqual(r.layers[0].computationalCellCount,1)}
    func testAdaptiveLayerTemperaturesRemainContinuous() throws {let r=try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.020,material:k10),.init(thicknessM:0.100,material:steep)])).result);XCTAssertEqual(r.layers[0].outerBoundaryTemperatureC,r.layers[1].innerBoundaryTemperatureC,accuracy:1e-7);XCTAssertEqual(r.layers.reduce(0){$0+$1.temperatureDropC},100,accuracy:1e-6)}
    func testAdaptiveSolverReportsConvergenceMetadata() throws {let r=try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.100,material:steep)])).result);XCTAssertGreaterThanOrEqual(r.refinementPasses,1);XCTAssertGreaterThanOrEqual(r.totalComputationalCells,1);XCTAssertGreaterThanOrEqual(r.heatRateConvergenceFraction,0)}
    func testOutOfRangeAtBoundaryBlocksAdaptiveCalculation(){let v=PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.020,material:tabulated)],inside:120,outside:20));XCTAssertFalse(v.canCalculate);XCTAssertNil(v.result)}
    func testLimitedRangeReturnsSpecificAdaptiveDiagnostic(){let v=PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.100,material:limited)],inside:100,outside:0));XCTAssertFalse(v.canCalculate);XCTAssertNil(v.result);guard case let .thermalConductivityUnavailable(name,t,status)?=v.solverFailure else{return XCTFail("Expected thermal-conductivity range failure")};XCTAssertEqual(name,"TEST Limited k(T)");XCTAssertTrue(t<20 || t>60);guard case let .outsideAvailableRange(a,b)=status else{return XCTFail("Expected outsideAvailableRange")};XCTAssertEqual(a,20);XCTAssertEqual(b,60);XCTAssertTrue(v.solverFailure?.message.contains("blocked rather than extrapolating") == true)}
    func testSteepValidRangeDoesNotProduceSolverFailure() throws {let v=PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.100,material:steep)],inside:100,outside:0));XCTAssertNil(v.solverFailure);let r=try XCTUnwrap(v.result);XCTAssertGreaterThan(r.totalComputationalCells,1)}
    func testTabulatedConductivityAtUniformMeanCase() throws {let result=try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.020,material:tabulated)],inside:100,outside:0)).result);XCTAssertGreaterThan(result.layers[0].thermalConductivityWMK,10);XCTAssertLessThan(result.layers[0].thermalConductivityWMK,20)}
    func testLayerTemperatureDropsSumToSpecifiedBoundaryDifference() throws {let result=try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.010,material:k10),.init(thicknessM:0.020,material:k20)],inside:120,outside:20)).result);XCTAssertEqual(result.layers.reduce(0){$0+$1.temperatureDropC},100,accuracy:1e-8);XCTAssertEqual(result.layers.last?.outerBoundaryTemperatureC ?? .nan,20,accuracy:1e-8)}
    func testHeatRateScalesWithLengthButHeatRatePerLengthDoesNot() throws {let one=try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.020,material:k10)],length:1)).result);let five=try XCTUnwrap(PipeHeatTransferCalculator.validatedCalculate(input:input(layers:[.init(thicknessM:0.020,material:k10)],length:5)).result);XCTAssertEqual(five.heatRateW,one.heatRateW*5,accuracy:1e-7);XCTAssertEqual(five.heatRatePerLengthWM,one.heatRatePerLengthWM,accuracy:1e-7)}

    func testColdLimitedMaterialIsAcceptedWhenOuterLayerStaysWithinRange() throws {
        let model=input(layers:[.init(name:"Inner insulation",thicknessM:0.100,material:lowK),.init(name:"Cold outer layer",thicknessM:0.020,material:coldLimited)],inside:100,outside:0)
        let validated=PipeHeatTransferCalculator.validatedCalculate(input:model)
        XCTAssertTrue(validated.validation.canCalculate,"Preflight validation should not reject a material merely because the global mean temperature is outside its range")
        XCTAssertNil(validated.solverFailure)
        let result=try XCTUnwrap(validated.result)
        let outer=result.layers[1]
        XCTAssertLessThanOrEqual(outer.innerBoundaryTemperatureC,50.0)
        XCTAssertGreaterThanOrEqual(outer.outerBoundaryTemperatureC,0.0)
    }

    func testColdLimitedMaterialFailsWhenItsPhysicalLayerExceedsRange() {
        let model=input(layers:[.init(name:"Cold limited inner layer",thicknessM:0.020,material:coldLimited),.init(name:"Outer insulation",thicknessM:0.100,material:lowK)],inside:100,outside:0)
        let validated=PipeHeatTransferCalculator.validatedCalculate(input:model)
        XCTAssertTrue(validated.validation.canCalculate,"Range checking belongs to the solved physical layer temperatures")
        XCTAssertNil(validated.result)
        guard case let .thermalConductivityUnavailable(name,t,status)?=validated.solverFailure else { return XCTFail("Expected local temperature-range failure") }
        XCTAssertEqual(name,"TEST Cold Limited k(T)")
        XCTAssertGreaterThan(t,50.0)
        guard case let .outsideAvailableRange(minimum,maximum)=status else { return XCTFail("Expected outsideAvailableRange") }
        XCTAssertEqual(minimum,0.0)
        XCTAssertEqual(maximum,50.0)
    }

    // Paired regression: identical geometry/materials/boundaries, only layer order changes.
    // The 20–60 °C material is valid as the cold outer layer, but invalid on the hot side.
    func testLimitedRangeOuterLayerSolvesAfterLocationAwareRefinement() throws {
        let model=input(layers:[.init(name:"Constant inner",thicknessM:0.030,material:EngineeringMaterial(name:"TEST Constant Thermal k",category:"Validation",thermalConductivityWMK:1.0)),.init(name:"Limited outer",thicknessM:0.020,material:limited)],inside:120,outside:20)
        let validated=PipeHeatTransferCalculator.validatedCalculate(input:model)
        XCTAssertNil(validated.solverFailure)
        let result=try XCTUnwrap(validated.result)
        XCTAssertEqual(result.layers.count,2)
        XCTAssertLessThanOrEqual(result.layers[1].innerBoundaryTemperatureC,60.0,accuracy:1e-6)
        XCTAssertGreaterThanOrEqual(result.layers[1].outerBoundaryTemperatureC,20.0,accuracy:1e-6)
        XCTAssertGreaterThanOrEqual(result.layers[1].computationalCellCount,2)
    }

    func testLimitedRangeInnerLayerFailsForSamePhysicalSystem() {
        let model=input(layers:[.init(name:"Limited inner",thicknessM:0.020,material:limited),.init(name:"Constant outer",thicknessM:0.030,material:EngineeringMaterial(name:"TEST Constant Thermal k",category:"Validation",thermalConductivityWMK:1.0))],inside:120,outside:20)
        let validated=PipeHeatTransferCalculator.validatedCalculate(input:model)
        XCTAssertNil(validated.result)
        guard case let .thermalConductivityUnavailable(name,t,status)?=validated.solverFailure else{return XCTFail("Expected local temperature-range failure")}
        XCTAssertEqual(name,"TEST Limited k(T)")
        XCTAssertGreaterThan(t,60.0)
        guard case let .outsideAvailableRange(minimum,maximum)=status else{return XCTFail("Expected outsideAvailableRange")}
        XCTAssertEqual(minimum,20.0)
        XCTAssertEqual(maximum,60.0)
    }
}
