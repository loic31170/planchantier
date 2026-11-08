import SwiftUI
import SceneKit

/// Bibliothèque de mobilier pour aménager les pièces en 3D.
/// Chaque meuble est construit en volumes simples, aux dimensions courantes (en mètres).
/// Repère : origine au sol, au centre du meuble ; la face avant regarde vers +z.

enum CategorieMeuble: String, CaseIterable, Identifiable {
    case cuisine = "Cuisine"
    case salon = "Salon"
    case chambre = "Chambre"
    case salleDeBain = "Salle de bain"
    case divers = "Divers"

    var id: String { rawValue }

    var symbole: String {
        switch self {
        case .cuisine: return "fork.knife"
        case .salon: return "sofa"
        case .chambre: return "bed.double"
        case .salleDeBain: return "bathtub"
        case .divers: return "square.grid.2x2"
        }
    }
}

struct ModeleMeuble: Identifiable {
    let id: String
    let nom: String
    let categorie: CategorieMeuble
    let symbole: String
    /// Largeur × profondeur × hauteur en mètres
    let dimensions: (Float, Float, Float)
    let construire: () -> SCNNode

    var libelleDimensions: String {
        let (l, p, h) = dimensions
        return "\(Int((l * 100).rounded())) × \(Int((p * 100).rounded())) × \(Int((h * 100).rounded())) cm"
    }
}

// MARK: - Volumes de base

private enum Teinte {
    static let blanc = UIColor(white: 0.95, alpha: 1)
    static let bois = UIColor(red: 0.76, green: 0.60, blue: 0.42, alpha: 1)
    static let boisFonce = UIColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1)
    static let inox = UIColor(white: 0.75, alpha: 1)
    static let noir = UIColor(white: 0.12, alpha: 1)
    static let gris = UIColor(white: 0.35, alpha: 1)
    static let tissu = UIColor(red: 0.42, green: 0.50, blue: 0.56, alpha: 1)
    static let tissuClair = UIColor(red: 0.86, green: 0.82, blue: 0.75, alpha: 1)
    static let eau = UIColor(red: 0.84, green: 0.92, blue: 0.97, alpha: 1)
    static let verre = UIColor(red: 0.80, green: 0.90, blue: 0.95, alpha: 0.3)
    static let vert = UIColor(red: 0.30, green: 0.55, blue: 0.30, alpha: 1)
    static let terre = UIColor(red: 0.72, green: 0.42, blue: 0.28, alpha: 1)
}

private func matiere(_ couleur: UIColor) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = couleur
    m.lightingModel = .physicallyBased
    m.roughness.contents = 0.75
    m.metalness.contents = 0.0
    if couleur.cgColor.alpha < 1 {
        m.transparency = couleur.cgColor.alpha
        m.isDoubleSided = true
    }
    return m
}

/// Boîte posée à la hauteur `y` (base), centrée en x et z.
private func boite(_ l: Float, _ h: Float, _ p: Float,
                   x: Float = 0, y: Float = 0, z: Float = 0,
                   _ couleur: UIColor, arrondi: Float = 0.008) -> SCNNode {
    let g = SCNBox(width: CGFloat(l), height: CGFloat(h), length: CGFloat(p),
                   chamferRadius: CGFloat(min(arrondi, min(l, min(h, p)) / 2)))
    g.firstMaterial = matiere(couleur)
    let n = SCNNode(geometry: g)
    n.position = SCNVector3(x, y + h / 2, z)
    return n
}

/// Cylindre vertical posé à la hauteur `y`.
private func cylindre(rayon: Float, _ h: Float, x: Float = 0, y: Float = 0, z: Float = 0,
                      _ couleur: UIColor) -> SCNNode {
    let g = SCNCylinder(radius: CGFloat(rayon), height: CGFloat(h))
    g.firstMaterial = matiere(couleur)
    let n = SCNNode(geometry: g)
    n.position = SCNVector3(x, y + h / 2, z)
    return n
}

private func groupe(_ enfants: [SCNNode]) -> SCNNode {
    let n = SCNNode()
    enfants.forEach { n.addChildNode($0) }
    return n
}

private func pieds(_ l: Float, _ p: Float, hauteur: Float, section: Float = 0.045, _ couleur: UIColor) -> [SCNNode] {
    let dx = l / 2 - section, dz = p / 2 - section
    return [(-dx, -dz), (dx, -dz), (-dx, dz), (dx, dz)].map { boite(section, hauteur, section, x: $0.0, z: $0.1, couleur) }
}

// MARK: - Construction des meubles

private func caissonBas(largeur l: Float = 0.6) -> [SCNNode] {
    [boite(l, 0.1, 0.52, z: -0.03, Teinte.gris),
     boite(l, 0.76, 0.58, y: 0.1, Teinte.blanc),
     boite(l, 0.04, 0.62, y: 0.86, z: 0.01, Teinte.gris)]
}

private func assise(largeur l: Float, profondeur p: Float, accoudoirs: Bool = true) -> SCNNode {
    var parties = [
        boite(l, 0.42, p, Teinte.tissu, arrondi: 0.04),
        boite(l, 0.45, 0.2, y: 0.4, z: -(p / 2 - 0.1), Teinte.tissu, arrondi: 0.05)
    ]
    if accoudoirs {
        parties.append(boite(0.18, 0.22, p, x: -(l / 2 - 0.09), y: 0.4, Teinte.tissu, arrondi: 0.05))
        parties.append(boite(0.18, 0.22, p, x: l / 2 - 0.09, y: 0.4, Teinte.tissu, arrondi: 0.05))
    }
    return groupe(parties)
}

private func lit(largeur l: Float, longueur p: Float) -> SCNNode {
    var parties: [SCNNode] = [
        boite(l + 0.06, 0.28, p + 0.06, Teinte.bois),
        boite(l, 0.2, p, y: 0.28, Teinte.blanc, arrondi: 0.04),
        boite(l + 0.06, 1.0, 0.06, z: -(p / 2 + 0.06), Teinte.boisFonce),
        boite(l + 0.02, 0.05, p * 0.6, y: 0.48, z: p * 0.18, Teinte.tissu, arrondi: 0.02)
    ]
    let zOreiller: Float = -(p / 2 - 0.25)
    if l > 1 {
        let largeurOreiller: Float = l * 0.42
        let ecart: Float = l * 0.24
        parties.append(boite(largeurOreiller, 0.1, 0.35, x: -ecart, y: 0.48, z: zOreiller, Teinte.tissuClair, arrondi: 0.04))
        parties.append(boite(largeurOreiller, 0.1, 0.35, x: ecart, y: 0.48, z: zOreiller, Teinte.tissuClair, arrondi: 0.04))
    } else {
        parties.append(boite(l * 0.8, 0.1, 0.35, y: 0.48, z: zOreiller, Teinte.tissuClair, arrondi: 0.04))
    }
    return groupe(parties)
}

enum Bibliotheque3D {
    static let modeles: [ModeleMeuble] = [
        // Cuisine
        ModeleMeuble(id: "meuble-bas", nom: "Meuble bas", categorie: .cuisine, symbole: "rectangle.split.2x1",
                     dimensions: (0.6, 0.6, 0.9)) { groupe(caissonBas()) },
        ModeleMeuble(id: "four", nom: "Four sous plan", categorie: .cuisine, symbole: "oven",
                     dimensions: (0.6, 0.6, 0.9)) {
            groupe(caissonBas() + [boite(0.56, 0.48, 0.01, y: 0.2, z: 0.295, Teinte.noir),
                                   boite(0.46, 0.02, 0.025, y: 0.72, z: 0.31, Teinte.inox)])
        },
        ModeleMeuble(id: "plaque", nom: "Plaque de cuisson", categorie: .cuisine, symbole: "flame",
                     dimensions: (0.6, 0.6, 0.9)) {
            groupe(caissonBas() + [boite(0.56, 0.006, 0.5, y: 0.9, Teinte.noir)])
        },
        ModeleMeuble(id: "evier", nom: "Évier", categorie: .cuisine, symbole: "drop",
                     dimensions: (1.2, 0.6, 0.9)) {
            groupe(caissonBas(largeur: 1.2) + [boite(0.9, 0.006, 0.45, y: 0.9, Teinte.inox),
                                               cylindre(rayon: 0.015, 0.3, y: 0.9, z: -0.24, Teinte.inox)])
        },
        ModeleMeuble(id: "lave-vaisselle", nom: "Lave-vaisselle", categorie: .cuisine, symbole: "dishwasher",
                     dimensions: (0.6, 0.6, 0.85)) {
            groupe([boite(0.6, 0.85, 0.6, Teinte.blanc), boite(0.58, 0.08, 0.01, y: 0.74, z: 0.3, Teinte.noir)])
        },
        ModeleMeuble(id: "frigo", nom: "Réfrigérateur", categorie: .cuisine, symbole: "refrigerator",
                     dimensions: (0.6, 0.65, 1.85)) {
            groupe([boite(0.6, 1.85, 0.65, Teinte.blanc),
                    boite(0.6, 0.01, 0.01, y: 1.15, z: 0.326, Teinte.gris),
                    boite(0.02, 0.4, 0.03, x: 0.25, y: 1.25, z: 0.34, Teinte.inox),
                    boite(0.02, 0.3, 0.03, x: 0.25, y: 0.75, z: 0.34, Teinte.inox)])
        },
        ModeleMeuble(id: "meuble-haut", nom: "Meuble haut", categorie: .cuisine, symbole: "rectangle.topthird.inset.filled",
                     dimensions: (0.6, 0.35, 0.7)) { groupe([boite(0.6, 0.7, 0.35, y: 1.45, z: -0.125, Teinte.blanc)]) },
        ModeleMeuble(id: "hotte", nom: "Hotte", categorie: .cuisine, symbole: "wind",
                     dimensions: (0.6, 0.5, 0.8)) {
            groupe([boite(0.6, 0.08, 0.5, y: 1.55, Teinte.inox), boite(0.25, 0.7, 0.25, y: 1.63, z: -0.12, Teinte.inox)])
        },
        ModeleMeuble(id: "table", nom: "Table 4 personnes", categorie: .cuisine, symbole: "table.furniture",
                     dimensions: (1.2, 0.8, 0.75)) {
            groupe([boite(1.2, 0.04, 0.8, y: 0.71, Teinte.bois)] + pieds(1.2, 0.8, hauteur: 0.71, Teinte.boisFonce))
        },
        ModeleMeuble(id: "chaise", nom: "Chaise", categorie: .cuisine, symbole: "chair",
                     dimensions: (0.45, 0.5, 0.9)) {
            groupe([boite(0.45, 0.04, 0.45, y: 0.45, Teinte.bois),
                    boite(0.45, 0.42, 0.04, y: 0.49, z: -0.205, Teinte.bois)] + pieds(0.45, 0.45, hauteur: 0.45, section: 0.035, Teinte.boisFonce))
        },
        // Salon
        ModeleMeuble(id: "canape", nom: "Canapé 3 places", categorie: .salon, symbole: "sofa",
                     dimensions: (2.1, 0.9, 0.85)) { assise(largeur: 2.1, profondeur: 0.9) },
        ModeleMeuble(id: "fauteuil", nom: "Fauteuil", categorie: .salon, symbole: "chair.lounge",
                     dimensions: (0.85, 0.85, 0.85)) { assise(largeur: 0.85, profondeur: 0.85) },
        ModeleMeuble(id: "table-basse", nom: "Table basse", categorie: .salon, symbole: "rectangle",
                     dimensions: (1.1, 0.6, 0.4)) {
            groupe([boite(1.1, 0.04, 0.6, y: 0.36, Teinte.bois)] + pieds(1.1, 0.6, hauteur: 0.36, Teinte.boisFonce))
        },
        ModeleMeuble(id: "meuble-tv", nom: "Meuble TV et écran", categorie: .salon, symbole: "tv",
                     dimensions: (1.6, 0.4, 1.25)) {
            groupe([boite(1.6, 0.5, 0.4, Teinte.bois),
                    boite(1.23, 0.72, 0.05, y: 0.53, Teinte.noir),
                    boite(0.3, 0.03, 0.2, y: 0.5, Teinte.noir)])
        },
        ModeleMeuble(id: "bibliotheque", nom: "Bibliothèque", categorie: .salon, symbole: "books.vertical",
                     dimensions: (0.8, 0.3, 2.0)) {
            groupe([boite(0.8, 2.0, 0.02, z: -0.14, Teinte.bois),
                    boite(0.02, 2.0, 0.3, x: -0.39, Teinte.bois),
                    boite(0.02, 2.0, 0.3, x: 0.39, Teinte.bois)]
                   + (0..<5).map { boite(0.76, 0.02, 0.28, y: Float($0) * 0.49, Teinte.bois) })
        },
        // Chambre
        ModeleMeuble(id: "lit-140", nom: "Lit 140 × 190", categorie: .chambre, symbole: "bed.double",
                     dimensions: (1.46, 2.02, 1.0)) { lit(largeur: 1.4, longueur: 1.9) },
        ModeleMeuble(id: "lit-160", nom: "Lit 160 × 200", categorie: .chambre, symbole: "bed.double.fill",
                     dimensions: (1.66, 2.12, 1.0)) { lit(largeur: 1.6, longueur: 2.0) },
        ModeleMeuble(id: "lit-90", nom: "Lit 90 × 190", categorie: .chambre, symbole: "bed.double",
                     dimensions: (0.96, 2.02, 1.0)) { lit(largeur: 0.9, longueur: 1.9) },
        ModeleMeuble(id: "chevet", nom: "Table de chevet", categorie: .chambre, symbole: "square",
                     dimensions: (0.45, 0.4, 0.5)) { groupe([boite(0.45, 0.5, 0.4, Teinte.bois)]) },
        ModeleMeuble(id: "armoire", nom: "Armoire", categorie: .chambre, symbole: "cabinet",
                     dimensions: (1.2, 0.6, 2.1)) {
            groupe([boite(1.2, 2.1, 0.6, Teinte.bois), boite(0.006, 2.0, 0.01, y: 0.05, z: 0.3, Teinte.boisFonce)])
        },
        ModeleMeuble(id: "bureau", nom: "Bureau", categorie: .chambre, symbole: "desktopcomputer",
                     dimensions: (1.2, 0.6, 0.75)) {
            groupe([boite(1.2, 0.03, 0.6, y: 0.72, Teinte.blanc)] + pieds(1.2, 0.6, hauteur: 0.72, Teinte.gris))
        },
        // Salle de bain
        ModeleMeuble(id: "baignoire", nom: "Baignoire", categorie: .salleDeBain, symbole: "bathtub",
                     dimensions: (1.7, 0.7, 0.58)) {
            groupe([boite(1.7, 0.58, 0.7, Teinte.blanc), boite(1.5, 0.01, 0.52, y: 0.575, Teinte.eau)])
        },
        ModeleMeuble(id: "douche", nom: "Douche 90 × 90", categorie: .salleDeBain, symbole: "shower",
                     dimensions: (0.9, 0.9, 2.0)) {
            groupe([boite(0.9, 0.05, 0.9, Teinte.blanc),
                    boite(0.9, 1.95, 0.01, y: 0.05, z: 0.445, Teinte.verre),
                    boite(0.01, 1.95, 0.9, x: 0.445, y: 0.05, Teinte.verre),
                    cylindre(rayon: 0.1, 0.02, x: -0.3, y: 1.95, z: -0.3, Teinte.inox)])
        },
        ModeleMeuble(id: "vasque", nom: "Meuble vasque", categorie: .salleDeBain, symbole: "sink",
                     dimensions: (0.8, 0.48, 1.8)) {
            groupe([boite(0.8, 0.5, 0.46, y: 0.35, Teinte.bois),
                    boite(0.8, 0.05, 0.48, y: 0.85, Teinte.blanc),
                    boite(0.8, 0.7, 0.02, y: 1.1, z: -0.23, Teinte.inox)])
        },
        ModeleMeuble(id: "wc", nom: "WC", categorie: .salleDeBain, symbole: "toilet",
                     dimensions: (0.38, 0.65, 0.8)) {
            groupe([cylindre(rayon: 0.18, 0.4, z: 0.08, Teinte.blanc),
                    boite(0.38, 0.8, 0.18, z: -0.2, Teinte.blanc)])
        },
        ModeleMeuble(id: "lave-linge", nom: "Lave-linge", categorie: .salleDeBain, symbole: "washer",
                     dimensions: (0.6, 0.6, 0.85)) {
            let hublot = cylindre(rayon: 0.17, 0.02, Teinte.gris)
            hublot.eulerAngles.x = .pi / 2
            hublot.position = SCNVector3(0, 0.45, 0.3)
            return groupe([boite(0.6, 0.85, 0.6, Teinte.blanc), hublot])
        },
        // Divers
        ModeleMeuble(id: "radiateur", nom: "Radiateur", categorie: .divers, symbole: "heater.vertical",
                     dimensions: (0.8, 0.08, 0.75)) { groupe([boite(0.8, 0.6, 0.08, y: 0.15, Teinte.blanc)]) },
        ModeleMeuble(id: "tapis", nom: "Tapis", categorie: .divers, symbole: "rectangle.dashed",
                     dimensions: (2.0, 1.4, 0.01)) { groupe([boite(2.0, 0.01, 1.4, Teinte.tissuClair, arrondi: 0)]) },
        ModeleMeuble(id: "plante", nom: "Plante", categorie: .divers, symbole: "leaf",
                     dimensions: (0.6, 0.6, 1.0)) {
            let feuillage = SCNNode(geometry: SCNSphere(radius: 0.3))
            feuillage.geometry?.firstMaterial = matiere(Teinte.vert)
            feuillage.position = SCNVector3(0, 0.6, 0)
            return groupe([cylindre(rayon: 0.15, 0.32, Teinte.terre), feuillage])
        },
        ModeleMeuble(id: "carton", nom: "Volume libre 1 m³", categorie: .divers, symbole: "cube",
                     dimensions: (1, 1, 1)) { groupe([boite(1, 1, 1, Teinte.tissuClair)]) },
    ]

    static func modele(_ id: String) -> ModeleMeuble? {
        modeles.first { $0.id == id }
    }
}

// MARK: - Écran de choix

struct BibliothequeMeublesView: View {
    var quandChoisi: (ModeleMeuble) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var categorie: CategorieMeuble = .cuisine

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CategorieMeuble.allCases) { c in
                            Button {
                                categorie = c
                            } label: {
                                Label(c.rawValue, systemImage: c.symbole)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(categorie == c ? Color.accentColor : Color(.secondarySystemBackground),
                                                in: Capsule())
                                    .foregroundStyle(categorie == c ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(Bibliotheque3D.modeles.filter { $0.categorie == categorie }) { modele in
                            Button {
                                quandChoisi(modele)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Image(systemName: modele.symbole)
                                        .font(.title2)
                                        .foregroundStyle(Color.accentColor)
                                        .frame(height: 30)
                                    Text(modele.nom)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(modele.libelleDimensions)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Mobilier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
