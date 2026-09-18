import SwiftUI

struct CalculationDetailsView: View {
    let details: CalculationDetails
    @Environment(\.interfaceDensity) private var density

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            overviewSection

            if !details.equations.isEmpty {
                detailHeading("Equations")

                VStack(alignment: .leading, spacing: equationSpacing) {
                    ForEach(details.equations) { equation in
                        equationBlock(equation)
                    }
                }
            }

            if !details.variables.isEmpty {
                detailHeading("Variables & Units")

                VStack(alignment: .leading, spacing: variableSpacing) {
                    ForEach(details.variables) { variable in
                        variableRow(variable)
                    }
                }
            }

            if !details.assumptions.isEmpty {
                detailHeading("Assumptions")
                bulletList(details.assumptions)
            }

            if !details.references.isEmpty {
                detailHeading("Basis & References")
                bulletList(details.references)
            }
        }
        .padding(.vertical, 4)
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: paragraphSpacing) {
            ForEach(Array(details.overview.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: detailBodySize))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func equationBlock(_ equation: CalculationEquation) -> some View {
        VStack(alignment: .leading, spacing: equation.explanation == nil ? 0 : 2) {
            Text(equation.title)
                .font(.system(size: density.bodySize - 0.5, weight: .semibold))

            MathEquationView(mathML: equation.mathML)

            if let explanation = equation.explanation {
                Text(explanation)
                    .font(.system(size: detailSmallSize))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func variableRow(_ variable: CalculationVariable) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            MathSymbolView(mathML: variable.symbolMathML)

            VStack(alignment: .leading, spacing: 1) {
                Text(variable.definition)
                    .fixedSize(horizontal: false, vertical: true)

                if let unit = variable.unit, !unit.isEmpty {
                    Text(unit)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .font(.system(size: detailSmallSize))
        }
    }

    private var detailBodySize: CGFloat {
        max(12, density.bodySize - 1)
    }

    private var detailSmallSize: CGFloat {
        max(11, density.smallSize - 0.5)
    }

    private var sectionSpacing: CGFloat {
        max(9, density.rowPadding + 6)
    }

    private var paragraphSpacing: CGFloat {
        max(7, density.rowPadding + 2)
    }

    private var equationSpacing: CGFloat {
        max(8, density.rowPadding + 4)
    }

    private var variableSpacing: CGFloat {
        max(7, density.rowPadding + 3)
    }

    private func detailHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: density.bodySize, weight: .bold))
            .padding(.top, 2)
    }

    private func bulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 7) {
                    Text("•")
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.system(size: detailSmallSize))
    }
}
