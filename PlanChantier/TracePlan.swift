import SwiftUI
import SwiftData
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

/// Créer les pièces à partir d'un plan existant (photo ou PDF de l'architecte) :
/// on met le plan à l'échelle avec une cote connue, puis on clique les coins de chaque pièce.
struct TracePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexte
    let chantier: Chantier

    enum Etape { case source, echelle, trace, ouvertures, nom }

    struct OuvertureTracee: Identifiable {
        let id = UUID()
        var genre: SegmentPlan.Genre
        var mur: Int
        var position: Double
        var largeur: Double
    }

    struct Attente: Identifiable {
        let id = UUID()
        let mur: Int
        let position: Double
    }

    @State private var etape: Etape = .source
    @State private var image: UIImage?
    @State private var pdf: PDFDocument?
    @State private var pagePDF = 0
    @State private var selectionPhoto: PhotosPickerItem?
    @State private var importOuvert = false
    @State private var scannerOuvert = false

    @State private var pointsEchelle: [CGPoint] = []
    @State private var longueurEchelle: Double?
    @State private var metresParPixel: Double?

    @State private var coins: [CGPoint] = []
    @State private var ferme = false
    @State private var orthogonal = true
    @State private var ouvertures: [OuvertureTracee] = []
    @State private var enAttente: Attente?

    @State private var nom = ""
    @State private var hauteur: Double = 2.5
    @State private var session = UUID()
    @State private var piecesTracees: [[CGPoint]] = []
    @State private var planArchive = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Group {
                if let image, etape != .source {
                    ZonePlan(image: image, dessin: dessiner, toucher: toucher)
                        .background(Color(.secondarySystemBackground))
                        .safeAreaInset(edge: .bottom) { panneau }
                } else {
                    choixSource
                }
            }
            .navigationTitle("Plan d'architecte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(piecesTracees.isEmpty ? "Annuler" : "Terminer") { dismiss() }
                }
            }
            .fileImporter(isPresented: $importOuvert, allowedContentTypes: [.pdf, .image]) { resultat in
                if case .success(let url) = resultat { charger(url) }
            }
            .fullScreenCover(isPresented: $scannerOuvert) {
                ScannerDocuments { pages in
                    if let premiere = pages.first { utiliser(premiere) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectionPhoto) { _, element in
                guard let element else { return }
                Task {
                    if let donnees = try? await element.loadTransferable(type: Data.self),
                       let photo = UIImage(data: donnees) {
                        utiliser(photo)
                    }
                    selectionPhoto = nil
                }
            }
            .confirmationDialog("Ajouter sur ce mur", isPresented: Binding(get: { enAttente != nil },
                                                                            set: { if !$0 { enAttente = nil } }),
                                titleVisibility: .visible, presenting: enAttente) { attente in
                Button("Porte (83 cm)") { ajouterOuverture(.porte, 0.83, attente) }
                Button("Fenêtre (120 cm)") { ajouterOuverture(.fenetre, 1.2, attente) }
                Button("Ouverture sans porte (90 cm)") { ajouterOuverture(.ouverture, 0.9, attente) }
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // MARK: Étape 1 : le plan

    private var choixSource: some View {
        List {
            Section {
                Button {
                    scannerOuvert = true
                } label: {
                    Label("Photographier le plan papier", systemImage: "doc.viewfinder")
                }
                PhotosPicker(selection: $selectionPhoto, matching: .images) {
                    Label("Choisir une photo", systemImage: "photo.on.rectangle")
                }
                Button {
                    importOuvert = true
                } label: {
                    Label("Importer un PDF ou une image", systemImage: "folder")
                }
            } footer: {
                Text("Avec « Photographier », l'iPhone redresse automatiquement la feuille. Le PDF de l'architecte donne le résultat le plus précis.")
            }
            Section("Comment ça marche") {
                Label("Mets le plan à l'échelle : touche les deux extrémités d'une cote connue.", systemImage: "1.circle")
                Label("Touche les coins de la pièce, dans l'ordre, puis le premier coin pour fermer.", systemImage: "2.circle")
                Label("Touche les murs pour placer portes et fenêtres.", systemImage: "3.circle")
                Label("Nomme la pièce, puis recommence pour les autres : elles formeront le plan d'étage.", systemImage: "4.circle")
            }
            .font(.subheadline)
        }
    }

    private func charger(_ url: URL) {
        let acces = url.startAccessingSecurityScopedResource()
        defer { if acces { url.stopAccessingSecurityScopedResource() } }
        if url.pathExtension.lowercased() == "pdf", let document = PDFDocument(url: url) {
            pdf = document
            pagePDF = 0
            if let rendu = TracePlanView.rendre(document, page: 0) { utiliser(rendu, garderPDF: true) }
        } else if let donnees = try? Data(contentsOf: url), let photo = UIImage(data: donnees) {
            utiliser(photo)
        } else {
            message = "Ce fichier n'a pas pu être ouvert."
        }
    }

    private func utiliser(_ nouvelle: UIImage, garderPDF: Bool = false) {
        if !garderPDF { pdf = nil }
        image = nouvelle
        pointsEchelle = []
        metresParPixel = nil
        coins = []
        ferme = false
        ouvertures = []
        piecesTracees = []
        planArchive = false
        session = UUID()
        etape = .echelle
    }

    static func rendre(_ document: PDFDocument, page index: Int) -> UIImage? {
        guard let page = document.page(at: index) else { return nil }
        let boite = page.bounds(for: .mediaBox)
        let facteur = min(4000 / max(boite.width, boite.height), 8)
        return page.thumbnail(of: CGSize(width: boite.width * facteur, height: boite.height * facteur), for: .mediaBox)
    }

    // MARK: Touchers sur le plan

    private func toucher(_ point: CGPoint, pixelsParPoint: CGFloat) {
        switch etape {
        case .echelle:
            pointsEchelle = pointsEchelle.count >= 2 ? [point] : pointsEchelle + [point]
        case .trace:
            guard !ferme else { return }
            if coins.count >= 3, distance(point, coins[0]) < 24 * pixelsParPoint {
                ferme = true
                return
            }
            var p = point
            if orthogonal, let dernier = coins.last {
                let dx = abs(p.x - dernier.x), dy = abs(p.y - dernier.y)
                let tolerance: CGFloat = 0.18 // environ 10°
                if dy < dx * tolerance { p.y = dernier.y } else if dx < dy * tolerance { p.x = dernier.x }
            }
            coins.append(p)
        case .ouvertures:
            guard coins.count >= 3 else { return }
            var meilleur: (mur: Int, distance: CGFloat, position: Double)?
            for i in coins.indices {
                let a = coins[i], b = coins[(i + 1) % coins.count]
                let (d, t) = distanceSegment(point, a, b)
                if d < (meilleur?.distance ?? .greatestFiniteMagnitude) { meilleur = (i, d, t) }
            }
            if let meilleur, meilleur.distance < 30 * pixelsParPoint {
                enAttente = Attente(mur: meilleur.mur, position: meilleur.position)
            }
        default:
            break
        }
    }

    private func ajouterOuverture(_ genre: SegmentPlan.Genre, _ largeur: Double, _ attente: Attente) {
        ouvertures.append(OuvertureTracee(genre: genre, mur: attente.mur, position: attente.position, largeur: largeur))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private func distanceSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> (CGFloat, Double) {
        let dx = b.x - a.x, dy = b.y - a.y
        let l2 = dx * dx + dy * dy
        let t = l2 > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2)) : 0
        return (distance(p, CGPoint(x: a.x + t * dx, y: a.y + t * dy)), Double(t))
    }

    // MARK: Dessin par-dessus le plan

    private func dessiner(_ contexte: inout GraphicsContext, _ ecran: (CGPoint) -> CGPoint, _ pixelsParPoint: CGFloat) {
        let accent = Color.accentColor

        for anciens in piecesTracees where anciens.count >= 3 {
            var chemin = Path()
            chemin.addLines(anciens.map(ecran))
            chemin.closeSubpath()
            contexte.fill(chemin, with: .color(.green.opacity(0.18)))
            contexte.stroke(chemin, with: .color(.green), lineWidth: 2)
        }

        if !pointsEchelle.isEmpty {
            let points = pointsEchelle.map(ecran)
            if points.count == 2 {
                var trait = Path()
                trait.move(to: points[0])
                trait.addLine(to: points[1])
                contexte.stroke(trait, with: .color(.red), lineWidth: 3)
            }
            for p in points {
                contexte.fill(Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)), with: .color(.red))
            }
        }

        if !coins.isEmpty {
            let points = coins.map(ecran)
            var chemin = Path()
            chemin.addLines(points)
            if ferme { chemin.closeSubpath() }
            if ferme { contexte.fill(chemin, with: .color(accent.opacity(0.2))) }
            contexte.stroke(chemin, with: .color(accent), lineWidth: 3)
            for (index, p) in points.enumerated() {
                let rayon: CGFloat = index == 0 && !ferme ? 9 : 6
                contexte.fill(Path(ellipseIn: CGRect(x: p.x - rayon, y: p.y - rayon, width: 2 * rayon, height: 2 * rayon)),
                              with: .color(index == 0 && !ferme ? .orange : accent))
            }
            if ferme, let mpp = metresParPixel {
                for i in coins.indices {
                    let a = coins[i], b = coins[(i + 1) % coins.count]
                    let milieu = ecran(CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))
                    let longueur = Double(distance(a, b)) * mpp
                    let etiquette = Text("\(i + 1) · \(longueur.enMetres)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                    let resolu = contexte.resolve(etiquette)
                    let taille = resolu.measure(in: CGSize(width: 200, height: 40))
                    let fond = CGRect(x: milieu.x - taille.width / 2 - 4, y: milieu.y - taille.height / 2 - 2,
                                      width: taille.width + 8, height: taille.height + 4)
                    contexte.fill(Path(roundedRect: fond, cornerRadius: 5), with: .color(accent))
                    contexte.draw(resolu, at: milieu)
                }
            }
        }

        for ouverture in ouvertures where ouverture.mur < coins.count {
            guard let mpp = metresParPixel else { break }
            let a = coins[ouverture.mur], b = coins[(ouverture.mur + 1) % coins.count]
            let longueur = Double(distance(a, b))
            guard longueur > 0 else { continue }
            let demi = (ouverture.largeur / mpp) / 2 / longueur
            let t0 = max(0, ouverture.position - demi), t1 = min(1, ouverture.position + demi)
            var trait = Path()
            trait.move(to: ecran(CGPoint(x: a.x + (b.x - a.x) * t0, y: a.y + (b.y - a.y) * t0)))
            trait.addLine(to: ecran(CGPoint(x: a.x + (b.x - a.x) * t1, y: a.y + (b.y - a.y) * t1)))
            contexte.stroke(trait, with: .color(PlanPieceView.couleur(ouverture.genre)), lineWidth: 7)
        }
    }

    // MARK: Panneau du bas

    private var panneau: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch etape {
            case .echelle:
                Text("1. Mise à l'échelle").font(.headline)
                Text(pointsEchelle.count < 2
                     ? "Zoome, puis touche les deux extrémités d'une cote que tu connais (par exemple un mur de 4,20 m)."
                     : "Indique la longueur réelle entre les deux points rouges.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let pdf, pdf.pageCount > 1 {
                    Stepper("Page \(pagePDF + 1) sur \(pdf.pageCount)", value: $pagePDF, in: 0...(pdf.pageCount - 1))
                        .onChange(of: pagePDF) { _, page in
                            if let rendu = TracePlanView.rendre(pdf, page: page) { utiliser(rendu, garderPDF: true) }
                        }
                }
                HStack {
                    TextField("Longueur en mètres", value: $longueurEchelle, format: .number.precision(.fractionLength(0...3)))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    Button("Valider") {
                        guard pointsEchelle.count == 2, let longueur = longueurEchelle, longueur > 0 else { return }
                        let pixels = Double(distance(pointsEchelle[0], pointsEchelle[1]))
                        guard pixels > 0 else { return }
                        metresParPixel = longueur / pixels
                        etape = .trace
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pointsEchelle.count < 2 || (longueurEchelle ?? 0) <= 0)
                }

            case .trace:
                Text(piecesTracees.isEmpty ? "2. Contour de la pièce" : "Pièce suivante").font(.headline)
                Text(ferme ? "Pièce fermée. Vérifie les longueurs affichées."
                           : "Touche les coins dans l'ordre. Touche le point orange pour fermer la pièce.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Toggle("Murs droits (angles à 90°)", isOn: $orthogonal)
                    .font(.subheadline)
                HStack {
                    Button {
                        if ferme { ferme = false } else if !coins.isEmpty { coins.removeLast() }
                    } label: {
                        Label("Annuler le dernier", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(coins.isEmpty)
                    Spacer()
                    Button("Suivant") { etape = .ouvertures }
                        .buttonStyle(.borderedProminent)
                        .disabled(!ferme)
                }

            case .ouvertures:
                Text("3. Portes et fenêtres").font(.headline)
                Text("Touche un mur pour y placer une porte, une fenêtre ou une ouverture.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !ouvertures.isEmpty {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach($ouvertures) { $ouverture in
                                HStack {
                                    Text("\(libelle(ouverture.genre)) · mur \(ouverture.mur + 1)")
                                        .font(.subheadline)
                                    Spacer()
                                    Stepper("\(Int((ouverture.largeur * 100).rounded())) cm",
                                            value: $ouverture.largeur, in: 0.4...4, step: 0.05)
                                        .font(.subheadline)
                                        .fixedSize()
                                    Button(role: .destructive) {
                                        ouvertures.removeAll { $0.id == ouverture.id }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 130)
                }
                HStack {
                    Button("Retour") { etape = .trace }
                    Spacer()
                    Button("Suivant") { etape = .nom }
                        .buttonStyle(.borderedProminent)
                }

            case .nom:
                Text("4. Enregistrer la pièce").font(.headline)
                TextField("Nom de la pièce (ex. Cuisine)", text: $nom)
                    .textFieldStyle(.roundedBorder)
                Stepper("Hauteur sous plafond : \(hauteur.enMetres)", value: $hauteur, in: 1.8...6, step: 0.05)
                    .font(.subheadline)
                if let mpp = metresParPixel {
                    Text("Surface : \(aire(mpp).enMetresCarres) · Périmètre : \(perimetre(mpp).enMetres)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Retour") { etape = .ouvertures }
                    Spacer()
                    Button("Enregistrer") { enregistrer() }
                        .buttonStyle(.borderedProminent)
                }

            case .source:
                EmptyView()
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    private func libelle(_ genre: SegmentPlan.Genre) -> String {
        switch genre {
        case .porte: return "Porte"
        case .fenetre: return "Fenêtre"
        case .ouverture: return "Ouverture"
        case .mur: return "Mur"
        }
    }

    // MARK: Enregistrement

    private func metres(_ mpp: Double) -> [(x: Double, y: Double)] {
        coins.map { (x: Double($0.x) * mpp, y: Double($0.y) * mpp) }
    }

    private func aire(_ mpp: Double) -> Double {
        let p = metres(mpp)
        guard p.count >= 3 else { return 0 }
        var somme = 0.0
        for i in p.indices {
            let a = p[i], b = p[(i + 1) % p.count]
            somme += a.x * b.y - b.x * a.y
        }
        return abs(somme) / 2
    }

    private func perimetre(_ mpp: Double) -> Double {
        let p = metres(mpp)
        guard p.count >= 2 else { return 0 }
        return p.indices.reduce(0) { total, i in
            let a = p[i], b = p[(i + 1) % p.count]
            return total + hypot(b.x - a.x, b.y - a.y)
        }
    }

    private func enregistrer() {
        guard let mpp = metresParPixel, coins.count >= 3 else { return }
        let p = metres(mpp)
        var segments: [SegmentPlan] = p.indices.map { i in
            let a = p[i], b = p[(i + 1) % p.count]
            return SegmentPlan(genre: .mur, x1: a.x, y1: a.y, x2: b.x, y2: b.y, hauteur: hauteur)
        }
        for ouverture in ouvertures where ouverture.mur < p.count {
            let a = p[ouverture.mur], b = p[(ouverture.mur + 1) % p.count]
            let longueur = hypot(b.x - a.x, b.y - a.y)
            guard longueur > 0 else { continue }
            let demi = min(ouverture.largeur, longueur) / 2 / longueur
            let t0 = max(0, ouverture.position - demi), t1 = min(1, ouverture.position + demi)
            segments.append(SegmentPlan(genre: ouverture.genre,
                                        x1: a.x + (b.x - a.x) * t0, y1: a.y + (b.y - a.y) * t0,
                                        x2: a.x + (b.x - a.x) * t1, y2: a.y + (b.y - a.y) * t1,
                                        hauteur: ouverture.genre == .fenetre ? 1.25 : 2.04))
        }
        let nomPiece = nom.trimmingCharacters(in: .whitespaces)
        let piece = Piece(nom: nomPiece.isEmpty ? "Pièce \(chantier.pieces.count + 1)" : nomPiece,
                          surfaceSol: aire(mpp),
                          perimetre: perimetre(mpp),
                          hauteur: hauteur,
                          segments: segments,
                          fichierScan: nil)
        piece.sessionScan = session
        contexte.insert(piece)
        chantier.pieces.append(piece)

        if !planArchive, let image, let donnees = image.jpegData(compressionQuality: 0.85) {
            let url = URL.temporaryDirectory.appending(path: "Plan d'architecte.jpg")
            if (try? donnees.write(to: url)) != nil {
                _ = chantier.archiver(url, nom: "Plan d'architecte", genre: .importe, contexte: contexte)
                planArchive = true
            }
        }

        piecesTracees.append(coins)
        message = "\(piece.nom) enregistrée (\(piece.surfaceSol.enMetresCarres)). Tu peux tracer la pièce suivante, ou toucher Terminer."
        coins = []
        ferme = false
        ouvertures = []
        nom = ""
        etape = .trace
    }
}

// MARK: - Plan zoomable

/// Affiche une image qu'on peut agrandir (pincer) et déplacer (glisser), avec un dessin par-dessus.
struct ZonePlan: View {
    let image: UIImage
    /// Dessin : contexte, conversion point de l'image → écran, pixels d'image par point d'écran.
    var dessin: (inout GraphicsContext, (CGPoint) -> CGPoint, CGFloat) -> Void
    /// Toucher : point dans l'image, pixels d'image par point d'écran.
    var toucher: (CGPoint, CGFloat) -> Void

    @State private var zoom: CGFloat = 1
    @State private var zoomDebut: CGFloat = 1
    @State private var decalage: CGSize = .zero
    @State private var decalageDebut: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let taille = geo.size
            let ajuste = min(taille.width / max(image.size.width, 1), taille.height / max(image.size.height, 1))
            let largeur = image.size.width * ajuste
            let hauteur = image.size.height * ajuste
            let echelle = ajuste * zoom
            let versEcran: (CGPoint) -> CGPoint = { p in
                CGPoint(x: taille.width / 2 + decalage.width + (p.x * ajuste - largeur / 2) * zoom,
                        y: taille.height / 2 + decalage.height + (p.y * ajuste - hauteur / 2) * zoom)
            }
            let versImage: (CGPoint) -> CGPoint = { s in
                CGPoint(x: ((s.x - taille.width / 2 - decalage.width) / zoom + largeur / 2) / ajuste,
                        y: ((s.y - taille.height / 2 - decalage.height) / zoom + hauteur / 2) / ajuste)
            }
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: largeur, height: hauteur)
                    .scaleEffect(zoom)
                    .offset(decalage)
                Canvas { contexte, _ in
                    dessin(&contexte, versEcran, 1 / echelle)
                }
                .allowsHitTesting(false)
            }
            .frame(width: taille.width, height: taille.height)
            .contentShape(Rectangle())
            .clipped()
            .gesture(SpatialTapGesture().onEnded { valeur in
                toucher(versImage(valeur.location), 1 / echelle)
            })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { valeur in zoom = max(1, min(15, zoomDebut * valeur.magnification)) }
                .onEnded { _ in zoomDebut = zoom })
            .simultaneousGesture(DragGesture(minimumDistance: 12)
                .onChanged { valeur in
                    decalage = CGSize(width: decalageDebut.width + valeur.translation.width,
                                      height: decalageDebut.height + valeur.translation.height)
                }
                .onEnded { _ in decalageDebut = decalage })
        }
    }
}
