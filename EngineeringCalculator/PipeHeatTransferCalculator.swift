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
struct ValidatedPipeHeatTransferResult { let validation:PipeHeatTransferValidation; let result:PipeHeatTransferResult?; var canCalculate:Bool{validation.canCalculate && result != nil} }

enum PipeHeatTransferCalculator {
    static let requirements=MaterialRequirementSet(id:"pipe-radial-conduction",name:"Multilayer pipe radial heat transfer",requirements:[.init(.thermalConductivity,purpose:"Radial heat conduction")])

    // Adaptive-solver controls. A cell is refined when conductivity changes by more than 1%
    // across its current temperature span. Refinement also stops when heat rate changes by < 1e-6.
    static let maximumRelativeConductivityVariation = 0.01
    static let heatRateConvergenceTolerance = 1.0e-6
    static let maximumRefinementPasses = 12
    static let maximumCellsPerPhysicalLayer = 4096

    static func propertyEvaluationTemperatureC(for input:PipeHeatTransferInput)->Double{(input.insideBoundaryTemperatureC+input.outsideBoundaryTemperatureC)/2}

    static func validateMaterials(input:PipeHeatTransferInput)->PipeHeatTransferValidation{
        let t=propertyEvaluationTemperatureC(for:input)
        return PipeHeatTransferValidation(layers:input.layers.map{layer in
            PipeHeatTransferLayerValidation(id:layer.id,layerName:layer.name,materialName:layer.material.name,evaluationTemperatureC:t,result:MaterialRequirementValidator.validate(material:layer.material,against:requirements,calculationTemperatureC:t))
        })
    }

    private struct Cell {
        let layerIndex:Int; let innerRadius:Double; let outerRadius:Double
        var meanTemperature:Double; var k:Double; var method:MaterialPropertyResolutionMethod?
        var resistance:Double; var innerTemperature:Double; var outerTemperature:Double
    }

    // Temperature sweeps can finish a few ulps beyond an imposed boundary because many
    // resistance drops are accumulated. Clamp only to the physical boundary interval before
    // resolving endpoint properties. This removes floating-point excursions without permitting
    // extrapolation beyond the temperatures actually specified by the user.
    private static func boundedPhysicalTemperature(_ temperature:Double,input:PipeHeatTransferInput)->Double {
        let lower=min(input.insideBoundaryTemperatureC,input.outsideBoundaryTemperatureC)
        let upper=max(input.insideBoundaryTemperatureC,input.outsideBoundaryTemperatureC)
        let scale=max(1.0,max(abs(lower),abs(upper)))
        let tolerance=64.0*Double.ulpOfOne*scale
        if temperature < lower && lower-temperature <= tolerance { return lower }
        if temperature > upper && temperature-upper <= tolerance { return upper }
        return temperature
    }

    static func validatedCalculate(input:PipeHeatTransferInput)->ValidatedPipeHeatTransferResult{
        let validation=validateMaterials(input:input)
        guard validation.canCalculate,input.internalDiameterM>0,input.lengthM>0,!input.layers.isEmpty,input.layers.allSatisfy({$0.thicknessM>0}) else{return .init(validation:validation,result:nil)}

        var counts=Array(repeating:1,count:input.layers.count)
        var previousQ:Double?
        var convergence=Double.infinity
        var finalCells:[Cell]=[]
        var passes=0

        for pass in 0..<maximumRefinementPasses {
            passes=pass+1
            guard let solved=solve(input:input,cellCounts:counts) else{return .init(validation:validation,result:nil)}
            finalCells=solved.cells
            if let q0=previousQ { convergence=abs(solved.q-q0)/max(abs(solved.q),1e-12) }

            var refine=Array(repeating:false,count:input.layers.count)
            for cell in solved.cells {
                let material=input.layers[cell.layerIndex].material
                let innerT=boundedPhysicalTemperature(cell.innerTemperature,input:input)
                let outerT=boundedPhysicalTemperature(cell.outerTemperature,input:input)
                let inner=MaterialPropertyResolver.resolve(.thermalConductivity,in:material,atTemperatureC:innerT)
                let outer=MaterialPropertyResolver.resolve(.thermalConductivity,in:material,atTemperatureC:outerT)
                guard let ki=inner.value,let ko=outer.value,ki>0,ko>0 else{return .init(validation:validation,result:nil)}
                let relative=abs(ki-ko)/max(abs(cell.k),1e-12)
                if relative > maximumRelativeConductivityVariation { refine[cell.layerIndex]=true }
            }

            let needsRefinement=refine.contains(true)
            if !needsRefinement || (previousQ != nil && convergence < heatRateConvergenceTolerance) { break }
            for i in counts.indices where refine[i] { counts[i]=min(counts[i]*2,maximumCellsPerPhysicalLayer) }
            previousQ=solved.q
        }

        guard !finalCells.isEmpty else{return .init(validation:validation,result:nil)}
        let totalR=finalCells.reduce(0){$0+$1.resistance}
        let deltaT=input.insideBoundaryTemperatureC-input.outsideBoundaryTemperatureC
        let q=deltaT/totalR
        var calculated:[CalculatedPipeHeatTransferLayer]=[]
        for (index,layer) in input.layers.enumerated(){
            let cells=finalCells.filter{$0.layerIndex==index}
            guard let first=cells.first,let last=cells.last else{return .init(validation:validation,result:nil)}
            let r=cells.reduce(0){$0+$1.resistance}
            let weightedK=cells.reduce(0.0){$0+$1.k*$1.resistance}/max(r,1e-30)
            let evalT=cells.reduce(0.0){$0+$1.meanTemperature*$1.resistance}/max(r,1e-30)
            calculated.append(.init(id:layer.id,name:layer.name,materialName:layer.material.name,innerRadiusM:first.innerRadius,outerRadiusM:last.outerRadius,evaluationTemperatureC:evalT,thermalConductivityWMK:weightedK,conductivityMethod:cells.count==1 ? first.method:nil,resistanceKPerW:r,temperatureDropC:q*r,innerBoundaryTemperatureC:boundedPhysicalTemperature(first.innerTemperature,input:input),outerBoundaryTemperatureC:boundedPhysicalTemperature(last.outerTemperature,input:input),computationalCellCount:cells.count,minimumConductivityWMK:cells.map(\.k).min() ?? weightedK,maximumConductivityWMK:cells.map(\.k).max() ?? weightedK))
        }
        let outer=finalCells.last!.outerRadius
        return .init(validation:validation,result:.init(layers:calculated,finalOuterDiameterM:2*outer,totalResistanceKPerW:totalR,heatRateW:q,heatRatePerLengthWM:q/input.lengthM,refinementPasses:passes,totalComputationalCells:finalCells.count,heatRateConvergenceFraction:convergence.isFinite ? convergence:0))
    }

    private static func solve(input:PipeHeatTransferInput,cellCounts:[Int])->(cells:[Cell],q:Double)?{
        var cells:[Cell]=[]; var radius=input.internalDiameterM/2
        let globalMean=propertyEvaluationTemperatureC(for:input)
        for (li,layer) in input.layers.enumerated(){
            let n=max(1,cellCounts[li]); let r0=radius; let r1=r0+layer.thicknessM
            for j in 0..<n {
                let f0=Double(j)/Double(n), f1=Double(j+1)/Double(n)
                let ri=r0*pow(r1/r0,f0), ro=r0*pow(r1/r0,f1)
                let resolution=MaterialPropertyResolver.resolve(.thermalConductivity,in:layer.material,atTemperatureC:globalMean)
                guard let k=resolution.value,k>0 else{return nil}
                cells.append(.init(layerIndex:li,innerRadius:ri,outerRadius:ro,meanTemperature:globalMean,k:k,method:resolution.method,resistance:log(ro/ri)/(2*Double.pi*k*input.lengthM),innerTemperature:globalMean,outerTemperature:globalMean))
            }
            radius=r1
        }

        var lastQ:Double?
        for _ in 0..<100 {
            let totalR=cells.reduce(0){$0+$1.resistance}; guard totalR>0 else{return nil}
            let q=(input.insideBoundaryTemperatureC-input.outsideBoundaryTemperatureC)/totalR
            var t=input.insideBoundaryTemperatureC
            var maxKChange=0.0
            for i in cells.indices {
                let oldK=cells[i].k
                let tout=t-q*cells[i].resistance
                let mean=(t+tout)/2
                let material=input.layers[cells[i].layerIndex].material
                let resolution=MaterialPropertyResolver.resolve(.thermalConductivity,in:material,atTemperatureC:boundedPhysicalTemperature(mean,input:input))
                guard let targetK=resolution.value,targetK>0 else{return nil}
                let newK=0.5*oldK+0.5*targetK
                maxKChange=max(maxKChange,abs(newK-oldK)/max(abs(newK),1e-12))
                cells[i].innerTemperature=t; cells[i].outerTemperature=tout; cells[i].meanTemperature=mean
                cells[i].k=newK; cells[i].method=resolution.method
                cells[i].resistance=log(cells[i].outerRadius/cells[i].innerRadius)/(2*Double.pi*newK*input.lengthM)
                t=tout
            }
            if let q0=lastQ,abs(q-q0)/max(abs(q),1e-12)<1e-9 && maxKChange<1e-9 {
                let rr=cells.reduce(0){$0+$1.resistance}; let qf=(input.insideBoundaryTemperatureC-input.outsideBoundaryTemperatureC)/rr; var tf=input.insideBoundaryTemperatureC
                for i in cells.indices { let to=tf-qf*cells[i].resistance; cells[i].innerTemperature=tf;cells[i].outerTemperature=to;cells[i].meanTemperature=(tf+to)/2;tf=to }
                return(cells,qf)
            }
            lastQ=q
        }
        let rr=cells.reduce(0){$0+$1.resistance}; guard rr>0 else{return nil}; let q=(input.insideBoundaryTemperatureC-input.outsideBoundaryTemperatureC)/rr
        var t=input.insideBoundaryTemperatureC; for i in cells.indices{let to=t-q*cells[i].resistance;cells[i].innerTemperature=t;cells[i].outerTemperature=to;cells[i].meanTemperature=(t+to)/2;t=to}
        return(cells,q)
    }
}
