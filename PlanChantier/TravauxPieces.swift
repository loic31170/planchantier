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

                if recherche.isEmpty {
                    Section {
                        NavigationLink {
                            ChoixProduitView(chantier: chantier, piece: piece) { dismiss() }
                        } label: {
                            Label("Fournitures (tarifs fournisseurs)", systemImage: "shippingbox")
                        }
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

/// Choix des murs (numéros du plan) et précision libre. Aucun mur coché = toute la pièce.
struct ChoixEmplacement: View {
    let piece: Piece?
    @Binding var murs: Set<Int>
    @Binding var precision: String

    var body: some View {
        Section {
            if let piece {
                let details = piece.detailMurs()
                if !details.isEmpty {
                    PlanCoteView(segments: piece.segments, nom: nil, echelleVisible: false)
                        .frame(height: 200)
                        .background(Color(.systemBackground))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                        puce(titre: "Toute la pièce", detail: piece.surfaceMursNette.enMetresCarres, active: murs.isEmpty) {
                            murs = []
                        }
                        ForEach(Array(details.enumerated()), id: \.offset) { index, mur in
                            let numero = index + 1
                            puce(titre: "Mur \(numero)", detail: mur.nette.enMetresCarres, active: murs.contains(numero)) {
                                if murs.contains(numero) { murs.remove(numero) } else { murs.insert(numero) }
                                if murs.count == details.count { murs = [] }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            TextField("Précision (ex. sous la fenêtre)", text: $precision, axis: .vertical)
        } header: {
            Text("Emplacement")
        } footer: {
            if piece != nil {
                Text("Touche plusieurs murs pour les cumuler. Les surfaces sont nettes (portes et fenêtres déduites).")
            }
        }
    }

    private func puce(titre: String, detail: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(titre).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(active ? Color.accentColor : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(active ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    static func texte(murs: Set<Int>, precision: String) -> String {
        var elements: [String] = []
        let tries = murs.sorted()
        if tries.count == 1 { elements.append("mur \(tries[0])") }
        if tries.count > 1 { elements.append("murs " + tries.map(String.init).joined(separator: ", ")) }
        let p = precision.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { elements.append(p) }
        return elements.isEmpty ? "" : " (" + elements.joined(separator: ", ") + ")"
    }

    /// Quantité d'une prestation calculée sur les murs choisis (nil si le choix ne change rien).
    static func quantite(_ base: BaseQuantite, piece: Piece, murs: Set<Int>) -> Double? {
        let details = piece.detailMurs()
        let choisis = details.enumerated().filter { murs.contains($0.offset + 1) }.map { $0.element }
        guard !murs.isEmpty, !choisis.isEmpty else { return nil }
        switch base {
        case .surfaceMursNette: return choisis.reduce(0) { $0 + $1.nette }
        case .surfaceMursBrute: return choisis.reduce(0) { $0 + $1.brute }
        case .perimetre, .plinthes: return choisis.reduce(0) { $0 + $1.longueur }
        default: return nil
        }
    }
}

extension Piece {
    /// Longueur, surface brute et surface nette de chaque mur, dans l'ordre des numéros du plan.
    func detailMurs() -> [(longueur: Double, brute: Double, nette: Double)] {
        let murs = PlanPieceView.mursOrdonnes(segments)
        guard !murs.isEmpty else { return [] }
        let ouvertures = PlanPieceView.redresser(segments).filter { $0.genre == .porte || $0.genre == .fenetre }
        let brutes = murs.map { $0.longueur * ($0.hauteur ?? hauteur) }
        var nettes = brutes

        func distance(_ x: Double, _ y: Double, _ m: SegmentPlan) -> Double {
            let dx = m.x2 - m.x1, dy = m.y2 - m.y1
            let l2 = dx * dx + dy * dy
            let t = l2 > 0 ? max(0, min(1, ((x - m.x1) * dx + (y - m.y1) * dy) / l2)) : 0
            let px = m.x1 + t * dx, py = m.y1 + t * dy
            return ((x - px) * (x - px) + (y - py) * (y - py)).squareRoot()
        }

        for o in ouvertures {
            let mx = (o.x1 + o.x2) / 2, my = (o.y1 + o.y2) / 2
            guard let i = murs.indices.min(by: { distance(mx, my, murs[$0]) < distance(mx, my, murs[$1]) }) else { continue }
            nettes[i] -= o.longueur * (o.hauteur ?? (o.genre == .porte ? 2.04 : 1.25))
        }
        return murs.indices.map { (murs[$0].longueur, brutes[$0], max(nettes[$0], 0)) }
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
    @State private var murs: Set<Int> = []
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
            ChoixEmplacement(piece: piece, murs: $murs, precision: $precision)
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
            recalculer()
        }
        .onChange(of: murs) { _, _ in recalculer() }
    }

    private func recalculer() {
        guard let piece, prestation.base != .manuelle else { return }
        let total = ChoixEmplacement.quantite(prestation.base, piece: piece, murs: murs)
            ?? prestation.base.quantite(pour: piece)
        quantite = (total * 100).rounded() / 100
    }

    private func ajouter() {
        let ligne = LigneDevis(designation: prestation.nom + ChoixEmplacement.texte(murs: murs, precision: precision),
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
    @State private var murs: Set<Int> = []
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

            ChoixEmplacement(piece: piece, murs: $murs, precision: $precision)
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
        let emplacement = ChoixEmplacement.texte(murs: murs, precision: precision)
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
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.gradient)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.white)
                }
            Text("Générer un devis")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            Text("Travaux pièce par pièce")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
