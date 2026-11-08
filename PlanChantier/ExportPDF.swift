import SwiftUI
import UIKit

/// Génère le PDF d'un chantier : page de garde, une page par pièce, puis les photos.
@MainActor
enum ExportPDF {
    static let largeur: CGFloat = 595   // A4 en points
    static let hauteur: CGFloat = 842

    static func generer(_ chantier: Chantier) -> URL? {
        let pieces = chantier.pieces.sorted { $0.dateScan < $1.dateScan }

        var pages: [AnyView] = [AnyView(PageGardePDF(chantier: chantier, pieces: pieces))]
        for (index, etage) in chantier.etages.enumerated() {
            pages.append(AnyView(PageEtagePDF(chantier: chantier, titre: "Plan d'étage \(index + 1)", pieces: etage)))
        }
        for piece in pieces {
            pages.append(AnyView(PagePiecePDF(piece: piece)))
            let photos = piece.photos
            for debut in stride(from: 0, to: photos.count, by: 6) {
                let groupe = Array(photos[debut..<min(debut + 6, photos.count)])
                pages.append(AnyView(PagePhotosPDF(titre: piece.nom, photos: groupe)))
            }
        }

        let nom = chantier.nom
            .replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespaces)
        return rendre(pages: pages, nomFichier: "Relevé \(nom.isEmpty ? "chantier" : nom)")
    }

    /// Assemble des pages A4 en un fichier PDF, avec la numérotation des pages.
    static func rendre(pages: [AnyView], nomFichier: String) -> URL? {
        let url = URL.temporaryDirectory.appending(path: "\(nomFichier).pdf")
        var boite = CGRect(x: 0, y: 0, width: largeur, height: hauteur)
        guard let pdf = CGContext(url as CFURL, mediaBox: &boite, nil) else { return nil }

        for (index, page) in pages.enumerated() {
            let contenu = page
                .overlay(alignment: .bottomTrailing) {
                    Text("Page \(index + 1) / \(pages.count)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .padding(24)
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

// MARK: - Pages

private struct EnTetePDF: View {
    let surtitre: String
    let titre: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(surtitre.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(titre)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
        }
    }
}

struct PageGardePDF: View {
    let chantier: Chantier
    let pieces: [Piece]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LogoPDF()
            EnTetePDF(surtitre: "Relevé de chantier", titre: chantier.nom)

            VStack(alignment: .leading, spacing: 4) {
                if !chantier.client.isEmpty { ligne("Client", chantier.client) }
                if !chantier.adresse.isEmpty { ligne("Adresse", chantier.adresse) }
                ligne("Date", Date.now.formatted(date: .long, time: .omitted))
            }

            Divider()

            Text("Récapitulatif des pièces")
                .font(.system(size: 13, weight: .semibold))

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    entete("Pièce")
                    entete("Surface sol")
                    entete("Périmètre")
                    entete("Hauteur")
                    entete("Murs (brut)")
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(pieces) { piece in
                    GridRow {
                        cellule(piece.nom)
                        cellule(piece.surfaceSol.enMetresCarres)
                        cellule(piece.perimetre.enMetres)
                        cellule(piece.hauteur.enMetres)
                        cellule((piece.perimetre * piece.hauteur).enMetresCarres)
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    Text("Total").font(.system(size: 10, weight: .bold))
                    Text(chantier.surfaceTotale.enMetresCarres).font(.system(size: 10, weight: .bold))
                    Text(pieces.reduce(0) { $0 + $1.perimetre }.enMetres).font(.system(size: 10, weight: .bold))
                    Text("")
                    Text(pieces.reduce(0) { $0 + $1.perimetre * $1.hauteur }.enMetresCarres)
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(.black)

            Spacer()

            Text("Mesures issues d'un scan LiDAR, à vérifier avant commande de matériaux.")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(width: ExportPDF.largeur, height: ExportPDF.hauteur, alignment: .topLeading)
    }

    private func ligne(_ titre: String, _ valeur: String) -> some View {
        HStack(alignment: .top) {
            Text(titre).font(.system(size: 10)).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
            Text(valeur).font(.system(size: 10)).foregroundStyle(.black)
        }
    }

    private func entete(_ texte: String) -> some View {
        Text(texte).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
    }

    private func cellule(_ texte: String) -> some View {
        Text(texte).font(.system(size: 10))
    }
}

struct PagePiecePDF: View {
    let piece: Piece

    var body: some View {
        let segments = piece.segments
        let murs = PlanPieceView.mursOrdonnes(segments)
        VStack(alignment: .leading, spacing: 14) {
            EnTetePDF(surtitre: piece.chantier?.nom ?? "Pièce", titre: piece.nom)

            PlanPieceView(segments: segments)
                .frame(width: ExportPDF.largeur - 80, height: 390)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
            LegendePlan()

            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Mesures").font(.system(size: 12, weight: .semibold))
                    mesure("Surface au sol", piece.surfaceSol.enMetresCarres)
                    mesure("Périmètre", piece.perimetre.enMetres)
                    mesure("Hauteur sous plafond", piece.hauteur.enMetres)
                    mesure("Surface des murs (brute)", piece.surfaceMursBrute.enMetresCarres)
                    mesure("Surface des murs (nette)", piece.surfaceMursNette.enMetresCarres)
                    mesure("Longueur de plinthes", piece.lineairePlinthes.enMetres)
                    mesure("Portes", "\(segments.filter { $0.genre == .porte }.count)")
                    mesure("Fenêtres", "\(segments.filter { $0.genre == .fenetre }.count)")
                }
                .frame(width: 230, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Longueur des murs").font(.system(size: 12, weight: .semibold))
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 3) {
                        ForEach(Array(stride(from: 0, to: murs.count, by: 2)), id: \.self) { i in
                            GridRow {
                                Text("Mur \(i + 1)").font(.system(size: 9)).foregroundStyle(.secondary)
                                Text(murs[i].longueur.enMetres).font(.system(size: 9, weight: .semibold))
                                if i + 1 < murs.count {
                                    Text("Mur \(i + 2)").font(.system(size: 9)).foregroundStyle(.secondary)
                                    Text(murs[i + 1].longueur.enMetres).font(.system(size: 9, weight: .semibold))
                                }
                            }
                        }
                    }
                }
            }
            .foregroundStyle(.black)

            if !piece.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes").font(.system(size: 12, weight: .semibold))
                    Text(piece.notes).font(.system(size: 10))
                }
                .foregroundStyle(.black)
            }
            Spacer()
        }
        .padding(40)
        .frame(width: ExportPDF.largeur, height: ExportPDF.hauteur, alignment: .topLeading)
    }

    private func mesure(_ titre: String, _ valeur: String) -> some View {
        HStack {
            Text(titre).font(.system(size: 10))
            Spacer()
            Text(valeur).font(.system(size: 10, weight: .semibold))
        }
    }
}

struct PageEtagePDF: View {
    let chantier: Chantier
    let titre: String
    let pieces: [Piece]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EnTetePDF(surtitre: chantier.nom, titre: titre)
            PlanEtageView(pieces: pieces)
                .frame(width: ExportPDF.largeur - 80, height: 480)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
            LegendePlan()
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 5) {
                ForEach(pieces) { piece in
                    GridRow {
                        Text(piece.nom).font(.system(size: 10))
                        Text(piece.surfaceSol.enMetresCarres).font(.system(size: 10, weight: .semibold))
                    }
                }
                GridRow {
                    Text("Total").font(.system(size: 10, weight: .bold))
                    Text(pieces.reduce(0) { $0 + $1.surfaceSol }.enMetresCarres).font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(.black)
            Spacer()
        }
        .padding(40)
        .frame(width: ExportPDF.largeur, height: ExportPDF.hauteur, alignment: .topLeading)
    }
}

struct PagePhotosPDF: View {
    let titre: String
    let photos: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            EnTetePDF(surtitre: "Photos", titre: titre)
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(Array(stride(from: 0, to: photos.count, by: 2)), id: \.self) { i in
                    GridRow {
                        vignette(photos[i])
                        if i + 1 < photos.count {
                            vignette(photos[i + 1])
                        } else {
                            Color.clear.frame(width: 251, height: 220)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(40)
        .frame(width: ExportPDF.largeur, height: ExportPDF.hauteur, alignment: .topLeading)
    }

    @ViewBuilder
    private func vignette(_ nom: String) -> some View {
        if let image = StockagePhotos.image(nom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 251, height: 220)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Color.gray.opacity(0.1).frame(width: 251, height: 220)
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
