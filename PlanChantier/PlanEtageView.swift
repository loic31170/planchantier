import SwiftUI

/// Assemble les pièces scannées à la suite en un seul plan vu de dessus.
struct PlanEtageView: View {
    let pieces: [Piece]
    var afficherNoms = true
    var epaisseur: CGFloat = 5
    var marge: CGFloat = 24

    var body: some View {
        Canvas { contexte, taille in
            let tous = pieces.flatMap { $0.segments }
            guard !tous.isEmpty else { return }
            let angle = PlanPieceView.angleRedressement(tous)
            let parPiece = pieces.map { (piece: $0, traits: PlanPieceView.tourner($0.segments, angle: angle)) }
            let traits = parPiece.flatMap { $0.traits }

            let xs = traits.flatMap { [$0.x1, $0.x2] }
            let ys = traits.flatMap { [$0.y1, $0.y2] }
            let minX = xs.min() ?? 0, maxX = xs.max() ?? 1
            let minY = ys.min() ?? 0, maxY = ys.max() ?? 1
            let largeur = max(maxX - minX, 0.1)
            let profondeur = max(maxY - minY, 0.1)

            let echelle = min((taille.width - 2 * marge) / largeur,
                              (taille.height - 2 * marge) / profondeur)
            let decalX = (taille.width - largeur * echelle) / 2
            let decalY = (taille.height - profondeur * echelle) / 2

            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: decalX + (x - minX) * echelle,
                        y: decalY + (y - minY) * echelle)
            }

            func trait(_ s: SegmentPlan) -> Path {
                var chemin = Path()
                chemin.move(to: point(s.x1, s.y1))
                chemin.addLine(to: point(s.x2, s.y2))
                return chemin
            }

            for s in traits where s.genre == .mur {
                contexte.stroke(trait(s), with: .color(.primary),
                                style: StrokeStyle(lineWidth: epaisseur, lineCap: .round))
            }
            for s in traits where s.genre != .mur {
                contexte.stroke(trait(s), with: .color(PlanPieceView.couleur(s.genre)),
                                style: StrokeStyle(lineWidth: epaisseur + 1, lineCap: .butt))
            }

            // Nom et surface au centre de chaque pièce
            for element in parPiece where afficherNoms {
                let murs = element.traits.filter { $0.genre == .mur }
                guard !murs.isEmpty else { continue }
                let cx = murs.map { ($0.x1 + $0.x2) / 2 }.reduce(0, +) / Double(murs.count)
                let cy = murs.map { ($0.y1 + $0.y2) / 2 }.reduce(0, +) / Double(murs.count)
                let centre = point(cx, cy)
                contexte.draw(Text(element.piece.nom)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary),
                              at: CGPoint(x: centre.x, y: centre.y - 7))
                contexte.draw(Text(element.piece.surfaceSol.enMetresCarres)
                                .font(.caption2)
                                .foregroundStyle(.secondary),
                              at: CGPoint(x: centre.x, y: centre.y + 8))
            }
        }
    }
}

/// Écran d'un plan d'étage : le plan assemblé et la liste des pièces.
struct EcranPlanEtage: View {
    let titre: String
    let pieces: [Piece]

    var body: some View {
        List {
            Section {
                PlanEtageView(pieces: pieces)
                    .frame(height: 420)
                LegendePlan()
            }
            Section("Pièces") {
                ForEach(pieces) { piece in
                    LabeledContent(piece.nom, value: piece.surfaceSol.enMetresCarres)
                }
                LabeledContent("Total") {
                    Text(pieces.reduce(0) { $0 + $1.surfaceSol }.enMetresCarres).fontWeight(.semibold)
                }
            }
        }
        .navigationTitle(titre)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    Vue3DView(titre: titre, pieces: pieces)
                } label: {
                    Label("Vue 3D", systemImage: "cube")
                }
            }
        }
    }
}
