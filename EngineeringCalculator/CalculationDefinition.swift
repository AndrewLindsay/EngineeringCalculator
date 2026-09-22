import SwiftUI

struct CalculationEquation: Identifiable, Hashable {
    let id: String
    let title: String
    let mathML: String
    let explanation: String?
    init(id: String, title: String, mathML: String, explanation: String? = nil) { self.id=id; self.title=title; self.mathML=mathML; self.explanation=explanation }
}
struct CalculationVariable: Identifiable, Hashable { let id:String; let symbolMathML:String; let definition:String; let unit:String?; init(id:String,symbolMathML:String,definition:String,unit:String?=nil){self.id=id;self.symbolMathML=symbolMathML;self.definition=definition;self.unit=unit} }
struct CalculationDetails: Hashable { let overview:[String];let equations:[CalculationEquation];let variables:[CalculationVariable];let assumptions:[String];let references:[String] }
struct CalculationDefinition: Identifiable, Hashable { let id:String;let title:String;let subtitle:String;let systemImage:String;let details:CalculationDetails?;init(id:String,title:String,subtitle:String,systemImage:String,details:CalculationDetails?=nil){self.id=id;self.title=title;self.subtitle=subtitle;self.systemImage=systemImage;self.details=details} }

enum CalculationRegistry {
    static let all:[CalculationDefinition] = [
        .init(id:"pipeWeightBuoyancy",title:"Pipe Weight & Buoyancy",subtitle:"Dry pipe weight, contents, displacement and submerged weight",systemImage:"cylinder.split.1x2",details:pipeWeightBuoyancyDetails),
        .init(id:"pipeHeatTransfer",title:"Pipe Heat Transfer",subtitle:"Steady-state radial conduction through multilayer pipe and insulation",systemImage:"thermometer.medium",details:pipeHeatTransferDetails),
        .init(id:"placeholder",title:"Future Calculator",subtitle:"A reserved module showing how the library can grow",systemImage:"plus.square.dashed")
    ]
    static func definition(id:String)->CalculationDefinition?{all.first{$0.id==id}}

    private static let pipeHeatTransferDetails = CalculationDetails(
        overview:[
            "Calculates steady-state radial heat conduction through one or more concentric cylindrical solid layers.",
            "Each layer obtains thermal conductivity from the selected material in the Material Library. Missing or out-of-range conductivity data block the calculation.",
            "The current first-pass model evaluates temperature-dependent conductivity at the arithmetic mean of the specified inside and outside boundary temperatures."
        ],
        equations:[
            .init(id:"radialR",title:"Layer radial conduction resistance",mathML:#"<math><msub><mi>R</mi><mi>i</mi></msub><mo>=</mo><mfrac><mrow><mi>ln</mi><mfenced><mfrac><msub><mi>r</mi><mi>o</mi></msub><msub><mi>r</mi><mi>i</mi></msub></mfrac></mfenced></mrow><mrow><mn>2</mn><mi>π</mi><msub><mi>k</mi><mi>i</mi></msub><mi>L</mi></mrow></mfrac></math>"#),
            .init(id:"totalR",title:"Total conduction resistance",mathML:#"<math><msub><mi>R</mi><mi>total</mi></msub><mo>=</mo><munderover><mo>∑</mo><mrow><mi>i</mi><mo>=</mo><mn>1</mn></mrow><mi>n</mi></munderover><msub><mi>R</mi><mi>i</mi></msub></math>"#),
            .init(id:"heatRate",title:"Heat-transfer rate",mathML:#"<math><mi>Q</mi><mo>=</mo><mfrac><mrow><msub><mi>T</mi><mi>inside</mi></msub><mo>−</mo><msub><mi>T</mi><mi>outside</mi></msub></mrow><msub><mi>R</mi><mi>total</mi></msub></mfrac></math>"#)
        ],
        variables:[
            .init(id:"ri",symbolMathML:#"<math><msub><mi>r</mi><mi>i</mi></msub></math>"#,definition:"Layer inner radius",unit:"m"),
            .init(id:"ro",symbolMathML:#"<math><msub><mi>r</mi><mi>o</mi></msub></math>"#,definition:"Layer outer radius",unit:"m"),
            .init(id:"k",symbolMathML:#"<math><mi>k</mi></math>"#,definition:"Layer thermal conductivity resolved from the Material Library",unit:"W/(m·K)"),
            .init(id:"L",symbolMathML:#"<math><mi>L</mi></math>"#,definition:"Calculation length",unit:"m"),
            .init(id:"R",symbolMathML:#"<math><mi>R</mi></math>"#,definition:"Thermal resistance",unit:"K/W"),
            .init(id:"Q",symbolMathML:#"<math><mi>Q</mi></math>"#,definition:"Heat-transfer rate; positive is from inside to outside",unit:"W")
        ],
        assumptions:[
            "Steady-state one-dimensional radial conduction.",
            "Concentric circular cylindrical layers with uniform thickness.",
            "Inside and outside temperatures are solid boundary temperatures; convection films are not yet included.",
            "No axial conduction, contact resistance, radiation, heat generation or end effects.",
            "Temperature-dependent conductivity is currently evaluated at the overall arithmetic mean boundary temperature rather than iteratively at each layer mean temperature."
        ],
        references:["Standard cylindrical-wall Fourier conduction relation: R = ln(ro/ri)/(2πkL)."]
    )

    private static let pipeWeightBuoyancyDetails = CalculationDetails(
        overview:["The pipe is modelled as a series of concentric solid layers, starting at the specified internal diameter and working outwards.","Dry pipe mass is the sum of all solid layer masses. Internal contents are calculated separately and are not included in dry pipe mass.","Buoyancy is based on the external volume displaced by the final outside diameter. All reported masses and weights are per metre of pipe length."],
        equations:[
            .init(id:"layerOD",title:"Layer outside diameter",mathML:#"<math><msub><mi>D</mi><mi>o</mi></msub><mo>=</mo><msub><mi>D</mi><mi>i</mi></msub><mo>+</mo><mn>2</mn><mo>⋅</mo><mi>t</mi></math>"#,explanation:"Each layer starts at the previous layer's outside diameter."),
            .init(id:"layerArea",title:"Layer cross-sectional area",mathML:#"<math><msub><mi>A</mi><mi>layer</mi></msub><mo>=</mo><mfrac><mi>π</mi><mn>4</mn></mfrac><mfenced><mrow><msubsup><mi>D</mi><mi>o</mi><mn>2</mn></msubsup><mo>−</mo><msubsup><mi>D</mi><mi>i</mi><mn>2</mn></msubsup></mrow></mfenced></math>"#,explanation:"Annular area of one solid pipe or coating layer."),
            .init(id:"layerMass",title:"Layer mass per unit length",mathML:#"<math><msub><mi>m</mi><mi>layer</mi></msub><mo>=</mo><msub><mi>ρ</mi><mi>layer</mi></msub><mo>⋅</mo><msub><mi>A</mi><mi>layer</mi></msub></math>"#),
            .init(id:"pipeMass",title:"Dry pipe mass per unit length",mathML:#"<math><msub><mi>m</mi><mi>pipe</mi></msub><mo>=</mo><munderover><mo>∑</mo><mrow><mi>j</mi><mo>=</mo><mn>1</mn></mrow><mi>n</mi></munderover><msub><mi>m</mi><mi>j</mi></msub></math>"#),
            .init(id:"contentsMass",title:"Internal contents mass per unit length",mathML:#"<math><msub><mi>m</mi><mi>contents</mi></msub><mo>=</mo><msub><mi>ρ</mi><mi>int</mi></msub><mfrac><mi>π</mi><mn>4</mn></mfrac><msubsup><mi>D</mi><mi>i</mi><mn>2</mn></msubsup></math>"#),
            .init(id:"displacedMass",title:"Displaced external-fluid mass per unit length",mathML:#"<math><msub><mi>m</mi><mi>disp</mi></msub><mo>=</mo><msub><mi>ρ</mi><mi>ext</mi></msub><mfrac><mi>π</mi><mn>4</mn></mfrac><msubsup><mi>D</mi><mi>final</mi><mn>2</mn></msubsup></math>"#),
            .init(id:"submergedMass",title:"Submerged equivalent mass",mathML:#"<math><msub><mi>m</mi><mi>sub</mi></msub><mo>=</mo><msub><mi>m</mi><mi>pipe</mi></msub><mo>+</mo><msub><mi>m</mi><mi>contents</mi></msub><mo>−</mo><msub><mi>m</mi><mi>disp</mi></msub></math>"#),
            .init(id:"submergedWeight",title:"Submerged weight",mathML:#"<math><msub><mi>W</mi><mi>sub</mi></msub><mo>=</mo><msub><mi>m</mi><mi>sub</mi></msub><mo>⋅</mo><mi>g</mi></math>"#,explanation:"The app divides by 1000 when displaying weight in kN/m. A negative result indicates net buoyancy.")
        ],
        variables:[.init(id:"Di",symbolMathML:#"<math><msub><mi>D</mi><mi>i</mi></msub></math>"#,definition:"Inside diameter of the current layer; for the first layer this is the pipe internal diameter",unit:"m"),.init(id:"Do",symbolMathML:#"<math><msub><mi>D</mi><mi>o</mi></msub></math>"#,definition:"Outside diameter of the current layer",unit:"m"),.init(id:"Dfinal",symbolMathML:#"<math><msub><mi>D</mi><mi>final</mi></msub></math>"#,definition:"Final outside diameter including all solid layers",unit:"m"),.init(id:"t",symbolMathML:#"<math><mi>t</mi></math>"#,definition:"Layer radial thickness",unit:"m"),.init(id:"A",symbolMathML:#"<math><mi>A</mi></math>"#,definition:"Cross-sectional area",unit:"m²"),.init(id:"rhoLayer",symbolMathML:#"<math><msub><mi>ρ</mi><mi>layer</mi></msub></math>"#,definition:"Density of the solid layer",unit:"kg/m³"),.init(id:"rhoInt",symbolMathML:#"<math><msub><mi>ρ</mi><mi>int</mi></msub></math>"#,definition:"Internal fluid density",unit:"kg/m³"),.init(id:"rhoExt",symbolMathML:#"<math><msub><mi>ρ</mi><mi>ext</mi></msub></math>"#,definition:"External fluid density",unit:"kg/m³"),.init(id:"m",symbolMathML:#"<math><mi>m</mi></math>"#,definition:"Mass per unit pipe length",unit:"kg/m"),.init(id:"g",symbolMathML:#"<math><mi>g</mi></math>"#,definition:"Standard acceleration due to gravity",unit:"9.80665 m/s²")],
        assumptions:["Pipe and added layers are concentric circular cylinders with uniform thickness and density.","The pipe is fully flooded internally and fully submerged externally for the contents and buoyancy calculations.","End effects are excluded; calculations are performed per metre of pipe length.","Negative submerged weight denotes a net upward buoyant force."],
        references:["Geometry: area of a circular annulus and volume of a cylinder.","Buoyancy: Archimedes' principle; buoyant force equals the weight of displaced external fluid.","Standard gravity used by the calculator: 9.80665 m/s²."]
    )
}
