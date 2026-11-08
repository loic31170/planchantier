import SwiftUI
import SwiftData

// MARK: - Ouvrages tout prêts (plusieurs lignes d'un coup)

/// Un ensemble de prestations qui vont ensemble, par exemple :
/// saignée + gaine + rebouchage + sortie de câble pour alimenter un radiateur.
struct Ouvrage: Identifiable {
    struct Composant: Identifiable {
        var id: String { prestation }
        let prestation: String
        let unite: UniteDevis
        let prixParDefaut: Double
        /// Quantité en fonction de la longueur de saignée (en mètres).
        let quantite: (Double) -> Double
        var coche = true
    }

    let id: String
    let nom: String
    let categorie: CategorieTravaux
    let symbole: String
    let longueurParDefaut: Double?
    var libelleParametre = "Longueur de saignée (m)"
    let composants: [Composant]

    static let tous: [Ouvrage] = [
        Ouvrage(id: "radiateur", nom: "Alimentation électrique d'un radiateur", categorie: .electricite,
                symbole: "heater.vertical", longueurParDefaut: 3, composants: [
                    Composant(prestation: "Création de saignée dans mur pour passage de gaine", unite: .ml, prixParDefaut: 25, quantite: { $0 }),
                    Composant(prestation: "Fourniture et pose de gaine ICTA avec câble", unite: .ml, prixParDefaut: 9, quantite: { $0 + 1 }),
                    Composant(prestation: "Création d'une sortie de câble pour radiateur", unite: .unite, prixParDefaut: 80, quantite: { _ in 1 }),
                    Composant(prestation: "Rebouchage de saignée", unite: .ml, prixParDefaut: 10, quantite: { $0 }),
                    Composant(prestation: "Création d'un circuit au tableau électrique", unite: .unite, prixParDefaut: 65, quantite: { _ in 1 }, coche: false),
                    Composant(prestation: "Pose d'un radiateur électrique", unite: .unite, prixParDefaut: 90, quantite: { _ in 1 }),
                    Composant(prestation: "Fourniture d'un radiateur électrique", unite: .unite, prixParDefaut: 350, quantite: { _ in 1 }, coche: false),
                ]),
        Ouvrage(id: "prise", nom: "Création d'une prise encastrée", categorie: .electricite,
                symbole: "powerplug", longueurParDefaut: 2, composants: [
                    Composant(prestation: "Création de saignée dans mur pour passage de gaine", unite: .ml, prixParDefaut: 25, quantite: { $0 }),
                    Composant(prestation: "Fourniture et pose de gaine ICTA avec câble", unite: .ml, prixParDefaut: 9, quantite: { $0 + 1 }),
                    Composant(prestation: "Création d'une prise de courant 16 A", unite: .unite, prixParDefaut: 75, quantite: { _ in 1 }),
                    Composant(prestation: "Rebouchage de saignée", unite: .ml, prixParDefaut: 10, quantite: { $0 }),
                ]),
        Ouvrage(id: "lumiere", nom: "Création d'un point lumineux", categorie: .electricite,
                symbole: "lightbulb", longueurParDefaut: 3, composants: [
                    Composant(prestation: "Création de saignée dans mur pour passage de gaine", unite: .ml, prixParDefaut: 25, quantite: { $0 }),
                    Composant(prestation: "Fourniture et pose de gaine ICTA avec câble", unite: .ml, prixParDefaut: 9, quantite: { $0 + 1 }),
                    Composant(prestation: "Création d'un point lumineux avec interrupteur", unite: .unite, prixParDefaut: 110, quantite: { _ in 1 }),
                    Composant(prestation: "Rebouchage de saignée", unite: .ml, prixParDefaut: 10, quantite: { $0 }),
                ]),
        Ouvrage(id: "baignoire-douche", nom: "Remplacement d'une baignoire par une douche", categorie: .plomberie,
                symbole: "shower", longueurParDefaut: 6, libelleParametre: "Surface de faïence (m²)", composants: [
                    Composant(prestation: "Dépose d'une baignoire et de son habillage", unite: .unite, prixParDefaut: 250, quantite: { _ in 1 }),
                    Composant(prestation: "Adaptation de l'évacuation pour receveur", unite: .unite, prixParDefaut: 180, quantite: { _ in 1 }),
                    Composant(prestation: "Fourniture et pose d'un receveur de douche extra-plat", unite: .unite, prixParDefaut: 450, quantite: { _ in 1 }),
                    Composant(prestation: "Système d'étanchéité sous carrelage (SPEC)", unite: .m2, prixParDefaut: 35, quantite: { $0 }),
                    Composant(prestation: "Pose de faïence murale", unite: .m2, prixParDefaut: 55, quantite: { $0 }),
                    Composant(prestation: "Fourniture et pose d'une paroi de douche", unite: .unite, prixParDefaut: 400, quantite: { _ in 1 }),
                    Composant(prestation: "Fourniture et pose d'une colonne de douche avec mitigeur", unite: .unite, prixParDefaut: 280, quantite: { _ in 1 }),
                    Composant(prestation: "Évacuation des gravats", unite: .forfait, prixParDefaut: 200, quantite: { _ in 1 }, coche: false),
                ]),
        Ouvrage(id: "lavabo", nom: "Installation d'un lavabo", categorie: .plomberie,
                symbole: "sink", longueurParDefaut: nil, composants: [
                    Composant(prestation: "Création d'une alimentation eau froide et eau chaude", unite: .unite, prixParDefaut: 150, quantite: { _ in 1 }),
                    Composant(prestation: "Création d'une évacuation PVC", unite: .unite, prixParDefaut: 120, quantite: { _ in 1 }),
                    Composant(prestation: "Pose d'un lavabo ou d'une vasque", unite: .unite, prixParDefaut: 180, quantite: { _ in 1 }),
                ]),
        Ouvrage(id: "wc", nom: "Installation d'un WC", categorie: .plomberie,
                symbole: "toilet", longueurParDefaut: nil, composants: [
                    Composant(prestation: "Création d'une alimentation eau froide et eau chaude", unite: .unite, prixParDefaut: 150, quantite: { _ in 1 }),
                    Composant(prestation: "Création d'une évacuation PVC", unite: .unite, prixParDefaut: 120, quantite: { _ in 1 }),
                    Composant(prestation: "Pose d'un WC", unite: .unite, prixParDefaut: 220, quantite: { _ in 1 }),
                ]),
    ]
}

// MARK: - Choix des travaux pour une pièce

/// Ajoute des travaux au devis, pour une pièce précise ou pour le chantier en général.
struct AjoutTravauxView: View {
    @Environment(\.dismiss) private var dismiss
    let chantier: Chantier
    let piece: Piece?

    @Query(sort: \Prestation.nom) private var prestations: [Prestation]
    @State private var recherche = ""

    private var filtrees: [Prestation] {
        guard !recherche.isEmpty else { return prestations }
        return prestations.filter { $0.nom.localizedCaseInsensitiveContains(recherche) }
    }

    var body: some View {
        NavigationStack {
            List {
                if recherche.isEmpty {
                    Section {
                        ForEach(Ouvrage.tous) { ouvrage in
                            NavigationLink {
                                OuvrageFormView(chantier: chantier, piece: piece, ouvrage: ouvrage) { dismiss() }
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ouvrage.nom)
                                        Text(ouvrage.composants.filter(\.coche).map { $0.prestation }.joined(separator: " + "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                } icon: {
                                    Image(systemName: ouvrage.symbole).foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    } header: {
                        Text("Ouvrages tout prêts")
                    } footer: {
                        Text("Ajoute en une fois toutes les lignes nécessaires. Tu choisis ce que tu gardes.")
                    }
                }

                ForEach(CategorieTravaux.allCases) { categorie in
                    let liste = filtrees.filter { $0.categorie == categorie }
                    if !liste.isEmpty {
                        Section {
                            ForEach(liste) { prestation in
                                NavigationLink {
                                    TravailFormView(chantier: chantier, piece: piece, prestation: prestation) { dismiss() }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(prestation.nom)
                                        Text("\(prestation.prixHT.enEuros) HT / \(prestation.unite.rawValue)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Label(categorie.rawValue, systemImage: categorie.symbole)
                        }
                    }
                }
            }
            .searchable(text: $recherche, prompt: "Rechercher une prestation")
            .navigationTitle(piece?.nom ?? "Travaux généraux")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Emplacement dans la pièce

/// Choix du mur (numéros du plan) et précision libre.
struct ChoixEmplacement: View {
    let piece: Piece?
    @Binding var mur: Int
    @Binding var precision: String

    var body: some View {
        Section {
            if let piece {
                let nombre = PlanPieceView.mursOrdonnes(piece.segments).count
                if nombre > 0 {
                    PlanCoteView(segments: piece.segments, nom: nil, echelleVisible: false)
                        .frame(height: 200)
                        .background(Color(.systemBackground))
                    Picker("Mur", selection: $mur) {
                        Text("Non précisé").tag(0)
                        ForEach(1...nombre, id: \.self) { n in
                            Text("Mur \(n)").tag(n)
                        }
                    }
                }
            }
            TextField("Précision (ex. sous la fenêtre)", text: $precision, axis: .vertical)
        } header: {
            Text("Emplacement")
        }
    }

    static func texte(mur: Int, precision: String) -> String {
        var elements: [String] = []
        if mur > 0 { elements.append("mur \(mur)") }
        let p = precision.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { elements.append(p) }
        return elements.isEmpty ? "" : " (" + elements.joined(separator: ", ") + ")"
    }
}

// MARK: - Une prestation dans une pièce

struct TravailFormView: View {
    @Environment(\.modelContext) private var contexte
    @AppStorage(Reglages.franchiseTVA) private var franchiseTVA = false
    let chantier: Chantier
    let piece: Piece?
    let prestation: Prestation
    var quandTermine: () -> Void

    @State private var quantite: Double = 1
    @State private var prix: Double = 0
    @State private var mur = 0
    @State private var precision = ""

    var body: some View {
        Form {
            Section {
                Text(prestation.nom).font(.headline)
                if let piece, prestation.base != .manuelle {
                    Text("Calculé sur \(piece.nom) : \(prestation.base.libelle.lowercased())")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            ChoixEmplacement(piece: piece, mur: $mur, precision: $precision)
        }
        .navigationTitle("Ajouter au devis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") { ajouter() }
                    .disabled(quantite <= 0)
            }
        }
        .onAppear {
            prix = prestation.prixHT
            if let piece, prestation.base != .manuelle {
                quantite = (prestation.base.quantite(pour: piece) * 100).rounded() / 100
            }
        }
    }

    private func ajouter() {
        let ligne = LigneDevis(designation: prestation.nom + ChoixEmplacement.texte(mur: mur, precision: precision),
                               unite: prestation.unite,
                               quantite: quantite,
                               prixHT: prix,
                               tauxTVA: franchiseTVA ? 0 : prestation.tauxTVA,
                               ordre: chantier.lignesDevis.count)
        ligne.section = piece?.nom ?? ""
        DevisView.ajouter(ligne, a: chantier, contexte: contexte)
        quandTermine()
    }
}

// MARK: - Un ouvrage dans une pièce

struct OuvrageFormView: View {
    @Environment(\.modelContext) private var contexte
    @AppStorage(Reglages.franchiseTVA) private var franchiseTVA = false
    @Query private var prestations: [Prestation]
    let chantier: Chantier
    let piece: Piece?
    let ouvrage: Ouvrage
    var quandTermine: () -> Void

    @State private var longueur: Double = 0
    @State private var composants: [Ouvrage.Composant] = []
    @State private var mur = 0
    @State private var precision = ""

    private func prestation(_ nom: String) -> Prestation? {
        prestations.first { $0.nom.caseInsensitiveCompare(nom) == .orderedSame }
    }

    private func prix(_ composant: Ouvrage.Composant) -> Double {
        prestation(composant.prestation)?.prixHT ?? composant.prixParDefaut
    }

    private func quantite(_ composant: Ouvrage.Composant) -> Double {
        (composant.quantite(longueur) * 100).rounded() / 100
    }

    private var total: Double {
        composants.filter(\.coche).reduce(0) { $0 + quantite($1) * prix($1) }
    }

    var body: some View {
        Form {
            Section {
                Text(ouvrage.nom).font(.headline)
                if ouvrage.longueurParDefaut != nil {
                    LabeledContent(ouvrage.libelleParametre) {
                        TextField("0", value: $longueur, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if let piece {
                        Text("Hauteur sous plafond de \(piece.nom) : \(piece.hauteur.enMetres)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                ForEach($composants) { $composant in
                    Toggle(isOn: $composant.coche) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(composant.prestation)
                            Text("\(quantite(composant).enQuantite) \(composant.unite.rawValue) × \(prix(composant).enEuros)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                LabeledContent("Total HT", value: total.enEuros)
                    .fontWeight(.semibold)
            } header: {
                Text("Lignes ajoutées au devis")
            } footer: {
                Text("Les prix viennent de ton catalogue. Tu pourras modifier chaque ligne ensuite dans le devis.")
            }

            ChoixEmplacement(piece: piece, mur: $mur, precision: $precision)
        }
        .navigationTitle("Ouvrage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") { ajouter() }
                    .disabled(!composants.contains(where: \.coche))
            }
        }
        .onAppear {
            if composants.isEmpty {
                composants = ouvrage.composants
                longueur = ouvrage.longueurParDefaut ?? 0
            }
        }
    }

    private func ajouter() {
        let emplacement = ChoixEmplacement.texte(mur: mur, precision: precision)
        for composant in composants where composant.coche {
            let catalogue = prestation(composant.prestation)
            let ligne = LigneDevis(designation: composant.prestation + emplacement,
                                   unite: catalogue?.unite ?? composant.unite,
                                   quantite: quantite(composant),
                                   prixHT: prix(composant),
                                   tauxTVA: franchiseTVA ? 0 : (catalogue?.tauxTVA ?? 10),
                                   ordre: chantier.lignesDevis.count)
            ligne.section = piece?.nom ?? ""
            DevisView.ajouter(ligne, a: chantier, contexte: contexte)
        }
        quandTermine()
    }
}

// MARK: - Générer un devis depuis l'accueil

struct AssistantDevisView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Chantier.dateCreation, order: .reverse) private var chantiers: [Chantier]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(chantiers.filter { !$0.archive }) { chantier in
                        NavigationLink {
                            DevisView(chantier: chantier)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(chantier.nom).font(.headline)
                                Text(chantier.lignesDevis.isEmpty
                                     ? "\(chantier.pieces.count) pièce\(chantier.pieces.count > 1 ? "s" : "") · pas encore de devis"
                                     : "Devis \(chantier.numeroDevis) · \(TotauxDevis(lignes: chantier.lignesDevis, franchise: false).ht.enEuros) HT")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("Choisis le chantier")
                }
            }
            .overlay {
                if chantiers.filter({ !$0.archive }).isEmpty {
                    ContentUnavailableView("Aucun chantier", systemImage: "doc.text",
                                           description: Text("Crée d'abord un chantier depuis l'accueil."))
                }
            }
            .navigationTitle("Générer un devis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}

struct CarteDevis: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.orange.gradient)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.white)
                }
            Text("Générer un devis")
                .font(.headline)
                .frame(maxWidth: .infinity)
            Text("Travaux pièce par pièce")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
