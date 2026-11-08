import SwiftUI
import SwiftData
import MapKit
import PhotosUI
import RoomPlan

/// Une photo du chantier, générale ou rattachée à une pièce.
struct PhotoChantier: Hashable, Identifiable {
    var nom: String
    var libelle: String
    var id: String { nom }
}

extension Chantier {
    var toutesLesPhotos: [PhotoChantier] {
        photos.map { PhotoChantier(nom: $0, libelle: "Général") } +
        pieces.sorted { $0.dateScan < $1.dateScan }
            .flatMap { piece in piece.photos.map { PhotoChantier(nom: $0, libelle: piece.nom) } }
    }

    var surfaceMursTotale: Double { pieces.reduce(0) { $0 + $1.surfaceMursNette } }

    /// Pièces qui ne font partie d'aucun plan d'étage.
    var piecesSeules: [Piece] {
        let dansEtages = Set(etages.flatMap { $0 }.map { $0.persistentModelID })
        return pieces
            .filter { !dansEtages.contains($0.persistentModelID) }
            .sorted { $0.dateScan < $1.dateScan }
    }
}

// MARK: - Fiche d'un chantier

struct ChantierView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var ouvrirURL
    @Bindable var chantier: Chantier

    @State private var scanOuvert = false
    @State private var lidarAbsent = false
    @State private var editionOuverte = false
    @State private var localisationOuverte = false
    @State private var documentPDF: DocumentPDF?
    @State private var photoAffichee: PhotoChantier?
    @State private var appareilOuvert = false
    @State private var selectionPhotos: [PhotosPickerItem] = []
    @State private var confirmerArchivage = false
    @State private var confirmerSuppression = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                description
                carteAdresse
                statistiques
                sectionPlans
                sectionPhotos
                sectionDevis
                informations
                actions
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(chantier.nom)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editionOuverte = true
                } label: {
                    Label("Modifier", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        exporterReleve()
                    } label: {
                        Label("Relevé (plans, mesures, photos)", systemImage: "doc.richtext")
                    }
                    .disabled(chantier.pieces.isEmpty)
                    Button {
                        exporterDevis()
                    } label: {
                        Label("Devis", systemImage: "eurosign.circle")
                    }
                    .disabled(chantier.lignesDevis.isEmpty)
                } label: {
                    Label("Exporter", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $editionOuverte) {
            EditionChantierView(chantier: chantier)
        }
        .sheet(isPresented: $localisationOuverte) {
            LocalisationChantierView(chantier: chantier)
        }
        .sheet(item: $documentPDF) { document in
            FeuillePartage(elements: [document.url])
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $photoAffichee) { photo in
            VisionneusePhoto(photo: photo)
        }
        .fullScreenCover(isPresented: $scanOuvert) {
            ScanView(chantier: chantier)
        }
        .fullScreenCover(isPresented: $appareilOuvert) {
            AppareilPhoto { image in ajouterPhoto(image) }
                .ignoresSafeArea()
        }
        .onChange(of: selectionPhotos) { _, elements in
            guard !elements.isEmpty else { return }
            Task {
                for element in elements {
                    if let donnees = try? await element.loadTransferable(type: Data.self),
                       let image = UIImage(data: donnees) {
                        ajouterPhoto(image)
                    }
                }
                selectionPhotos = []
            }
        }
        .alert("Scan impossible", isPresented: $lidarAbsent) {
            Button("OK") {}
        } message: {
            Text("Cet appareil n'a pas de capteur LiDAR. Le scan fonctionne sur les iPhone Pro (12 Pro et plus récents) et les iPad Pro.")
        }
        .confirmationDialog(chantier.archive ? "Désarchiver ce chantier ?" : "Archiver ce chantier ?",
                            isPresented: $confirmerArchivage, titleVisibility: .visible) {
            Button(chantier.archive ? "Désarchiver" : "Archiver") {
                chantier.archive.toggle()
                if chantier.archive { dismiss() }
            }
        } message: {
            Text(chantier.archive
                 ? "Il reviendra dans la liste des chantiers en cours."
                 : "Il restera disponible dans le filtre « Archivés » de l'accueil.")
        }
        .confirmationDialog("Supprimer ce chantier ?", isPresented: $confirmerSuppression, titleVisibility: .visible) {
            Button("Supprimer définitivement", role: .destructive) {
                chantier.supprimerFichiers()
                contexte.delete(chantier)
                dismiss()
            }
        } message: {
            Text("Les pièces, photos et le devis de ce chantier seront supprimés.")
        }
        .task(id: chantier.adresse) {
            if chantier.coordonnees == nil { await localiserAdresse() }
        }
    }

    // MARK: Description et adresse

    private var description: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "text.alignleft")
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            TextField("Ajouter une description du chantier…", text: $chantier.descriptionChantier, axis: .vertical)
                .lineLimit(1...5)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var carteAdresse: some View {
        VStack(spacing: 0) {
            Button {
                localisationOuverte = true
            } label: {
                HStack(spacing: 14) {
                    apercuCarte
                        .frame(width: 76, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(chantier.client.isEmpty ? "Client non renseigné" : chantier.client)
                            .font(.headline)
                            .foregroundStyle(chantier.client.isEmpty ? .secondary : .primary)
                        Text(chantier.adresse.isEmpty ? "Ajouter une adresse" : chantier.adresse)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !chantier.infosPratiques.isEmpty {
                Divider().padding(.leading, 12)
                Label(chantier.infosPratiques, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }

            if !chantier.adresse.isEmpty {
                Divider().padding(.leading, 12)
                Button {
                    chantier.ouvrirDansPlans(itineraire: true)
                } label: {
                    Label("Itinéraire avec Plans", systemImage: "car.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var apercuCarte: some View {
        if let lat = chantier.latitude, let lon = chantier.longitude {
            let point = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            Map(initialPosition: .region(MKCoordinateRegion(center: point,
                                                            latitudinalMeters: 400,
                                                            longitudinalMeters: 400))) {
                Marker("", coordinate: point)
                    .tint(Color.accentColor)
            }
            .allowsHitTesting(false)
            .id("\(lat),\(lon)")
        } else {
            ZStack {
                Color.accentColor.opacity(0.1)
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: Statistiques

    private var statistiques: some View {
        VStack(alignment: .leading, spacing: 10) {
            enTeteSection("Statistiques", sousTitre: nil, compteur: nil) { EmptyView() }
            HStack(spacing: 0) {
                tuile(chantier.surfaceTotale.enMetresCarres, "Surface au sol")
                Divider().frame(height: 34)
                tuile(chantier.surfaceMursTotale.enMetresCarres, "Surface murale")
                Divider().frame(height: 34)
                tuile("\(chantier.etages.count)", "Étages")
                Divider().frame(height: 34)
                tuile("\(chantier.pieces.count)", "Pièces")
            }
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func tuile(_ valeur: String, _ titre: String) -> some View {
        VStack(spacing: 3) {
            Text(valeur)
                .font(.headline)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(titre)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: Plans

    private var sectionPlans: some View {
        let nombre = chantier.etages.count + chantier.piecesSeules.count
        return VStack(alignment: .leading, spacing: 10) {
            enTeteSection("Plans", sousTitre: "Plans d'étage, puis pièces seules", compteur: nombre) {
                ToutesLesPiecesView(chantier: chantier)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    boutonAjout("Scanner") { lancerScan() }
                    ForEach(Array(chantier.etages.enumerated()), id: \.offset) { index, pieces in
                        NavigationLink {
                            EcranPlanEtage(titre: "Plan d'étage \(index + 1)", pieces: pieces)
                        } label: {
                            CartePlan(titre: "Plan d'étage \(index + 1)",
                                      detail: "\(pieces.count) pièces · \(pieces.reduce(0) { $0 + $1.surfaceSol }.enMetresCarres)") {
                                PlanEtageView(pieces: pieces, afficherNoms: false, epaisseur: 2.5, marge: 10)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(chantier.piecesSeules) { piece in
                        NavigationLink {
                            PieceView(piece: piece)
                        } label: {
                            CartePlan(titre: piece.nom, detail: piece.surfaceSol.enMetresCarres) {
                                PlanEtageView(pieces: [piece], afficherNoms: false, epaisseur: 2.5, marge: 10)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Photos

    private var sectionPhotos: some View {
        let photos = chantier.toutesLesPhotos
        return VStack(alignment: .leading, spacing: 10) {
            enTeteSection("Photos", sousTitre: "Photos générales, puis par pièce", compteur: photos.count) {
                ToutesLesPhotosView(chantier: chantier)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    Menu {
                        Button {
                            appareilOuvert = true
                        } label: {
                            Label("Prendre une photo", systemImage: "camera")
                        }
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                        PhotosPicker(selection: $selectionPhotos, maxSelectionCount: 20, matching: .images) {
                            Label("Choisir dans la photothèque", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        CercleAjout(titre: "Photo")
                    }
                    ForEach(photos) { photo in
                        Button {
                            photoAffichee = photo
                        } label: {
                            CartePhoto(photo: photo)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Devis

    private var sectionDevis: some View {
        VStack(alignment: .leading, spacing: 10) {
            enTeteSection("Devis", sousTitre: nil, compteur: nil) { EmptyView() }
            NavigationLink {
                DevisView(chantier: chantier)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "eurosign")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    if chantier.lignesDevis.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Créer un devis").font(.headline)
                            Text("Quantités calculées depuis les plans")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        let totaux = TotauxDevis(lignes: chantier.lignesDevis, franchise: Entreprise.actuelle.franchiseTVA)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Devis \(chantier.numeroDevis)").font(.headline)
                            Text("\(chantier.lignesDevis.count) ligne\(chantier.lignesDevis.count > 1 ? "s" : "")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(totaux.ttc.enEuros)
                            .font(.headline)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Informations et actions

    private var informations: some View {
        VStack(alignment: .leading, spacing: 0) {
            ligneInfo("Créé le", chantier.dateCreation.formatted(date: .long, time: .shortened))
            Divider().padding(.leading, 14)
            ligneInfo("Dernier scan",
                      chantier.pieces.map { $0.dateScan }.max()?.formatted(date: .long, time: .shortened) ?? "aucun")
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func ligneInfo(_ titre: String, _ valeur: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titre).font(.caption).foregroundStyle(.secondary)
            Text(valeur).font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                boutonAction("Exporter le relevé…", "Plans, mesures et photos en PDF", "doc.richtext") {
                    exporterReleve()
                }
                .disabled(chantier.pieces.isEmpty)
                Divider().padding(.leading, 48)
                boutonAction(chantier.favori ? "Retirer des favoris" : "Mettre en favori", nil,
                             chantier.favori ? "star.slash" : "star") {
                    chantier.favori.toggle()
                }
                Divider().padding(.leading, 48)
                boutonAction("Dupliquer", "Copie avec les pièces, photos et devis", "plus.square.on.square") {
                    chantier.dupliquer(dans: contexte)
                    dismiss()
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

            VStack(spacing: 0) {
                boutonAction(chantier.archive ? "Désarchiver…" : "Archiver…", nil, "archivebox", couleur: .orange) {
                    confirmerArchivage = true
                }
                Divider().padding(.leading, 48)
                boutonAction("Supprimer…", nil, "trash", couleur: .red) {
                    confirmerSuppression = true
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func boutonAction(_ titre: String, _ detail: String?, _ icone: String,
                              couleur: Color = .accentColor, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icone)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titre)
                    if let detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .foregroundStyle(couleur)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Éléments communs

    private func enTeteSection<Destination: View>(_ titre: String, sousTitre: String?, compteur: Int?,
                                                  @ViewBuilder destination: @escaping () -> Destination) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titre).font(.title3.weight(.bold))
                if let sousTitre {
                    Text(sousTitre).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let compteur, compteur > 0 {
                NavigationLink {
                    destination()
                } label: {
                    Text("Voir tout (\(compteur))")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private func boutonAjout(_ titre: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CercleAjout(titre: titre)
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func lancerScan() {
        if RoomCaptureSession.isSupported {
            scanOuvert = true
        } else {
            lidarAbsent = true
        }
    }

    private func ajouterPhoto(_ image: UIImage) {
        if let nom = StockagePhotos.enregistrer(image) {
            chantier.photos.append(nom)
        }
    }

    private func exporterReleve() {
        if let url = ExportPDF.generer(chantier) {
            documentPDF = DocumentPDF(url: url)
        }
    }

    private func exporterDevis() {
        if let url = ExportDevisPDF.generer(chantier) {
            documentPDF = DocumentPDF(url: url)
        }
    }

    private func localiserAdresse() async {
        let adresse = chantier.adresse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !adresse.isEmpty else {
            chantier.latitude = nil
            chantier.longitude = nil
            return
        }
        if let lieu = try? await CLGeocoder().geocodeAddressString(adresse).first?.location {
            chantier.latitude = lieu.coordinate.latitude
            chantier.longitude = lieu.coordinate.longitude
        }
    }
}

// MARK: - Composants

struct CercleAjout: View {
    let titre: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 52, height: 52)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            Text(titre)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 70, height: 150)
    }
}

struct CartePlan<Contenu: View>: View {
    let titre: String
    let detail: String
    @ViewBuilder let contenu: () -> Contenu

    var body: some View {
        VStack(spacing: 4) {
            contenu()
                .frame(width: 140, height: 140)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
                .padding(.bottom, 4)
            Text(titre)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 140)
    }
}

struct CartePhoto: View {
    let photo: PhotoChantier
    var taille: CGFloat = 140

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let image = StockagePhotos.image(photo.nom) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray.opacity(0.15)
                }
            }
            .frame(width: taille, height: taille)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.bottom, 4)
            Text(photo.libelle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .frame(width: taille)
    }
}

struct VisionneusePhoto: View {
    let photo: PhotoChantier

    var body: some View {
        NavigationStack {
            Group {
                if let image = StockagePhotos.image(photo.nom) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ContentUnavailableView("Photo introuvable", systemImage: "photo")
                }
            }
            .padding()
            .navigationTitle(photo.libelle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let image = StockagePhotos.image(photo.nom) {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(photo.libelle, image: Image(uiImage: image)))
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Édition des informations

struct EditionChantierView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var chantier: Chantier

    var body: some View {
        NavigationStack {
            Form {
                Section("Chantier") {
                    TextField("Nom du chantier", text: $chantier.nom)
                    TextField("Description", text: $chantier.descriptionChantier, axis: .vertical)
                }
                Section("Client") {
                    TextField("Nom du client", text: $chantier.client)
                    NavigationLink {
                        EditionAdresseView(chantier: chantier)
                    } label: {
                        LabeledContent("Adresse") {
                            Text(chantier.adresse.isEmpty ? "Ajouter" : chantier.adresse.replacingOccurrences(of: "\n", with: ", "))
                                .lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle("Informations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Pages « Voir tout »

struct ToutesLesPiecesView: View {
    let chantier: Chantier
    private let colonnes = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(Array(chantier.etages.enumerated()), id: \.offset) { index, pieces in
                    VStack(alignment: .leading, spacing: 10) {
                        NavigationLink {
                            EcranPlanEtage(titre: "Plan d'étage \(index + 1)", pieces: pieces)
                        } label: {
                            HStack {
                                Text("Plan d'étage \(index + 1)").font(.title3.weight(.bold))
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                            }
                        }
                        .buttonStyle(.plain)
                        grille(pieces)
                    }
                }
                if !chantier.piecesSeules.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(chantier.etages.isEmpty ? "Pièces" : "Pièces seules").font(.title3.weight(.bold))
                        grille(chantier.piecesSeules)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Plans")
    }

    private func grille(_ pieces: [Piece]) -> some View {
        LazyVGrid(columns: colonnes, spacing: 18) {
            ForEach(pieces) { piece in
                NavigationLink {
                    PieceView(piece: piece)
                } label: {
                    VStack(spacing: 4) {
                        PlanEtageView(pieces: [piece], afficherNoms: false, epaisseur: 2.5, marge: 10)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                            .padding(.bottom, 4)
                        Text(piece.nom).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(piece.surfaceSol.enMetresCarres).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ToutesLesPhotosView: View {
    let chantier: Chantier
    @State private var photoAffichee: PhotoChantier?
    private let colonnes = [GridItem(.adaptive(minimum: 105), spacing: 4)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: colonnes, spacing: 4) {
                ForEach(chantier.toutesLesPhotos) { photo in
                    Button {
                        photoAffichee = photo
                    } label: {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if let image = StockagePhotos.image(photo.nom) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                            .clipped()
                            .overlay(alignment: .bottomLeading) {
                                Text(photo.libelle)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.black.opacity(0.45), in: Capsule())
                                    .padding(5)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Photos")
        .sheet(item: $photoAffichee) { photo in
            VisionneusePhoto(photo: photo)
        }
    }
}
