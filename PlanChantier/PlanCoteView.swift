import SwiftUI

/// Plan d'une pièce « façon architecte » : murs épais, portes avec leur ouverture,
/// fenêtres, chaînes de cotes à l'extérieur de chaque mur, nom et surface au centre, échelle.
struct PlanCoteView: View {
    let segments: [SegmentPlan]
    var nom: String? = nil
    var numeros = true
    var echelleVisible = true

    var body: some View {
        Canvas { contexte, taille in
            let traits = PlanPieceView.redresser(segments)
            let murs = PlanPieceView.mursOrdonnes(segments)
            guard !murs.isEmpty else { return }

            let xs = traits.flatMap { [$0.x1, $0.x2] }
            let ys = traits.flatMap { [$0.y1, $0.y2] }
            let minX = xs.min() ?? 0, maxX = xs.max() ?? 1
            let minY = ys.min() ?? 0, maxY = ys.max() ?? 1
            let largeur = max(maxX - minX, 0.1)
            let profondeur = max(maxY - minY, 0.1)

            let marge: CGFloat = 64
            let basEchelle: CGFloat = echelleVisible ? 26 : 0
            let echelle = min((taille.width - 2 * marge) / largeur,
                              (taille.height - 2 * marge - basEchelle) / profondeur)
            let decalX = (taille.width - largeur * echelle) / 2
            let decalY = (taille.height - basEchelle - profondeur * echelle) / 2

            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: decalX + (x - minX) * echelle, y: decalY + (y - minY) * echelle)
            }
            let encre = GraphicsContext.Shading.color(.primary)
            let fond = GraphicsContext.Shading.color(Color(.systemBackground))
            let cx = murs.map { ($0.x1 + $0.x2) / 2 }.reduce(0, +) / Double(murs.count)
            let cy = murs.map { ($0.y1 + $0.y2) / 2 }.reduce(0, +) / Double(murs.count)

            /// Normale unitaire d'un trait, tournée vers l'extérieur (ou l'intérieur) de la pièce.
            func normale(_ s: SegmentPlan, exterieur: Bool) -> (x: Double, y: Double) {
                let l = max(s.longueur, 0.0001)
                var nx = -(s.y2 - s.y1) / l, ny = (s.x2 - s.x1) / l
                let mx = (s.x1 + s.x2) / 2 - cx, my = (s.y1 + s.y2) / 2 - cy
                let versExterieur = mx * nx + my * ny > 0
                if versExterieur != exterieur { nx = -nx; ny = -ny }
                return (nx, ny)
            }

            func ligne(_ a: CGPoint, _ b: CGPoint, _ style: StrokeStyle, _ couleur: GraphicsContext.Shading) {
                var chemin = Path()
                chemin.move(to: a)
                chemin.addLine(to: b)
                contexte.stroke(chemin, with: couleur, style: style)
            }

            func texte(_ mots: String, _ p: CGPoint, angle: Double, taillePolice: CGFloat, gras: Bool = false) {
                var c = contexte
                c.translateBy(x: p.x, y: p.y)
                var a = angle
                if a > .pi / 2 { a -= .pi } else if a <= -.pi / 2 { a += .pi }
                c.rotate(by: .radians(a))
                c.draw(Text(mots)
                        .font(.system(size: taillePolice, weight: gras ? .semibold : .regular))
                        .foregroundStyle(.primary),
                       at: .zero)
            }

            // 1. Murs
            for s in murs {
                ligne(point(s.x1, s.y1), point(s.x2, s.y2),
                      StrokeStyle(lineWidth: 7, lineCap: .square), encre)
            }

            // 2. Portes, fenêtres, ouvertures
            for s in traits where s.genre != .mur {
                let a = point(s.x1, s.y1), b = point(s.x2, s.y2)
                ligne(a, b, StrokeStyle(lineWidth: 9, lineCap: .butt), fond)
                switch s.genre {
                case .fenetre:
                    let n = normale(s, exterieur: true)
                    for decalage in [-2.5, 2.5] {
                        let dx = n.x * decalage, dy = n.y * decalage
                        ligne(CGPoint(x: a.x + dx, y: a.y + dy), CGPoint(x: b.x + dx, y: b.y + dy),
                              StrokeStyle(lineWidth: 1), encre)
                    }
                case .porte:
                    // vantail ouvert vers l'intérieur et arc d'ouverture
                    let n = normale(s, exterieur: false)
                    let rayon = hypot(b.x - a.x, b.y - a.y)
                    let debut = atan2(n.y, n.x), fin = atan2(b.y - a.y, b.x - a.x)
                    var ecart = fin - debut
                    while ecart > .pi { ecart -= 2 * .pi }
                    while ecart < -.pi { ecart += 2 * .pi }
                    let bout = CGPoint(x: a.x + n.x * rayon, y: a.y + n.y * rayon)
                    ligne(a, bout, StrokeStyle(lineWidth: 1.2), encre)
                    var arc = Path()
                    arc.move(to: bout)
                    for i in 1...20 {
                        let t = debut + ecart * Double(i) / 20
                        arc.addLine(to: CGPoint(x: a.x + cos(t) * rayon, y: a.y + sin(t) * rayon))
                    }
                    contexte.stroke(arc, with: encre, style: StrokeStyle(lineWidth: 0.7, dash: [3, 2]))
                case .ouverture, .mur:
                    break
                }
            }

            // 3. Chaînes de cotes à l'extérieur de chaque mur
            let fin = StrokeStyle(lineWidth: 0.6)
            for (index, mur) in murs.enumerated() {
                let longueur = mur.longueur
                guard longueur > 0.05 else { continue }
                let dx = (mur.x2 - mur.x1) / longueur, dy = (mur.y2 - mur.y1) / longueur
                let n = normale(mur, exterieur: true)
                let angle = atan2(dy, dx)

                // positions des portes / fenêtres le long du mur
                var positions: [Double] = [0, longueur]
                for o in traits where o.genre != .mur {
                    let t1 = (o.x1 - mur.x1) * dx + (o.y1 - mur.y1) * dy
                    let t2 = (o.x2 - mur.x1) * dx + (o.y2 - mur.y1) * dy
                    let d1 = abs((o.x1 - mur.x1) * n.x + (o.y1 - mur.y1) * n.y)
                    let d2 = abs((o.x2 - mur.x1) * n.x + (o.y2 - mur.y1) * n.y)
                    if d1 < 0.25, d2 < 0.25, min(t1, t2) > -0.1, max(t1, t2) < longueur + 0.1 {
                        positions.append(min(max(t1, 0), longueur))
                        positions.append(min(max(t2, 0), longueur))
                    }
                }
                positions.sort()
                var uniques: [Double] = []
                for p in positions where uniques.last.map({ p - $0 > 0.03 }) ?? true { uniques.append(p) }
                if let dernier = uniques.last, longueur - dernier > 0.0001, longueur - dernier <= 0.03 {
                    uniques[uniques.count - 1] = longueur
                }

                func surChaine(_ t: Double, _ ecart: CGFloat) -> CGPoint {
                    let p = point(mur.x1 + dx * t, mur.y1 + dy * t)
                    return CGPoint(x: p.x + n.x * ecart, y: p.y + n.y * ecart)
                }

                let chaines: [(ecart: CGFloat, reperes: [Double])] = uniques.count > 2
                    ? [(18, uniques), (40, [0, longueur])]
                    : [(18, [0, longueur])]

                for chaine in chaines {
                    ligne(surChaine(0, chaine.ecart), surChaine(longueur, chaine.ecart), fin, encre)
                    for t in chaine.reperes {
                        // ligne d'attache depuis le mur et petit trait oblique
                        ligne(surChaine(t, 6), surChaine(t, chaine.ecart + 4), StrokeStyle(lineWidth: 0.4), encre)
                        let c = surChaine(t, chaine.ecart)
                        ligne(CGPoint(x: c.x - (dx + n.x) * 3, y: c.y - (dy + n.y) * 3),
                              CGPoint(x: c.x + (dx + n.x) * 3, y: c.y + (dy + n.y) * 3),
                              StrokeStyle(lineWidth: 1), encre)
                    }
                    for (debut, finSegment) in zip(chaine.reperes, chaine.reperes.dropFirst()) {
                        let morceau = finSegment - debut
                        guard morceau * echelle > 16 else { continue }
                        texte(morceau.formatted(.number.precision(.fractionLength(2))),
                              surChaine((debut + finSegment) / 2, chaine.ecart + 7),
                              angle: angle, taillePolice: 7.5)
                    }
                }

                if numeros {
                    let interieur = normale(mur, exterieur: false)
                    let m = point((mur.x1 + mur.x2) / 2, (mur.y1 + mur.y2) / 2)
                    let c = CGPoint(x: m.x + interieur.x * 14, y: m.y + interieur.y * 14)
                    contexte.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)),
                                  with: .color(.accentColor))
                    contexte.draw(Text("\(index + 1)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white),
                                  at: c)
                }
            }

            // 4. Nom, surface et dimensions au centre
            let centre = point((minX + maxX) / 2, (minY + maxY) / 2)
            if let nom, !nom.isEmpty {
                texte(nom, CGPoint(x: centre.x, y: centre.y - 8), angle: 0, taillePolice: 11, gras: true)
            }
            texte("\(largeur.formatted(.number.precision(.fractionLength(2)))) × \(profondeur.formatted(.number.precision(.fractionLength(2)))) m",
                  CGPoint(x: centre.x, y: centre.y + 7), angle: 0, taillePolice: 8)

            // 5. Échelle graphique
            if echelleVisible {
                let pasMetres: Double = largeur > 12 ? 2 : 1
                let nombre = 3
                let origine = CGPoint(x: 12, y: taille.height - 12)
                for i in 0..<nombre {
                    let rect = CGRect(x: origine.x + CGFloat(Double(i) * pasMetres) * echelle, y: origine.y - 5,
                                      width: CGFloat(pasMetres) * echelle, height: 5)
                    contexte.fill(Path(rect), with: i % 2 == 0 ? encre : fond)
                    contexte.stroke(Path(rect), with: encre, lineWidth: 0.6)
                }
                for i in 0...nombre {
                    contexte.draw(Text("\(Int(Double(i) * pasMetres)) m")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.secondary),
                                  at: CGPoint(x: origine.x + CGFloat(Double(i) * pasMetres) * echelle, y: origine.y - 12))
                }
            }
        }
    }
}
