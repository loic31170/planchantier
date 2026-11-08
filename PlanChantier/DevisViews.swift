import SwiftUI
import SwiftData

// MARK: - Devis d'un chantier

struct DevisView: View {
    @Environment(\.modelContext) private var contexte
    @Bindable var chantier: Chantier
    @AppStorage(Reglages.franchiseTVA) private var franchiseTVA = false

    @State private var ajoutOuvert = false
    @State private var ligneEditee: LigneDevis?
    @State private var documentPDF: DocumentPDF?
    @State private var cible: CibleTravaux?

    struct CibleTravaux: Identifiable {
        let id = UUID()
        let piece: Piece?
    }

    private var lignes: [LigneDevis] {
        chantier.lignesDevis.sorted { $0.ordre < $1.ordre }
    }

    private var totaux: TotauxDevis {
        TotauxDevis(lignes: chantier.lignesDevis, franchise: franchiseTVA)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Numéro", value: chantier.numeroDevis.isEmpty ? "attribué au premier ajout" : chantier.numeroDevis)
                if let date = chantier.dateDevis {
                    LabeledContent("Date", value: date.formatted(date: .long, time: .omitted))
                }
            }

            ForEach(chantier.sectionsDevis, id: \.self) { section in
                let piece = chantier.piece(nommee: section)
                let liste = lignes.filter { $0.section == section }
                if !section.isEmpty {
                    Section {
                        lignesListe(liste)
                        Button {
                            cible = CibleTravaux(piece: piece)
                        } label: {
                            Label("Ajouter des travaux dans \(section)", systemImage: "plus.circle")
                        }
                        .disabled(piece == nil)
                    } header: {
                        enTeteSection(section, liste: liste)
                    }
                }
            }

            Section {
                lignesListe(lignes.filter { $0.section.isEmpty })
                Button {
                    cible = CibleTravaux(piece: nil)
                } label: {
                    Label("Ajouter des travaux généraux", systemImage: "plus.circle")
                }
                Button {
                    ajoutOuvert = true
                } label: {
                    Label("Une prestation sur plusieurs pièces", systemImage: "square.stack.3d.up")
                }
                Button {
                    ajouterLigneLibre()
                } label: {
                    Label("Ajouter une ligne libre", systemImage: "square.and.pencil")
                }
            } header: {
                enTeteSection("Travaux généraux", liste: lignes.filter { $0.section.isEmpty })
            } footer: {
                Text("Les travaux propres à chaque pièce (saignée, prise, radiateur…) s'ajoutent dans la section de la pièce.")
            }

            Section("Total") {
                LabeledContent("Total HT", value: totaux.ht.enEuros)
                if franchiseTVA {
                    Text("TVA non applicable, art. 293 B du CGI")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(totaux.tva, id: \.taux) { ligne in
                        LabeledContent("TVA \(ligne.taux.enPourcentage)", value: ligne.montant.enEuros)
                    }
                    LabeledContent("Total TTC") {
                        Text(totaux.ttc.enEuros).fontWeight(.bold)
                    }
                }
            }
        }
        .navigationTitle("Devis")
        .toolbar {
            ToolbarItem {
                EditButton()
            }
            ToolbarItem {
                Button {
                    if let url = ExportDevisPDF.generer(chantier) {
                        let numero = chantier.numeroDevis.isEmpty ? "" : " \(chantier.numeroDevis)"
                        _ = chantier.archiver(url, nom: "Devis\(numero)", genre: .devis, contexte: contexte)
                        documentPDF = DocumentPDF(url: url)
                    }
                } label: {
                    Label("Exporter le devis", systemImage: "square.and.arrow.up")
                }
                .disabled(chantier.lignesDevis.isEmpty)
            }
        }
        .sheet(isPresented: $ajoutOuvert) {
            AjoutPrestationView(chantier: chantier)
        }
        .sheet(item: $cible) { cible in
            AjoutTravauxView(chantier: chantier, piece: cible.piece)
        }
        .sheet(item: $ligneEditee) { ligne in
            LigneDevisFormView(ligne: ligne)
        }
        .sheet(item: $documentPDF) { document in
            FeuillePartage(elements: [document.url])
                .presentationDetents([.medium, .large])
        }
    }

    private func enTeteSection(_ titre: String, liste: [LigneDevis]) -> some View {
        HStack {
            Text(titre)
            Spacer()
            if !liste.isEmpty {
                Text(liste.reduce(0) { $0 + $1.totalHT }.enEuros + " HT")
            }
        }
    }

    @ViewBuilder
    private func lignesListe(_ liste: [LigneDevis]) -> some View {
        ForEach(liste) { ligne in
            Button {
                ligneEditee = ligne
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ligne.designation)
                        .foregroundStyle(.primary)
                    HStack {
                        Text("\(ligne.quantite.enQuantite) \(ligne.unite.rawValue) × \(ligne.prixHT.enEuros)")
                        Spacer()
                        Text(ligne.totalHT.enEuros).fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .onDelete { positions in
            for i in positions { contexte.delete(liste[i]) }
        }
        .onMove { depart, arrivee in
            // On réordonne dans la section en réutilisant ses numéros d'ordre.
            let ordres = liste.map(\.ordre).sorted()
            var nouvelle = liste
            nouvelle.move(fromOffsets: depart, toOffset: arrivee)
            for (ligne, ordre) in zip(nouvelle, ordres) { ligne.ordre = ordre }
        }
    }

    private func ajouterLigneLibre() {
        let ligne = LigneDevis(designation: "Nouvelle prestation", unite: .forfait, quantite: 1,
                               prixHT: 0, tauxTVA: franchiseTVA ? 0 : 10, ordre: chantier.lignesDevis.count)
        DevisView.ajouter(ligne, a: chantier, contexte: contexte)
        ligneEditee = ligne
    }

    static func ajouter(_ ligne: LigneDevis, a chantier: Chantier, contexte: ModelContext) {
        contexte.insert(ligne)
        chantier.lignesDevis.append(ligne)
        if chantier.numeroDevis.isEmpty {
            chantier.numeroDevis = Catalogue.numeroSuivant()
            chantier.dateDevis = .now
        }
    }
}

// MARK: - Ajout d'une prestation du catalogue

struct AjoutPrestationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexte
    @AppStorage(Reglages.franchiseTVA) private var franchiseTVA = false

    let chantier: Chantier

    @Query(sort: \Prestation.nom) private var prestations: [Prestation]
    @State private var choisie: Prestation?
    @State private var piecesChoisies: Set<PersistentIdentifier> = []
    @State private var quantite: Double = 0
    @State private var prix: Double = 0

    private var pieces: [Piece] {
        chantier.pieces.sorted { $0.dateScan < $1.dateScan }
    }

    var body: some View {
        NavigationStack {
            Form {
                if prestations.isEmpty {
                    Text("Ton catalogue est vide. Ajoute des prestations dans Réglages > Catalogue.")
                        .foregroundStyle(.secondary)
                }

                Section("Prestation") {
                    Picker("Prestation", selection: $choisie) {
                        Text("Choisir…").tag(Prestation?.none)
                        ForEach(prestations) { prestation in
                            Text(prestation.nom).tag(Optional(prestation))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                if let prestation = choisie {
                    if prestation.base != .manuelle {
                        Section {
                            ForEach(pieces) { piece in
                                Toggle(isOn: selectionPiece(piece)) {
                                    HStack {
                                        Text(piece.nom)
                                        Spacer()
                                        Text("\(prestation.base.quantite(pour: piece).enQuantite) \(prestation.unite.rawValue)")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Text("Pièces concernées")
                        } footer: {
                            Text("Calcul : \(prestation.base.libelle.lowercased()).")
                        }
                    }

                    Section("Quantité et prix") {
                        LabeledContent("Quantité (\(prestation.unite.rawValue))") {
                            TextField("0", value: $quantite, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Prix unitaire HT") {
                            TextField("0", value: $prix, format: .currency(code: "EUR"))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Total HT", value: (quantite * prix).enEuros)
                    }
                }
            }
            .navigationTitle("Ajouter au devis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { ajouter() }
                        .disabled(choisie == nil)
                }
            }
            .onChange(of: choisie) { _, prestation in
                guard let prestation else { return }
                prix = prestation.prixHT
                piecesChoisies = Set(pieces.map { $0.persistentModelID })
                recalculer()
            }
            .onChange(of: piecesChoisies) { _, _ in
                recalculer()
            }
        }
    }

    private func selectionPiece(_ piece: Piece) -> Binding<Bool> {
        Binding(
            get: { piecesChoisies.contains(piece.persistentModelID) },
            set: { coche in
                if coche {
                    piecesChoisies.insert(piece.persistentModelID)
                } else {
                    piecesChoisies.remove(piece.persistentModelID)
                }
            }
        )
    }

    private var piecesRetenues: [Piece] {
        pieces.filter { piecesChoisies.contains($0.persistentModelID) }
    }

    private func recalculer() {
        guard let prestation = choisie else { return }
        if prestation.base == .manuelle {
            if quantite == 0 { quantite = 1 }
            return
        }
        let total = piecesRetenues.reduce(0) { $0 + prestation.base.quantite(pour: $1) }
        quantite = (total * 100).rounded() / 100
    }

    private func ajouter() {
        guard let prestation = choisie else { return }
        var designation = prestation.nom
        let noms = piecesRetenues.map { $0.nom }
        if prestation.base != .manuelle, !noms.isEmpty {
            designation += " – " + noms.joined(separator: ", ")
        }
        let ligne = LigneDevis(designation: designation,
                               unite: prestation.unite,
                               quantite: quantite,
                               prixHT: prix,
                               tauxTVA: franchiseTVA ? 0 : prestation.tauxTVA,
                               ordre: chantier.lignesDevis.count)
        DevisView.ajouter(ligne, a: chantier, contexte: contexte)
        dismiss()
    }
}

// MARK: - Modification d'une ligne

struct LigneDevisFormView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Reglages.franchiseTVA) private var franchiseTVA = false
    @Bindable var ligne: LigneDevis

    var body: some View {
        NavigationStack {
            Form {
                Section("Désignation") {
                    TextField("Désignation", text: $ligne.designation, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Quantité et prix") {
                    LabeledContent("Quantité") {
                        TextField("0", value: $ligne.quantite, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Unité", selection: $ligne.uniteRaw) {
                        ForEach(UniteDevis.allCases, id: \.self) { unite in
                            Text(unite.rawValue).tag(unite.rawValue)
                        }
                    }
                    LabeledContent("Prix unitaire HT") {
                        TextField("0", value: $ligne.prixHT, format: .currency(code: "EUR"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if !franchiseTVA {
                        Picker("TVA", selection: $ligne.tauxTVA) {
                            ForEach(TauxTVA.valeurs, id: \.self) { taux in
                                Text(taux.enPourcentage).tag(taux)
                            }
                        }
                    }
                    LabeledContent("Total HT", value: ligne.totalHT.enEuros)
                }
            }
            .navigationTitle("Ligne du devis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}
