import SwiftUI
#if os(macOS)
import AppKit
#endif

enum MaterialComparisonSection: String, CaseIterable, Identifiable, Codable {
    case identity = "Identity & Traceability", physical = "Physical", thermal = "Thermal", mechanical = "Mechanical", electrical = "Electrical", serviceLimits = "Service Limits"
    var id: Self { self }
}

enum MaterialComparisonValue: Hashable { case text(String); case number(Double, unit: String?); case propertySeries(MaterialPropertySeries); case missing }
struct MaterialComparisonCell: Identifiable, Hashable { let materialID: UUID; let value: MaterialComparisonValue; let differsFromReference: Bool; let absoluteDifference: Double?; let percentageDifference: Double?; var id: UUID { materialID } }
struct MaterialComparisonRow: Identifiable, Hashable { let id: String; let section: MaterialComparisonSection; let label: String; let cells: [MaterialComparisonCell]; var hasDifference: Bool { cells.dropFirst().contains(where: \.differsFromReference) } }
struct MaterialComparison: Hashable { let materials: [EngineeringMaterial]; let referenceMaterialID: UUID; let rows: [MaterialComparisonRow]; var referenceMaterial: EngineeringMaterial? { materials.first { $0.id == referenceMaterialID } }; var differingRows: [MaterialComparisonRow] { rows.filter(\.hasDifference) } }

enum MaterialComparisonEngine {
    static let relativeTolerance = 1e-9, absoluteTolerance = 1e-12
    static func compare(_ materials: [EngineeringMaterial], referenceMaterialID: UUID? = nil) -> MaterialComparison {
        guard !materials.isEmpty else { return MaterialComparison(materials: [], referenceMaterialID: UUID(), rows: []) }
        let referenceID = referenceMaterialID.flatMap { id in materials.contains { $0.id == id } ? id : nil } ?? materials[0].id
        let ordered = materials.first(where: { $0.id == referenceID }).map { [$0] + materials.filter { $0.id != referenceID } } ?? materials
        var rows: [MaterialComparisonRow] = []
        func text(_ id: String, _ section: MaterialComparisonSection, _ label: String, _ key: KeyPath<EngineeringMaterial, String?>) { rows.append(makeRow(id, section, label, ordered) { $0[keyPath: key].map(MaterialComparisonValue.text) ?? .missing }) }
        func number(_ id: String, _ section: MaterialComparisonSection, _ label: String, _ unit: String?, _ key: KeyPath<EngineeringMaterial, Double?>) { rows.append(makeRow(id, section, label, ordered) { $0[keyPath: key].map { .number($0, unit: unit) } ?? .missing }) }
        func series(_ id: String, _ section: MaterialComparisonSection, _ label: String, _ key: KeyPath<EngineeringMaterial, MaterialPropertySeries?>) { rows.append(makeRow(id, section, label, ordered) { $0[keyPath: key].map(MaterialComparisonValue.propertySeries) ?? .missing }) }
        text("category",.identity,"Category",\.category); text("grade",.identity,"Grade",\.grade); text("unsDesignation",.identity,"UNS designation",\.unsDesignation); text("standardDesignation",.identity,"Standard designation",\.standardDesignation); text("productForm",.identity,"Product form",\.productForm); text("materialCondition",.identity,"Material condition",\.materialCondition); text("source",.identity,"Source",\.source); text("notes",.identity,"Notes",\.notes)
        number("density",.physical,"Density","kg/m³",\.densityKgM3)
        number("thermalConductivity",.thermal,"Thermal conductivity","W/(m·K)",\.thermalConductivityWMK); series("thermalConductivityModel",.thermal,"Thermal conductivity model",\.thermalConductivitySeries); number("specificHeatCapacity",.thermal,"Specific heat capacity","J/(kg·K)",\.specificHeatCapacityJkgK); series("specificHeatCapacityModel",.thermal,"Specific heat capacity model",\.specificHeatCapacitySeries); number("thermalExpansion",.thermal,"Thermal expansion","µm/(m·K)",\.thermalExpansionMicrostrainPerK); series("thermalExpansionModel",.thermal,"Thermal expansion model",\.thermalExpansionSeries)
        number("youngsModulus",.mechanical,"Young's modulus","GPa",\.youngsModulusGPa); series("youngsModulusModel",.mechanical,"Young's modulus model",\.youngsModulusSeries); number("poissonsRatio",.mechanical,"Poisson's ratio",nil,\.poissonsRatio); series("poissonsRatioModel",.mechanical,"Poisson's ratio model",\.poissonsRatioSeries); number("yieldStrength",.mechanical,"Yield strength","MPa",\.yieldStrengthMPa); series("yieldStrengthModel",.mechanical,"Yield strength model",\.yieldStrengthSeries); number("ultimateTensileStrength",.mechanical,"Ultimate tensile strength","MPa",\.ultimateTensileStrengthMPa); series("ultimateTensileStrengthModel",.mechanical,"Ultimate tensile strength model",\.ultimateTensileStrengthSeries); number("shearModulus",.mechanical,"Shear modulus","GPa",\.shearModulusGPa); series("shearModulusModel",.mechanical,"Shear modulus model",\.shearModulusSeries); number("compressiveStrength",.mechanical,"Compressive strength","MPa",\.compressiveStrengthMPa); number("smys",.mechanical,"SMYS","MPa",\.smysMPa); number("smts",.mechanical,"SMTS","MPa",\.smtsMPa)
        number("electricalResistivity",.electrical,"Electrical resistivity","Ω·m",\.electricalResistivityOhmM); series("electricalResistivityModel",.electrical,"Electrical resistivity model",\.electricalResistivitySeries)
        number("minimumServiceTemperature",.serviceLimits,"Minimum service temperature","°C",\.minimumServiceTemperatureC); number("maximumServiceTemperature",.serviceLimits,"Maximum service temperature","°C",\.maximumServiceTemperatureC)
        return MaterialComparison(materials: ordered, referenceMaterialID: referenceID, rows: rows)
    }
    private static func makeRow(_ id: String, _ section: MaterialComparisonSection, _ label: String, _ materials: [EngineeringMaterial], _ value: (EngineeringMaterial)->MaterialComparisonValue) -> MaterialComparisonRow {
        let values = materials.map(value), reference = materials.isEmpty ? .missing : value(materials[0])
        let cells = zip(materials, values).enumerated().map { i, pair -> MaterialComparisonCell in let (m,v)=pair; let differs=i > 0 && !equivalent(reference,v); let d=numeric(reference,v); return MaterialComparisonCell(materialID:m.id,value:v,differsFromReference:differs,absoluteDifference:differs ? d.0:nil,percentageDifference:differs ? d.1:nil) }
        return MaterialComparisonRow(id:id,section:section,label:label,cells:cells)
    }
    private static func numeric(_ a: MaterialComparisonValue,_ b: MaterialComparisonValue)->(Double?,Double?){ guard case let .number(x,_)=a, case let .number(y,_)=b else{return(nil,nil)}; let d=y-x; return(d,approximatelyEqual(x,0) ? nil:d/x*100) }
    private static func equivalent(_ a: MaterialComparisonValue,_ b: MaterialComparisonValue)->Bool { switch(a,b){case(.missing,.missing):return true;case let(.text(x),.text(y)):return x==y;case let(.number(x,u),.number(y,v)):return u==v && approximatelyEqual(x,y);case let(.propertySeries(x),.propertySeries(y)):return equivalent(x,y);default:return false} }
    private static func equivalent(_ a: MaterialPropertySeries,_ b: MaterialPropertySeries)->Bool { optionalEqual(a.referenceValue,b.referenceValue) && optionalEqual(a.referenceTemperatureC,b.referenceTemperatureC) && pointsEqual(a.temperatureTable,b.temperatureTable) && equationsEqual(a.equation,b.equation) && a.source==b.source && a.basis==b.basis }
    private static func pointsEqual(_ a:[MaterialPropertyPoint],_ b:[MaterialPropertyPoint])->Bool { let x=a.sorted{$0.temperatureC<$1.temperatureC},y=b.sorted{$0.temperatureC<$1.temperatureC}; return x.count==y.count && zip(x,y).allSatisfy{approximatelyEqual($0.temperatureC,$1.temperatureC)&&approximatelyEqual($0.value,$1.value)} }
    private static func equationsEqual(_ a:MaterialPropertyEquation?,_ b:MaterialPropertyEquation?)->Bool { switch(a,b){case(nil,nil):return true;case let(x?,y?):return x.effectiveKind==y.effectiveKind && approximatelyEqual(x.a,y.a) && approximatelyEqual(x.b,y.b) && approximatelyEqual(x.c,y.c) && approximatelyEqual(x.d,y.d) && optionalEqual(x.minimumTemperatureC,y.minimumTemperatureC) && optionalEqual(x.maximumTemperatureC,y.maximumTemperatureC) && x.allowsExtrapolation==y.allowsExtrapolation && optionalEqual(x.referenceValue,y.referenceValue) && optionalEqual(x.referenceTemperatureC,y.referenceTemperatureC) && optionalEqual(x.slope,y.slope) && optionalEqual(x.temperatureCoefficient,y.temperatureCoefficient);default:return false} }
    private static func optionalEqual(_ a:Double?,_ b:Double?)->Bool { switch(a,b){case(nil,nil):return true;case let(x?,y?):return approximatelyEqual(x,y);default:return false} }
    private static func approximatelyEqual(_ a:Double,_ b:Double)->Bool { let scale=max(abs(a),abs(b),1); return abs(a-b)<=max(absoluteTolerance,relativeTolerance*scale) }
}

struct MaterialComparisonView: View {
    @EnvironmentObject private var store: MaterialLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<UUID>
    @State private var selectionOrder: [UUID]
    @State private var referenceID: UUID?
    @State private var differencesOnly = false
    @State private var showingComparison: Bool
    private let standaloneWindow: Bool
    private let propertyColumnWidth: CGFloat = 220, materialColumnWidth: CGFloat = 190

    init(initialSelectionOrder:[UUID]=[],referenceID:UUID?=nil,showingComparison:Bool=false,standaloneWindow:Bool=false){ _selectedIDs=State(initialValue:Set(initialSelectionOrder)); _selectionOrder=State(initialValue:initialSelectionOrder); _referenceID=State(initialValue:referenceID ?? initialSelectionOrder.first); _showingComparison=State(initialValue:showingComparison); self.standaloneWindow=standaloneWindow }
    private var allMaterials:[EngineeringMaterial]{store.allMaterials.sorted{$0.name.localizedCaseInsensitiveCompare($1.name)==.orderedAscending}}
    private var selectedMaterials:[EngineeringMaterial]{selectionOrder.compactMap{id in allMaterials.first{$0.id==id}}}
    private var comparison:MaterialComparison?{guard showingComparison,selectedMaterials.count>=2 else{return nil};return MaterialComparisonEngine.compare(selectedMaterials,referenceMaterialID:referenceID)}

    var body: some View { NavigationStack { Group { if let comparison { comparisonContent(comparison) } else { selectionContent } }.navigationTitle("Compare Materials").toolbar { ToolbarItem(placement:.cancellationAction){Button("Done"){closeView()}} } }
        #if os(macOS)
        .frame(minWidth:800,idealWidth:1200,maxWidth:.infinity,minHeight:560,idealHeight:760,maxHeight:.infinity)
        #else
        .frame(minWidth:620,minHeight:520)
        #endif
        .onChange(of:selectedIDs){_,_ in normaliseReference()}
    }
    private var selectionContent:some View { VStack(alignment:.leading,spacing:16){Text("Select two or more materials to compare.").font(.headline);Text("The first material selected becomes the reference. Selection badges show the comparison order.").font(.callout).foregroundStyle(.secondary);List{ForEach(groupedCategories,id:\.self){category in Section(category){ForEach(allMaterials.filter{$0.category==category}){material in Button{toggle(material.id)}label:{HStack{Image(systemName:selectedIDs.contains(material.id) ? "checkmark.circle.fill":"circle");VStack(alignment:.leading){Text(material.name);Text(material.isBuiltIn ? "Built-in":"My Material").font(.caption).foregroundStyle(.secondary)};Spacer();selectionBadge(for:material.id)}.contentShape(Rectangle())}.buttonStyle(.plain)}}}};HStack{Text("\(selectedIDs.count) selected").foregroundStyle(.secondary);Spacer();Button("Compare (\(selectedIDs.count))"){beginComparison()}.buttonStyle(.borderedProminent).disabled(selectedIDs.count<2)}}.padding(20) }
    @ViewBuilder private func selectionBadge(for id:UUID)->some View{if let i=selectionOrder.firstIndex(of:id){if i==0{Text("R").font(.caption2.bold()).foregroundStyle(.white).frame(width:24,height:24).background(Color.green,in:Circle())}else{Text("\(i+1)").font(.caption2.bold()).foregroundStyle(.white).frame(width:24,height:24).background(Color.accentColor,in:Circle())}}}
    private var groupedCategories:[String]{Array(Set(allMaterials.map(\.category))).sorted{$0.localizedCaseInsensitiveCompare($1)==.orderedAscending}}
    private func comparisonContent(_ comparison:MaterialComparison)->some View { VStack(spacing:0){HStack{Picker("Reference",selection:Binding(get:{referenceID ?? comparison.referenceMaterialID},set:{referenceID=$0})){ForEach(selectedMaterials){Text($0.name).tag($0.id)}}.frame(maxWidth:360);Toggle("Differences Only",isOn:$differencesOnly);Spacer();if !standaloneWindow{Button("Change Materials"){showingComparison=false}}}.padding(16);Divider();comparisonTable(comparison)} }
    @ViewBuilder private func comparisonTable(_ comparison:MaterialComparison)->some View {
        #if os(macOS)
        MacMaterialComparisonGrid(comparison:comparison,rows:differencesOnly ? comparison.differingRows:comparison.rows)
        #else
        mobileComparisonTable(comparison)
        #endif
    }
    private func mobileComparisonTable(_ comparison:MaterialComparison)->some View { let rows=differencesOnly ? comparison.differingRows:comparison.rows; return ScrollView([.horizontal,.vertical]){LazyVStack(alignment:.leading,spacing:0){HStack(spacing:0){Text("Property").fontWeight(.semibold).frame(width:propertyColumnWidth,alignment:.leading).padding(8);ForEach(comparison.materials){materialHeader($0,subtitle:$0.id==comparison.referenceMaterialID ? "Reference":"Compared")}}.background(.quaternary.opacity(0.35));ForEach(MaterialComparisonSection.allCases){section in let sr=rows.filter{$0.section==section};if !sr.isEmpty{Text(section.rawValue).font(.headline).frame(maxWidth:.infinity,alignment:.leading).padding(8).background(.regularMaterial);ForEach(sr){row in HStack(alignment:.top,spacing:0){Text(row.label).frame(width:propertyColumnWidth,alignment:.leading).padding(8);ForEach(row.cells){comparisonCell($0)}}.overlay(alignment:.bottom){Divider()}}}}}.padding(12)} }
    private func materialHeader(_ m:EngineeringMaterial,subtitle:String)->some View{VStack(alignment:.leading){Text(m.name).fontWeight(.semibold);Text(subtitle).font(.caption2).foregroundStyle(.secondary)}.frame(width:materialColumnWidth,alignment:.leading).padding(8)}
    private func comparisonCell(_ c:MaterialComparisonCell)->some View{VStack(alignment:.leading,spacing:3){Text(display(c.value)).font(.body.monospacedDigit());if c.differsFromReference{if let d=c.absoluteDifference{Text(differenceText(delta:d,percentage:c.percentageDifference,value:c.value)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)}else{Text("Changed").font(.caption).foregroundStyle(.secondary)}}}.frame(width:materialColumnWidth,alignment:.leading).frame(minHeight:42,alignment:.topLeading).padding(8).background(c.differsFromReference ? Color.accentColor.opacity(0.10):Color.clear)}
    private func display(_ v:MaterialComparisonValue)->String{switch v{case .missing:return "Not specified";case .text(let t):return t.isEmpty ? "—":t;case .number(let x,let u):let s=EngineeringNumberFormatter.string(x);return u.map{"\(s) \($0)"} ?? s;case .propertySeries(let s):if let e=s.equation{return e.effectiveKind.rawValue};if !s.temperatureTable.isEmpty{return "\(s.temperatureTable.count) temperature points"};return "Reference value only"}}
    private func differenceText(delta:Double,percentage:Double?,value:MaterialComparisonValue)->String{let sign=delta>0 ? "+":"";let unit:String;if case .number(_,let u)=value,let u{unit=" \(u)"}else{unit=""};let base="Δ \(sign)\(EngineeringNumberFormatter.string(delta))\(unit)";guard let p=percentage else{return base};return "\(base) (\(p>0 ? "+":"")\(EngineeringNumberFormatter.string(p))%)"}
    private func toggle(_ id:UUID){if selectedIDs.contains(id){selectedIDs.remove(id);selectionOrder.removeAll{$0==id}}else{selectedIDs.insert(id);selectionOrder.append(id)};referenceID=selectionOrder.first}
    private func normaliseReference(){selectionOrder.removeAll{!selectedIDs.contains($0)};for id in selectedIDs where !selectionOrder.contains(id){selectionOrder.append(id)};if referenceID==nil || !selectedIDs.contains(referenceID!){referenceID=selectionOrder.first}}
    private func beginComparison(){
        #if os(macOS)
        if !standaloneWindow{openMacComparisonWindow();dismiss();return}
        #endif
        showingComparison=true
    }
    private func closeView(){
        #if os(macOS)
        if standaloneWindow{NSApp.keyWindow?.close();return}
        #endif
        dismiss()
    }
    #if os(macOS)
    private func openMacComparisonWindow(){let root=MaterialComparisonView(initialSelectionOrder:selectionOrder,referenceID:referenceID,showingComparison:true,standaloneWindow:true).environmentObject(store);let controller=NSHostingController(rootView:root);let window=NSWindow(contentViewController:controller);window.title="Compare Materials";window.styleMask=[.titled,.closable,.miniaturizable,.resizable];window.setContentSize(NSSize(width:1200,height:760));window.minSize=NSSize(width:800,height:560);window.collectionBehavior.insert(.fullScreenPrimary);window.center();window.makeKeyAndOrderFront(nil)}
    #endif
}
