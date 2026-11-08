import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Données

/// Un produit d'un tarif fournisseur (Cedeo…), avec ton prix d'achat et le prix de revente.
@Model
final class Produit {
    var code: String
    var libelle: String
    var marque: String
    var prixAchat: Double
    var prixPublic: Double
    var ecoContribution: Double
    var unite: String
    var famille: String
    var sousFamille: String
    var categorie: String
    var image: String
    var fournisseur: String

    init(code: String, libelle: String, marque: String, prixAchat: Double, prixPublic: Double,
         ecoContribution: Double, unite: String, famille: String, sousFamille: String,
         categorie: String, image: String, fournisseur: String) {
        self.code = code
        self.libelle = libelle
        self.marque = marque
        self.prixAchat = prixAchat
        self.prixPublic = prixPublic
        self.ecoContribution = ecoContribution
        self.unite = unite
        self.famille = famille
        self.sousFamille = sousFamille
        self.categorie = categorie
        self.image = image
        self.fournisseur = fournisseur
    }

    /// Coût réel : prix net + éco-contribution.
    var coutAchat: Double { prixAchat + ecoContribution }

    /// Prix de revente HT selon le réglage : prix public, ou achat × coefficient.
    func prixVente(coefficient: Double) -> Double {
        let base = coefficient > 0 ? prixAchat * coefficient : max(prixPublic, prixAchat)
        return ((base + ecoContribution) * 100).rounded() / 100
    }

    var uniteDevis: UniteDevis {
        let u = unite.lowercased()
        if u.contains("mètre carré") || u.contains("m²") || u == "m2" { return .m2 }
        if u.contains("mètre") || u == "m" || u == "ml" { return .ml }
        if u.contains("heure") { return .heure }
        return .unite
    }
}

enum ReglagesProduits {
    /// 0 = prix public du fournisseur ; sinon prix d'achat × coefficient.
    static let coefficient = "produits.coefficient"
}

// MARK: - Import d'un fichier CSV

enum ImportProduits {
    enum Erreur: LocalizedError {
        case illisible, colonnes(String)
        var errorDescription: String? {
            switch self {
            case .illisible: return "Le fichier n'a pas pu être lu. Exporte-le en CSV (Numbers ou Excel : Exporter > CSV)."
            case .colonnes(let detail): return "Colonnes introuvables : \(detail)."
            }
        }
    }

    /// Lit un CSV (séparateur ; , ou tabulation) et remplace les produits du même fournisseur.
    /// Reconnaît les en-têtes des exports Cedeo et des en-têtes simples (« libellé », « prix achat », « prix vente »…).
    @MainActor
    static func importer(_ url: URL, contexte: ModelContext) throws -> Int {
        let acces = url.startAccessingSecurityScopedResource()
        defer { if acces { url.stopAccessingSecurityScopedResource() } }
        guard let donnees = try? Data(contentsOf: url) else { throw Erreur.illisible }
        let texte = String(data: donnees, encoding: .utf8)
            ?? String(data: donnees, encoding: .windowsCP1252)
            ?? String(data: donnees, encoding: .isoLatin1)
        guard let texte, let premiereLigne = texte.split(whereSeparator: \.isNewline).first else { throw Erreur.illisible }

        let separateur: Character = [";", "\t", ","].max { a, b in
            premiereLigne.filter { $0 == a }.count < premiereLigne.filter { $0 == b }.count
        } ?? ";"
        var lignes = lireCSV(texte, separateur: separateur)
        guard !lignes.isEmpty else { throw Erreur.illisible }
        let entetes = lignes.removeFirst().map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        func colonne(_ cles: [String], sauf: [String] = []) -> Int? {
            for cle in cles {
                if let i = entetes.firstIndex(where: { e in e.contains(cle) && !sauf.contains(where: { e.contains($0) }) }) {
                    return i
                }
            }
            return nil
        }

        let iLibelle = colonne(["libellé de l'article", "libellé", "libelle", "désignation", "designation"],
                               sauf: ["unité", "conditionnement", "nomenclature"])
        let iAchat = colonne(["prix net", "prix achat", "prix d'achat", "achat"])
        let iVente = colonne(["prix public", "prix vente", "prix de vente", "revente", "vente"])
        var manquantes: [String] = []
        if iLibelle == nil { manquantes.append("libellé") }
        if iAchat == nil && iVente == nil { manquantes.append("prix") }
        guard manquantes.isEmpty, let iLibelle else { throw Erreur.colonnes(manquantes.joined(separator: ", ")) }

        let iCode = colonne(["code de l'article", "code article", "code", "référence", "reference"], sauf: ["ean", "agence", "produit"])
        let iMarque = colonne(["nom de la marque", "marque"], sauf: ["référence"])
        let iEco = colonne(["ecocontribution", "éco-contribution", "eco-contribution", "écocontribution"])
        let iUnite = colonne(["libellé unité de vente", "unité", "unite"])
        let iFamille = colonne(["nomenclature niv. 1", "famille"], sauf: ["sous"])
        let iSousFamille = colonne(["nomenclature niv. 2", "sous-famille", "sous famille"])
        let iCategorie = colonne(["nomenclature niv. 3", "catégorie", "categorie"])
        let iImage = colonne(["url image", "image"])
        let iEnseigne = colonne(["nom de l'enseigne", "fournisseur"])

        func valeur(_ ligne: [String], _ i: Int?) -> String {
            guard let i, i < ligne.count else { return "" }
            return ligne[i].trimmingCharacters(in: .whitespaces)
        }
        func nombre(_ ligne: [String], _ i: Int?) -> Double {
            let brut = valeur(ligne, i)
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\u{00A0}", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Double(brut) ?? 0
        }

        var fournisseur = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "Tarifs ", with: "")
        if let premiere = lignes.first, !valeur(premiere, iEnseigne).isEmpty {
            fournisseur = valeur(premiere, iEnseigne).capitalized
        }

        try contexte.delete(model: Produit.self, where: #Predicate { $0.fournisseur == fournisseur })

        var nombreImportes = 0
        for ligne in lignes {
            let libelle = valeur(ligne, iLibelle)
            guard !libelle.isEmpty else { continue }
            let achat = nombre(ligne, iAchat)
            let vente = nombre(ligne, iVente)
            contexte.insert(Produit(code: valeur(ligne, iCode),
                                    libelle: libelle,
                                    marque: valeur(ligne, iMarque),
                                    prixAchat: iAchat == nil ? vente : achat,
                                    prixPublic: iVente == nil ? achat : vente,
                                    ecoContribution: nombre(ligne, iEco),
                                    unite: valeur(ligne, iUnite),
                                    famille: valeur(ligne, iFamille),
                                    sousFamille: valeur(ligne, iSousFamille),
                                    categorie: valeur(ligne, iCategorie),
                                    image: valeur(ligne, iImage),
                                    fournisseur: fournisseur))
            nombreImportes += 1
        }
        try contexte.save()
        return nombreImportes
    }

    /// Découpe un CSV en tenant compte des guillemets.
    static func lireCSV(_ texte: String, separateur: Character) -> [[String]] {
        var lignes: [[String]] = []
        var ligne: [String] = []
        var champ = ""
        var entreGuillemets = false
        var precedent: Character?
        for caractere in texte {
            if entreGuillemets {
                if caractere == "\"" {
                    entreGuillemets = false
                } else {
                    champ.append(caractere)
                }
            } else if caractere == "\"" {
                if precedent == "\"" { champ.append("\"") }
                entreGuillemets = true
            } else if caractere == separateur {
                ligne.append(champ)
                champ = ""
            } else if caractere.isNewline {
                ligne.append(champ)
                champ = ""
                if ligne.contains(where: { !$0.isEmpty }) { lignes.append(ligne) }
                ligne = []
            } else {
                champ.append(caractere)
            }
            precedent = caractere
        }
        ligne.append(champ)
        if ligne.contains(where: { !$0.isEmpty }) { lignes.append(ligne) }
        return lignes
    }
}

// MARK: - Liste et recherche

/// Résultats de recherche (limités pour rester rapides avec des milliers de produits).
struct ResultatsProduits: View {
    @Query private var produits: [Produit]
    @AppStorage(ReglagesProduits.coefficient) private var coefficient = 0.0
    var choisir: ((Produit) -> Void)?

    init(recherche: String, famille: String, choisir: ((Produit) -> Void)? = nil) {
        self.choisir = choisir
        let texte = recherche.trimmingCharacters(in: .whitespaces)
        let predicat: Predicate<Produit>
        switch (texte.isEmpty, famille.isEmpty) {
        case (true, true):
            predicat = #Predicate { _ in true }
        case (true, false):
            predicat = #Predicate { $0.famille == famille }
        case (false, true):
            predicat = #Predicate {
                $0.libelle.localizedStandardContains(texte)
                    || $0.code.localizedStandardContains(texte)
                    || $0.marque.localizedStandardContains(texte)
            }
        case (false, false):
            predicat = #Predicate {
                $0.famille == famille && ($0.libelle.localizedStandardContains(texte)
                    || $0.code.localizedStandardContains(texte)
                    || $0.marque.localizedStandardContains(texte))
            }
        }
        var descripteur = FetchDescriptor<Produit>(predicate: predicat, sortBy: [SortDescriptor(\.libelle)])
        descripteur.fetchLimit = 150
        _produits = Query(descripteur)
    }

    var body: some View {
        if produits.isEmpty {
            Text("Aucun produit trouvé.")
                .foregroundStyle(.secondary)
        }
        ForEach(produits) { produit in
            if let choisir {
                Button { choisir(produit) } label: { LigneProduit(produit: produit, coefficient: coefficient) }
                    .foregroundStyle(.primary)
            } else {
                LigneProduit(produit: produit, coefficient: coefficient)
            }
        }
        if produits.count == 150 {
            Text("Seuls les 150 premiers résultats sont affichés : précise ta recherche.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct LigneProduit: View {
    let produit: Produit
    let coefficient: Double

    var body: some View {
        let vente = produit.prixVente(coefficient: coefficient)
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: produit.image)) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "shippingbox").foregroundStyle(.tertiary)
            }
            .frame(width: 44, height: 44)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(produit.libelle)
                    .font(.subheadline)
                    .lineLimit(2)
                Text([produit.marque, produit.code].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Text("Achat \(produit.coutAchat.enEuros)")
                    Text("Vente \(vente.enEuros)").fontWeight(.semibold)
                    if vente > 0 {
                        Text("Marge \(((vente - produit.coutAchat) / vente * 100).enQuantite) %")
                            .foregroundStyle(.green)
                    }
                }
                .font(.caption)
            }
        }
    }
}

/// Familles présentes (filtre).
private struct FiltreFamilles: View {
    @Query(sort: \Produit.famille) private var produits: [Produit]
    @Binding var famille: String

    init(famille: Binding<String>) {
        _famille = famille
        var descripteur = FetchDescriptor<Produit>(sortBy: [SortDescriptor(\.famille)])
        descripteur.propertiesToFetch = [\.famille]
        _produits = Query(descripteur)
    }

    var body: some View {
        let familles = Array(Set(produits.map(\.famille).filter { !$0.isEmpty })).sorted()
        Picker("Famille", selection: $famille) {
            Text("Toutes").tag("")
            ForEach(familles, id: \.self) { Text($0).tag($0) }
        }
    }
}

// MARK: - Réglages : tarifs fournisseurs

struct ProduitsView: View {
    @Environment(\.modelContext) private var contexte
    @AppStorage(ReglagesProduits.coefficient) private var coefficient = 0.0
    @State private var recherche = ""
    @State private var famille = ""
    @State private var importOuvert = false
    @State private var message: String?
    @State private var enCours = false

    private var nombre: Int {
        (try? contexte.fetchCount(FetchDescriptor<Produit>())) ?? 0
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Produits", value: "\(nombre)")
                Button {
                    importOuvert = true
                } label: {
                    Label(enCours ? "Import en cours…" : "Importer un tarif (CSV)", systemImage: "square.and.arrow.down")
                }
                .disabled(enCours)
            } footer: {
                Text("Fichier CSV avec au moins un libellé et un prix. Un nouvel import du même fournisseur remplace l'ancien tarif.")
            }

            Section {
                Picker("Prix de revente", selection: Binding(
                    get: { coefficient > 0 },
                    set: { coefficient = $0 ? max(coefficient, 1.3) : 0 })) {
                    Text("Prix public").tag(false)
                    Text("Achat × coefficient").tag(true)
                }
                if coefficient > 0 {
                    Stepper(value: $coefficient, in: 1...3, step: 0.05) {
                        LabeledContent("Coefficient", value: coefficient.enQuantite)
                    }
                }
            } header: {
                Text("Revente")
            } footer: {
                Text("Le prix d'achat et la marge ne sont jamais imprimés sur le devis.")
            }

            if nombre > 0 {
                Section {
                    FiltreFamilles(famille: $famille)
                    ResultatsProduits(recherche: recherche, famille: famille)
                } header: {
                    Text("Produits")
                }
            }
        }
        .searchable(text: $recherche, prompt: "Libellé, marque ou code")
        .navigationTitle("Tarifs fournisseurs")
        .fileImporter(isPresented: $importOuvert,
                      allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText]) { resultat in
            guard case .success(let url) = resultat else { return }
            enCours = true
            Task { @MainActor in
                do {
                    let n = try ImportProduits.importer(url, contexte: contexte)
                    message = "\(n) produits importés."
                } catch {
                    message = error.localizedDescription
                }
                enCours = false
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - Ajouter un produit au devis

struct ChoixProduitView: View {
    let chantier: Chantier
    let piece: Piece?
    var quandTermine: () -> Void
    @State private var recherche = ""
    @State private var famille = ""
    @State private var choisi: Produit?

    var body: some View {
        List {
            FiltreFamilles(famille: $famille)
            ResultatsProduits(recherche: recherche, famille: famille) { choisi = $0 }
        }
        .searchable(text: $recherche, prompt: "Libellé, marque ou code")
        .navigationTitle("Fournitures")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $choisi) { produit in
            ProduitFormView(chantier: chantier, piece: piece, produit: produit, quandTermine: quandTermine)
        }
    }
}

struct ProduitFormView: View {
    @Environment(\.modelContext) private var contexte
    @AppStorage(Reglages.franchiseTVA) private var franchiseTVA = false
    @AppStorage(ReglagesProduits.coefficient) private var coefficient = 0.0
    let chantier: Chantier
    let piece: Piece?
    let produit: Produit
    var quandTermine: () -> Void

    @State private var quantite: Double = 1
    @State private var prix: Double = 0
    @State private var tva: Double = 10
    @State private var avecPose = false

    private var marge: Double { (prix - produit.coutAchat) * quantite }

    var body: some View {
        Form {
            Section {
                Text(produit.libelle).font(.headline)
                Text([produit.marque, produit.code, produit.unite].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Quantité et prix") {
                LabeledContent("Quantité") {
                    TextField("0", value: $quantite, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Prix de vente HT") {
                    TextField("0", value: $prix, format: .currency(code: "EUR"))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                if !franchiseTVA {
                    Picker("TVA", selection: $tva) {
                        ForEach(TauxTVA.valeurs, id: \.self) { Text($0.enPourcentage).tag($0) }
                    }
                }
                LabeledContent("Total HT", value: (quantite * prix).enEuros)
            }
            Section {
                LabeledContent("Prix d'achat", value: produit.coutAchat.enEuros)
                LabeledContent("Marge", value: marge.enEuros)
                    .foregroundStyle(marge >= 0 ? Color.green : Color.red)
            } header: {
                Text("Pour toi (non imprimé)")
            }
        }
        .navigationTitle("Fourniture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") { ajouter() }
                    .disabled(quantite <= 0)
            }
        }
        .onAppear {
            prix = produit.prixVente(coefficient: coefficient)
            tva = franchiseTVA ? 0 : 10
        }
    }

    private func ajouter() {
        var designation = "Fourniture : " + produit.libelle
        if !produit.marque.isEmpty && !produit.libelle.localizedCaseInsensitiveContains(produit.marque) {
            designation += " (\(produit.marque))"
        }
        let ligne = LigneDevis(designation: designation,
                               unite: produit.uniteDevis,
                               quantite: quantite,
                               prixHT: prix,
                               tauxTVA: franchiseTVA ? 0 : tva,
                               ordre: chantier.lignesDevis.count)
        ligne.section = piece?.nom ?? ""
        ligne.prixAchat = produit.coutAchat
        DevisView.ajouter(ligne, a: chantier, contexte: contexte)
        quandTermine()
    }
}
