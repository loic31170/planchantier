import SwiftUI

/// Dessine la pièce vue de dessus, avec la longueur de chaque mur.
/// Le plan est redressé pour que le mur le plus long soit horizontal.
struct PlanPieceView: View {
    let segments: [SegmentPlan]
    /// En dessous de cette longueur (m), la cote n'est pas écrite sur le plan
    /// (elle reste visible dans la liste des murs) pour éviter les chevauchements.
    var coteMinimale: Double = 0.5

    var body: some View {
        Canvas { contexte, taille in
            let traits = PlanPieceView.redresser(segments)
            guard !traits.isEmpty else { return }

            let xs = traits.flatMap { [$0.x1, $0.x2] }
            let ys = traits.flatMap { [$0.y1, $0.y2] }
            let minX = xs.min() ?? 0, maxX = xs.max() ?? 1
            let minY = ys.min() ?? 0, maxY = ys.max() ?? 1
            let largeur = max(maxX - minX, 0.1)
            let profondeur = max(maxY - minY, 0.1)

            let marge: CGFloat = 48
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

            // Murs
            for s in traits where s.genre == .mur {
                contexte.stroke(trait(s), with: .color(.primary),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
            // Portes, fenêtres, ouvertures par-dessus les murs
            for s in traits where s.genre != .mur {
                contexte.stroke(trait(s), with: .color(PlanPieceView.couleur(s.genre)),
                                style: StrokeStyle(lineWidth: 7, lineCap: .butt))
            }

            // Cotes à l'extérieur de la pièce, numéros des murs à l'intérieur
            let centre = point((minX + maxX) / 2, (minY + maxY) / 2)
            for (index, s) in PlanPieceView.mursOrdonnes(segments).enumerated() {
                let a = point(s.x1, s.y1), b = point(s.x2, s.y2)
                let milieu = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                let dx = b.x - a.x, dy = b.y - a.y
                let longueur = max(hypot(dx, dy), 0.001)
                var nx = -dy / longueur, ny = dx / longueur
                if (milieu.x - centre.x) * nx + (milieu.y - centre.y) * ny > 0 {
                    nx = -nx
                    ny = -ny
                }
                let position = CGPoint(x: milieu.x + nx * 16, y: milieu.y + ny * 16)
                let rond = Path(ellipseIn: CGRect(x: position.x - 9, y: position.y - 9, width: 18, height: 18))
                contexte.fill(rond, with: .color(.accentColor))
                contexte.draw(Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white),
                              at: position)
            }
            for s in traits where s.genre == .mur && s.longueur >= coteMinimale {
                let a = point(s.x1, s.y1), b = point(s.x2, s.y2)
                let milieu = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                let dx = b.x - a.x, dy = b.y - a.y
                let longueur = max(hypot(dx, dy), 0.001)
                var nx = -dy / longueur, ny = dx / longueur
                if (milieu.x - centre.x) * nx + (milieu.y - centre.y) * ny < 0 {
                    nx = -nx
                    ny = -ny
                }
                // Décalage selon l'orientation : plus large pour un mur vertical (texte horizontal)
                let ecart = 10 + abs(nx) * 24 + abs(ny) * 8
                let position = CGPoint(x: milieu.x + nx * ecart, y: milieu.y + ny * ecart)
                contexte.draw(Text(s.longueur.enMetres)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary),
                              at: position)
            }
        }
        .overlay {
            if segments.isEmpty {
                Text("Aucun plan pour cette pièce")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Angle qui rend horizontal le mur le plus long.
    static func angleRedressement(_ segments: [SegmentPlan]) -> Double {
        guard let plusLong = segments.filter({ $0.genre == .mur }).max(by: { $0.longueur < $1.longueur }) else {
            return 0
        }
        return atan2(plusLong.y2 - plusLong.y1, plusLong.x2 - plusLong.x1)
    }

    /// Fait tourner tous les traits d'un même angle (en radians).
    static func tourner(_ segments: [SegmentPlan], angle: Double) -> [SegmentPlan] {
        let c = cos(-angle), s = sin(-angle)
        return segments.map { seg in
            var r = seg
            r.x1 = seg.x1 * c - seg.y1 * s
            r.y1 = seg.x1 * s + seg.y1 * c
            r.x2 = seg.x2 * c - seg.y2 * s
            r.y2 = seg.x2 * s + seg.y2 * c
            return r
        }
    }

    /// Fait tourner le plan pour que le mur le plus long soit horizontal.
    static func redresser(_ segments: [SegmentPlan]) -> [SegmentPlan] {
        tourner(segments, angle: angleRedressement(segments))
    }

    /// Murs du plan redressé, numérotés dans le sens des aiguilles d'une montre
    /// en partant du haut. C'est cet ordre qui sert partout (plan, liste, PDF).
    static func mursOrdonnes(_ segments: [SegmentPlan]) -> [SegmentPlan] {
        let murs = redresser(segments).filter { $0.genre == .mur }
        guard !murs.isEmpty else { return [] }
        let milieux = murs.map { (x: ($0.x1 + $0.x2) / 2, y: ($0.y1 + $0.y2) / 2) }
        let cx = milieux.map { $0.x }.reduce(0, +) / Double(milieux.count)
        let cy = milieux.map { $0.y }.reduce(0, +) / Double(milieux.count)
        func cle(_ m: SegmentPlan) -> Double {
            let angle = atan2((m.y1 + m.y2) / 2 - cy, (m.x1 + m.x2) / 2 - cx)
            // en haut = 0, puis à droite, en bas, à gauche (l'axe y descend à l'écran)
            return (angle + .pi / 2 + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        }
        return murs.sorted { cle($0) < cle($1) }
    }

    static func couleur(_ genre: SegmentPlan.Genre) -> Color {
        switch genre {
        case .mur: return .primary
        case .porte: return .orange
        case .fenetre: return .blue
        case .ouverture: return .gray
        }
    }
}

/// Légende des couleurs du plan.
struct LegendePlan: View {
    var body: some View {
        HStack(spacing: 16) {
            element("Mur", .mur)
            element("Porte", .porte)
            element("Fenêtre", .fenetre)
            element("Ouverture", .ouverture)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func element(_ titre: String, _ genre: SegmentPlan.Genre) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(PlanPieceView.couleur(genre))
                .frame(width: 14, height: 5)
            Text(titre)
        }
    }
}
