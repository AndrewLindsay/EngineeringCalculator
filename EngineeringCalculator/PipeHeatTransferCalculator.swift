import Foundation

struct PipeHeatTransferLayer: Identifiable, Hashable {
    let id: UUID
    var name: String
    var thicknessM: Double
    var material: EngineeringMaterial
    init(id: UUID = UUID(), name: String? = nil, thicknessM: Double, material: EngineeringMaterial) {
        self.id=id; self.name=name ?? material.name; self.thicknessM=thicknessM; self.material=material
    }
}

struct PipeHeatTransferInput: Hashable {
    var internalDiameterM: Double
    var layers: [PipeHeatTransferLayer]
    var insideBoundaryTemperatureC: Double
    var outsideBoundaryTemperatureC: Double
    var lengthM: Double = 1.0
}

struct CalculatedPipeHeatTransferLayer: Identifiable, Hashable {
    let id: UUID; let name:String; let materialName:String
    let innerRadiusM:Double; let outerRadiusM:Double
    let evaluationTemperatureC:Double; let thermalConductivityWMK:Double
    let conductivityMethod:MaterialPropertyResolutionMethod?
    let resistanceKPerW:Double; let temperatureDropC:Double
    let innerBoundaryTemperatureC:Double; let outerBoundaryTemperatureC:Double
    let computationalCellCount:Int
    let minimumConductivityWMK:Double; let maximumConductivityWMK:Double
}

struct PipeHeatTransferResult: Hashable {
    let layers:[CalculatedPipeHeatTransferLayer]
    let finalOuterDiameterM:Double; let totalResistanceKPerW:Double
    let heatRateW:Double; let heatRatePerLengthWM:Double
    let refinementPasses:Int; let totalComputationalCells:Int
    let heatRateConvergenceFraction:Double
}

struct PipeHeatTransferLayerValidation: Identifiable, Hashable {
    let id:UUID; let layerName:String; let materialName:String; let evaluationTemperatureC:Double
    let result:MaterialValidationResult
    var canCalculate:Bool { result.canCalculate }
}
struct PipeHeatTransferValidation: Hashable {
    let layers:[PipeHeatTransferLayerValidation]
    var issues:[MaterialValidationIssue]{layers.flatMap{$0.result.issues}}
    var errors:[MaterialValidationIssue]{issues.filter{$0.severity == .error}}
    var canCalculate:Bool{errors.isEmpty}
}

enum PipeHeatTransferSolverFailure: Error {
    case thermalConductivityUnavailable(materialName:String, temperatureC:Double, status:MaterialPropertyResolutionStatus)
    case invalidThermalConductivity(materialName:String, temperatureC:Double)
    case invalidGeometry

    var message:String {
        switch self {
        case let .thermalConductivityUnavailable(materialName,t,status):
            switch status {
            case let .outsideAvailableRange(minimum,maximum):
                return "\(materialName) requires thermal conductivity at \(t.formatted(.number.precision(.fractionLength(0...2)))) °C for its calculated physical location. Available tabulated range: \(minimum.formatted(.number.precision(.fractionLength(0...2))))–\(maximum.formatted(.number.precision(.fractionLength(0...2)))) °C. Calculation has been blocked rather than extrapolating material data."
            case let .outsideEquationRange(minimum,maximum):
                let range:String
                switch (minimum,maximum) {
                case let (a?,b?): range="\(a.formatted())–\(b.formatted()) °C"
                case let (a?,nil): range="temperatures at or above \(a.formatted()) °C"
                case let (nil,b?): range="temperatures at or below \(b.formatted()) °C"
                default: range="the defined equation range"
                }
                return "\(materialName) thermal conductivity is required at \(t.formatted(.number.precision(.fractionLength(0...2)))) °C for its calculated physical location; the correlation is valid for \(range). Calculation has been blocked rather than extrapolating material data."
            case .missing: return "\(materialName) does not define thermal conductivity."
            case .temperatureRequired: return "\(materialName) thermal conductivity requires a temperature."
            case .resolved: return "\(materialName) thermal conductivity could not be resolved at \(t.formatted()) °C."
            }
        case let .invalidThermalConductivity(materialName,t): return "\(materialName) returned an invalid thermal conductivity at \(t.formatted(.number.precision(.fractionLength(0...2)))) °C."
        case .invalidGeometry: return "The adaptive heat-transfer solution encountered invalid geometry or resistance data."
        }
    }
}

struct ValidatedPipeHeatTransferResult {
    let validation:PipeHeatTransferValidation
    let result:PipeHeatTransferResult?
    let solverFailure:PipeHeatTransferSolverFailure?
    var canCalculate:Bool{validation.canCalculate && result != nil}
    init(validation:PipeHeatTransferValidation,result:PipeHeatTransferResult?,solverFailure:PipeHeatTransferSolverFailure? = nil){self.validation=validation;self.result=result;self.solverFailure=solverFailure}
}

enum PipeHeatTransferCalculator {
    static let requirements=MaterialRequirementSet(id:"pipe-radial-conduction",name:"Multilayer pipe radial heat transfer",requirements:[.init(.thermalConductivity,purpose:"Radial heat conduction")])
    static let maximumRelativeConductivityVariation = 0.01
    static let heatRateConvergenceTolerance = 1.0e-6
    static let maximumRefinementPasses = 12
    static let maximumCellsPerPhysicalLayer = 4096

    static func propertyEvaluationTemperatureC(for input:PipeHeatTransferInput)->Double{(input.insideBoundaryTemperatureC+input.outsideBoundaryTemperatureC)/2}

    // Heat-transfer range validity is location-dependent.  This preflight check therefore
    // verifies only that conductivity data exist.  Actual temperature-range validity is
    // checked by the adaptive solution at the temperatures experienced by each layer.
    static func validateMaterials(input:PipeHeatTransferInput)->PipeHeatTransferValidation{
        let displayT=propertyEvaluationTemperatureC(for:input)
        return PipeHeatTransferValidation(layers:input.layers.map{ layer in
            let hasK=MaterialPropertyResolver.availableProperties(in:layer.material).contains(.thermalConductivity)
            let issues:[MaterialValidationIssue]
            if hasK { issues=[] }
            else { issues=[.init(materialID:layer.material.id,materialName:layer.material.name,property:.thermalConductivity,severity:.error,reason:.missing,temperatureC:nil,purpose:"Radial heat conduction")] }
            return .init(id:layer.id,layerName:layer.name,materialName:layer.material.name,evaluationTemperatureC:displayT,result:.init(requirementSetID:requirements.id,issues:issues))
        })
    }

    private struct Cell { let layerIndex:Int; let innerRadius:Double; let outerRadius:Double; var meanTemperature:Double; var k:Double; var method:MaterialPropertyResolutionMethod?; var resistance:Double; var innerTemperature:Double; var outerTemperature:Double }
    private struct SolveFailure: Error { let failure:PipeHeatTransferSolverFailure }

    private static func boundedPhysicalTemperature(_ temperature:Double,input:PipeHeatTransferInput)->Double {
        let lower=min(input.insideBoundaryTemperatureC,input.outsideBoundaryTemperatureC), upper=max(input.insideBoundaryTemperatureC,input.outsideBoundaryTemperatureC)
        let scale=max(1.0,max(abs(lower),abs(upper))), tolerance=64.0*Double.ulpOfOne*scale
        if temperature < lower && lower-temperature <= tolerance { return lower }
        if temperature > upper && temperature-upper <= tolerance { return upper }
        return temperature
    }

    private static func conductivity(_ material:EngineeringMaterial,at temperature:Double,input:PipeHeatTransferInput)throws->MaterialPropertyResolution {
        let t=boundedPhysicalTemperature(temperature,input:input)
        let r=MaterialPropertyResolver.resolve(.thermalConductivity,in:material,atTemperatureC:t)
        guard let k=r.value else { throw SolveFailure(failure:.thermalConductivityUnavailable(materialName:material.name,temperatureC:t,status:r.status)) }
        guard k>0,k.isFinite else { throw SolveFailure(failure:.invalidThermalConductivity(materialName:material.name,temperatureC:t)) }
        return r
    }

    // Bootstrap only: if the first global temperature estimate lies outside a material's
    // data range, use the nearest valid endpoint to obtain an initial resistance.  This is
    // not accepted as a final property evaluation; all subsequent iterations are strict.
    private static func seedConductivity(_ material:EngineeringMaterial,at temperature:Double,input:PipeHeatTransferInput)throws->MaterialPropertyResolution {
        let t=boundedPhysicalTemperature(temperature,input:input)
        let initial=MaterialPropertyResolver.resolve(.thermalConductivity,in:material,atTemperatureC:t)
        if initial.value != nil { return initial }
        let boundedT:Double?
        switch initial.status {
        case let .outsideAvailableRange(minimum,maximum): boundedT=min(max(t,minimum),maximum)
        case let .outsideEquationRange(minimum,maximum):
            var candidate=t
            if let minimum { candidate=max(candidate,minimum) }
            if let maximum { candidate=min(candidate,maximum) }
            boundedT=candidate
        default: boundedT=nil
        }
        guard let boundedT else { throw SolveFailure(failure:.thermalConductivityUnavailable(materialName:material.name,temperatureC:t,status:initial.status)) }
        let seeded=MaterialPropertyResolver.resolve(.thermalConductivity,in:material,atTemperatureC:boundedT)
        guard let k=seeded.value else { throw SolveFailure(failure:.thermalConductivityUnavailable(materialName:material.name,temperatureC:t,status:initial.status)) }
        guard k>0,k.isFinite else { throw SolveFailure(failure:.invalidThermalConductivity(materialName:material.name,temperatureC:boundedT)) }
        return seeded
    }

    static func validatedCalculate(input:PipeHeatTransferInput)->ValidatedPipeHeatTransferResult{
        let validation=validateMaterials(input:input)
        guard validation.canCalculate,input.internalDiameterM>0,input.lengthM>0,!input.layers.isEmpty,input.layers.allSatisfy({$0.thicknessM>0}) else{return .init(validation:validation,result:nil)}
        var counts=Array(repeating:1,count:input.layers.count), previousQ:Double?, convergence=Double.infinity, finalCells:[Cell]=[]; var passes=0
        do {
            for pass in 0..<maximumRefinementPasses {
                passes=pass+1
                let solved=try solve(input:input,cellCounts:counts); finalCells=solved.cells
                if let q0=previousQ { convergence=abs(solved.q-q0)/max(abs(solved.q),1e-12) }
                var refine=Array(repeating:false,count:input.layers.count)
                for cell in solved.cells {
                    let material=input.layers[cell.layerIndex].material
                    let inner=try conductivity(material,at:cell.innerTemperature,input:input), outer=try conductivity(material,at:cell.outerTemperature,input:input)
                    let ki=inner.value!, ko=outer.value!, relative=abs(ki-ko)/max(abs(cell.k),1e-12)
                    if relative > maximumRelativeConductivityVariation { refine[cell.layerIndex]=true }
                }
                let needsRefinement=refine.contains(true)
                if !needsRefinement || (previousQ != nil && convergence < heatRateConvergenceTolerance) { break }
                for i in counts.indices where refine[i] { counts[i]=min(counts[i]*2,maximumCellsPerPhysicalLayer) }
                previousQ=solved.q
            }
        } catch let error as SolveFailure { return .init(validation:validation,result:nil,solverFailure:error.failure) }
          catch { return .init(validation:validation,result:nil,solverFailure:.invalidGeometry) }

        guard !finalCells.isEmpty else{return .init(validation:validation,result:nil,solverFailure:.invalidGeometry)}
        let totalR=finalCells.reduce(0){$0+$1.resistance}; guard totalR>0,totalR.isFinite else{return .init(validation:validation,result:nil,solverFailure:.invalidGeometry)}
        let deltaT=input.insideBoundaryTemperatureC-input.outsideBoundaryTemperatureC, q=deltaT/totalR
        var calculated:[CalculatedPipeHeatTransferLayer]=[]
        for (index,layer) in input.layers.enumerated(){
            let cells=finalCells.filter{$0.layerIndex==index}; guard let first=cells.first,let last=cells.last else{return .init(validation:validation,result:nil,solverFailure:.invalidGeometry)}
            let r=cells.reduce(0){$0+$1.resistance}, weightedK=cells.reduce(0.0){$0+$1.k*$1.resistance}/max(r,1e-30), evalT=cells.reduce(0.0){$0+$1.meanTemperature*$1.resistance}/max(r,1e-30)
            calculated.append(.init(id:layer.id,name:layer.name,materialName:layer.material.name,innerRadiusM:first.innerRadius,outerRadiusM:last.outerRadius,evaluationTemperatureC:evalT,thermalConductivityWMK:weightedK,conductivityMethod:cells.count==1 ? first.method:nil,resistanceKPerW:r,temperatureDropC:q*r,innerBoundaryTemperatureC:boundedPhysicalTemperature(first.innerTemperature,input:input),outerBoundaryTemperatureC:boundedPhysicalTemperature(last.outerTemperature,input:input),computationalCellCount:cells.count,minimumConductivityWMK:cells.map(\.k).min() ?? weightedK,maximumConductivityWMK:cells.map(\.k).max() ?? weightedK))
        }
        let outer=finalCells.last!.outerRadius
        return .init(validation:validation,result:.init(layers:calculated,finalOuterDiameterM:2*outer,totalResistanceKPerW:totalR,heatRateW:q,heatRatePerLengthWM:q/input.lengthM,refinementPasses:passes,totalComputationalCells:finalCells.count,heatRateConvergenceFraction:convergence.isFinite ? convergence:0))
    }

    private static func solve(input:PipeHeatTransferInput,cellCounts:[Int])throws->(cells:[Cell],q:Double){
        var cells:[Cell]=[], radius=input.internalDiameterM/2; let globalMean=propertyEvaluationTemperatureC(for:input)
        for (li,layer) in input.layers.enumerated(){
            let n=max(1,cellCounts[li]), r0=radius, r1=r0+layer.thicknessM; guard r0>0,r1>r0 else{throw SolveFailure(failure:.invalidGeometry)}
            for j in 0..<n {
                let f0=Double(j)/Double(n), f1=Double(j+1)/Double(n), ri=r0*pow(r1/r0,f0), ro=r0*pow(r1/r0,f1)
                let resolution=try seedConductivity(layer.material,at:globalMean,input:input), k=resolution.value!
                cells.append(.init(layerIndex:li,innerRadius:ri,outerRadius:ro,meanTemperature:globalMean,k:k,method:resolution.method,resistance:log(ro/ri)/(2*Double.pi*k*input.lengthM),innerTemperature:globalMean,outerTemperature:globalMean))
            }; radius=r1
        }
        var lastQ:Double?
        for _ in 0..<100 {
            let totalR=cells.reduce(0){$0+$1.resistance}; guard totalR>0,totalR.isFinite else{throw SolveFailure(failure:.invalidGeometry)}
            let q=(input.insideBoundaryTemperatureC-input.outsideBoundaryTemperatureC)/totalR; var t=input.insideBoundaryTemperatureC, maxKChange=0.0
            for i in cells.indices {
                let oldK=cells[i].k, tout=t-q*cells[i].resistance, mean=(t+tout)/2, material=input.layers[cells[i].layerIndex].material
                let resolution=try conductivity(material,at:mean,input:input), targetK=resolution.value!, newK=0.5*oldK+0.5*targetK
                maxKChange=max(maxKChange,abs(newK-oldK)/max(abs(newK),1e-12)); cells[i].innerTemperature=t; cells[i].outerTemperature=tout; cells[i].meanTemperature=mean; cells[i].k=newK; cells[i].method=resolution.method; cells[i].resistance=log(cells[i].outerRadius/cells[i].innerRadius)/(2*Double.pi*newK*input.lengthM); t=tout
            }
            if let q0=lastQ,abs(q-q0)/max(abs(q),1e-12)<1e-9 && maxKChange<1e-9 {
                let rr=cells.reduce(0){$0+$1.resistance}, qf=(input.insideBoundaryTemperatureC-input.outsideBoundaryTemperatureC)/rr; var tf=input.insideBoundaryTemperatureC
                for i in cells.indices { let to=tf-qf*cells[i].resistance; cells[i].innerTemperature=tf;cells[i].outerTemperature=to;cells[i].meanTemperature=(tf+to)/2;tf=to }
                // Final strict boundary check: a successful solution must not rely on extrapolation.
                for cell in cells { let material=input.layers[cell.layerIndex].material; _=try conductivity(material,at:cell.innerTemperature,input:input); _=try conductivity(material,at:cell.outerTemperature,input:input) }
                return(cells,qf)
            }; lastQ=q
        }
        let rr=cells.reduce(0){$0+$1.resistance}; guard rr>0 else{throw SolveFailure(failure:.invalidGeometry)}; let q=(input.insideBoundaryTemperatureC-input.outsideBoundaryTemperatureC)/rr; var t=input.insideBoundaryTemperatureC
        for i in cells.indices{let to=t-q*cells[i].resistance;cells[i].innerTemperature=t;cells[i].outerTemperature=to;cells[i].meanTemperature=(t+to)/2;t=to}
        for cell in cells { let material=input.layers[cell.layerIndex].material; _=try conductivity(material,at:cell.innerTemperature,input:input); _=try conductivity(material,at:cell.outerTemperature,input:input) }
        return(cells,q)
    }
}
