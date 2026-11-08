import SwiftUI
import UIKit
import MapKit

/// Génère le relevé PDF d'un chantier : page de garde avec carte, plans d'étage,
/// une page cotée par pièce, puis les photos étiquetées.
@MainActor
enum ExportPDF {
    static let largeur: CGFloat = 595   // A4 en points
    static let hauteur: CGFloat = 842
    static let avertissement = "Plans établis à partir d'un scan LiDAR, sans garantie d'exactitude. Mesures à vérifier avant toute commande ou fabrication."

    static func generer(_ chantier: Chantier) async -> URL? {
        let carte = await instantaneCarte(chantier)
        let pieces = chantier.pieces.sorted { $0.dateScan < $1.dateScan }

        var pages: [AnyView] = [AnyView(PageGardePDF(chantier: chantier, pieces: pieces, carte: carte))]
        for (index, etage) in chantier.etages.enumerated() {
            pages.append(AnyView(PageEtagePDF(chantier: chantier, titre: "Plan d'étage \(index + 1)", pieces: etage)))
        }
        for piece in pieces {
            pages.append(AnyView(PagePiecePDF(chantier: chantier, piece: piece)))
        }

        // Photos étiquetées « Salon · Photo 2 »
        var compteurs: [String: Int] = [:]
        let photos: [PhotoEtiquetee] = chantier.toutesLesPhotos.map { photo in
            let n = (compteurs[photo.libelle] ?? 0) + 1
            compteurs[photo.libelle] = n
            return PhotoEtiquetee(nom: photo.nom, etiquette: "\(photo.libelle) · Photo \(n)")
        }
        for debut in stride(from: 0, to: photos.count, by: 9) {
            let groupe = Array(photos[debut..<min(debut + 9, photos.count)])
            pages.append(AnyView(PagePhotosPDF(chantier: chantier, photos: groupe)))
        }

        let nom = chantier.nom
            .replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespaces)
        return rendre(pages: pages, nomFichier: "Relevé \(nom.isEmpty ? "chantier" : nom)", piedDePage: avertissement)
    }

    /// Image de la carte Plans d'Apple centrée sur le chantier, avec un repère.
    static func instantaneCarte(_ chantier: Chantier) async -> UIImage? {
        guard let point = chantier.coordonnees else { return nil }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: point, latitudinalMeters: 500, longitudinalMeters: 500)
        options.size = CGSize(width: 260, height: 170)
        options.scale = 3
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)
        guard let cliche = try? await MKMapSnapshotter(options: options).start() else { return nil }
        let repere = cliche.point(for: point)
        return UIGraphicsImageRenderer(size: options.size).image { _ in
            cliche.image.draw(at: .zero)
            let rond = CGRect(x: repere.x - 7, y: repere.y - 7, width: 14, height: 14)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: rond.insetBy(dx: -2, dy: -2)).fill()
            UIColor(named: "AccentColor")?.setFill()
            UIBezierPath(ovalIn: rond).fill()
        }
    }

    /// Assemble des pages A4 en un fichier PDF, avec la numérotation des pages.
    static func rendre(pages: [AnyView], nomFichier: String, piedDePage: String? = nil) -> URL? {
        let url = URL.temporaryDirectory.appending(path: "\(nomFichier).pdf")
        var boite = CGRect(x: 0, y: 0, width: largeur, height: hauteur)
        guard let pdf = CGContext(url as CFURL, mediaBox: &boite, nil) else { return nil }

        for (index, page) in pages.enumerated() {
            let contenu = page
                .overlay(alignment: .bottom) {
                    HStack(alignment: .bottom) {
                        if let piedDePage {
                            Text(piedDePage)
                                .font(.system(size: 6.5))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 380, alignment: .leading)
                        }
                        Spacer()
                        Text("Page \(index + 1) / \(pages.count)")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
                .frame(width: largeur, height: hauteur)
                .background(Color.white)
                .environment(\.colorScheme, .light)
            let rendu = ImageRenderer(content: contenu)
            rendu.render { _, dessiner in
                pdf.beginPDFPage(nil)
                dessiner(pdf)
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return url
    }
}

struct PhotoEtiquetee: Hashable {
    var nom: String
    var etiquette: String
}

// MARK: - Éléments communs

/// Bandeau en haut des pages intérieures : chantier, adresse, chiffres clés, logo.
struct BandeauPDF: View {
    let chantier: Chantier

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chantier.nom)
                        .font(.system(size: 11, weight: .bold))
                    Text([chantier.adresse.replacingOccurrences(of: "\n", with: ", "),
                          "Surface totale \(chantier.surfaceTotale.enMetresCarres)",
                          "Étages \(chantier.etages.count)",
                          "Pièces \(chantier.pieces.count)"]
                            .filter { !$0.isEmpty }
                            .joined(separator: "  ·  "))
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                LogoPDF(hauteurMax: 28)
            }
            Rectangle().fill(Color.accentColor).frame(height: 1.5)
        }
        .foregroundStyle(.black)
    }
}

struct TitreSectionPDF: View {
    let titre: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 7))
                .foregroundStyle(Color.accentColor)
            Text(titre)
                .font(.system(size: 13, weight: .bold))
            if let detail {
                Text(detail)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.black)
    }
}

private struct CelluleChiffre: View {
    let titre: String
    let valeur: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titre.uppercased())
                .font(.system(size: 6.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(valeur)
                .font(.system(size: 12, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
    }
}

// MARK: - Page de garde

struct PageGardePDF: View {
    let chantier: Chantier
    let pieces: [Piece]
    let carte: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RELEVÉ DE CHANTIER")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(chantier.nom)
                        .font(.system(size: 26, weight: .bold))
                }
                Spacer()
                LogoPDF(hauteurMax: 60)
            }

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    info("Créé le", chantier.dateCreation.formatted(date: .long, time: .omitted))
                    if !chantier.client.isEmpty { info("Client", chantier.client) }
                    if !chantier.adresse.isEmpty { info("Adresse", chantier.adresse) }
                    if !chantier.descriptionChantier.isEmpty { info("Description", chantier.descriptionChantier) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let carte {
                    Image(uiImage: carte)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 250, height: 163)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }
            }

            HStack(spacing: 0) {
                CelluleChiffre(titre: "Surface au sol", valeur: chantier.surfaceTotale.enMetresCarres)
                Divider()
                CelluleChiffre(titre: "Surface murale", valeur: chantier.surfaceMursTotale.enMetresCarres)
                Divider()
                CelluleChiffre(titre: "Étages", valeur: "\(chantier.etages.count)")
                Divider()
                CelluleChiffre(titre: "Pièces", valeur: "\(chantier.pieces.count)")
            }
            .fixedSize(horizontal: false, vertical: true)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.35)))

            VStack(alignment: .leading, spacing: 8) {
                TitreSectionPDF(titre: "Récapitulatif des pièces")
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        entete("Pièce")
                        entete("Surface sol")
                        entete("Périmètre")
                        entete("Hauteur")
                        entete("Murs (nets)")
                        entete("Plinthes")
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ForEach(pieces) { piece in
                        GridRow {
                            cellule(piece.nom)
                            cellule(piece.surfaceSol.enMetresCarres)
                            cellule(piece.perimetre.enMetres)
                            cellule(piece.hauteur.enMetres)
                            cellule(piece.surfaceMursNette.enMetresCarres)
                            cellule(piece.lineairePlinthes.enMetres)
                        }
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    GridRow {
                        Text("Total").font(.system(size: 9.5, weight: .bold))
                        Text(chantier.surfaceTotale.enMetresCarres).font(.system(size: 9.5, weight: .bold))
                        Text(pieces.reduce(0) { $0 + $1.perimetre }.enMetres).font(.system(size: 9.5, weight: .bold))
                        Text("")
                        Text(chantier.surfaceMursTotale.enMetresCarres).font(.system(size: 9.5, weight: .bold))
                        Text(pieces.reduce(0) { $0 + $1.lineairePlinthes }.enMetres).font(.system(size: 9.5, weight: .bold))
                    }
                }
            }
            Spacer()
        }
        .foregroundStyle(.black)
        .padding(40)
        .frame(width: ExportPDF.largeur, height: ExportPDF.hauteur, alignment: .topLeading)
    }

    private func info(_ titre: String, _ valeur: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titre.uppercased())
                .font(.system(size: 6.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(valeur).font(.system(size: 9.5))
        }
    }

    private func entete(_ texte: String) -> some View {
        Text(texte).font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
    }

    private func cellule(_ texte: String) -> some View {
        Text(texte).font(.system(size: 9.5))
    }
}

// MARK: - Plan d'étage

struct PageEtagePDF: View {
    let chantier: Chantier
    let titre: String
    let pieces: [Piece]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BandeauPDF(chantier: chantier)
            TitreSectionPDF(titre: titre,
                            detail: "\(pieces.count) pièces · \(pieces.reduce(0) { $0 + $1.surfaceSol }.enMetresCarres)")
            PlanEtageView(pieces: pieces, epaisseur: 5, marge: 20)
                .frame(width: ExportPDF.largeur - 80, height: 520)
            LegendePlan()
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 5) {
                ForEach(pieces) { piece in
                    GridRow {
                        Text(piece.nom).font(.system(size: 9.5))
                        Text(piece.surfaceSol.enMetresCarres).font(.system(size: 9.5, weight: .semibold))
                    }
                }
            }
            .foregroundStyle(.black)
            Spacer()
        }
        .padding(40)
        .frame(width: ExportPDF.largeur, height: ExportPDF.hauteur, alignment: .topLeading)
    }
}

// MARK: - Page d'une pièce

struct PagePiecePDF: View {
    let chantier: Chantier
    let piece: Piece

    var body: some View {
        let segments = piece.segments
        let murs = PlanPieceView.mursOrdonnes(segments)
        VStack(alignment: .leading, spacing: 12) {
            BandeauPDF(chantier: chantier)
            TitreSectionPDF(titre: piece.nom,
                            detail: "Surface \(piece.surfaceSol.enMetresCarres)  ·  Périmètre \(piece.perimetre.enMetres)  ·  Hauteur sous plafond \(piece.hauteur.enMetres)")

            PlanCoteView(segments: segments, nom: piece.nom)
                .frame(width: ExportPDF.largeur - 80, height: 430)

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Mesures").font(.system(size: 11, weight: .semibold))
                    mesure("Surface au sol", piece.surfaceSol.enMetresCarres)
                    mesure("Périmètre", piece.perimetre.enMetres)
                    mesure("Hauteur sous plafond", piece.hauteur.enMetres)
                    mesure("Surface des murs (brute)", piece.surfaceMursBrute.enMetresCarres)
                    mesure("Surface des murs (nette)", piece.surfaceMursNette.enMetresCarres)
                    mesure("Longueur de plinthes", piece.lineairePlinthes.enMetres)
                    mesure("Portes", "\(segments.filter { $0.genre == .porte }.count)")
                    mesure("Fenêtres", "\(segments.filter { $0.genre == .fenetre }.count)")
                }
                .frame(width: 220, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Longueur des murs").font(.system(size: 11, weight: .semibold))
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 3) {
                        ForEach(Array(stride(from: 0, to: murs.count, by: 2)), id: \.self) { i in
                            GridRow {
                                Text("Mur \(i + 1)").font(.system(size: 8.5)).foregroundStyle(.secondary)
                                Text(murs[i].longueur.enMetres).font(.system(size: 8.5, weight: .semibold))
                                if i + 1 < murs.count {
                                    Text("Mur \(i + 2)").font(.system(size: 8.5)).foregroundStyle(.secondary)
                                    Text(murs[i + 1].longueur.enMetres).font(.system(size: 8.5, weight: .semibold))
                                }
                            }
                        }
                    }
                }
            }
            .foregroundStyle(.black)

            if !piece.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes").font(.system(size: 11, weight: .semibold))
                    Text(piece.notes).font(.system(size: 9))
                }
                .foregroundStyle(.black)
            }
            if !piece.photos.isEmpty {
                Text("\(piece.photos.count) photo\(piece.photos.count > 1 ? "s" : "") (voir les pages photos)")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(40)
        .frame(width: ExportPDF.largeur, height: ExportPDF.hauteur, alignment: .topLeading)
    }

    private func mesure(_ titre: String, _ valeur: String) -> some View {
        HStack {
            Text(titre).font(.system(size: 9))
            Spacer()
            Text(valeur).font(.system(size: 9, weight: .semibold))
        }
    }
}

// MARK: - Photos

struct PagePhotosPDF: View {
    let chantier: Chantier
    let photos: [PhotoEtiquetee]

    private let cote: CGFloat = 164

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BandeauPDF(chantier: chantier)
            TitreSectionPDF(titre: "Photos")
            Grid(horizontalSpacing: 11, verticalSpacing: 14) {
                ForEach(Array(stride(from: 0, to: photos.count, by: 3)), id: \.self) { i in
                    GridRow {
                        ForEach(i..<min(i + 3, photos.count), id: \.self) { j in
                            vignette(photos[j])
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(40)
        .frame(width: ExportPDF.largeur, height: ExportPDF.hauteur, alignment: .topLeading)
    }

    private func vignette(_ photo: PhotoEtiquetee) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let image = StockagePhotos.image(photo.nom) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray.opacity(0.1)
                }
            }
            .frame(width: cote, height: cote * 1.1)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(alignment: .topLeading) {
                Text(photo.etiquette)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.yellow, in: RoundedRectangle(cornerRadius: 3))
                    .padding(5)
            }
        }
    }
}

// MARK: - Partage

struct DocumentPDF: Identifiable {
    let id = UUID()
    let url: URL
}

/// Feuille de partage iOS (Mail, Messages, AirDrop, Fichiers…).
struct FeuillePartage: UIViewControllerRepresentable {
    let elements: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: elements, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
