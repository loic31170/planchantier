import Foundation
import SwiftData

// MARK: - Réglages de l'entreprise (stockés dans les préférences de l'appli)

enum Reglages {
    static let nom = "entreprise.nom"
    static let adresse = "entreprise.adresse"
    static let telephone = "entreprise.telephone"
    static let email = "entreprise.email"
    static let siret = "entreprise.siret"
    static let franchiseTVA = "entreprise.franchiseTVA"
    static let validite = "devis.validiteJours"
    static let prochainNumero = "devis.prochainNumero"
    static let catalogueInitialise = "catalogue.initialise"
    static let catalogueTravaux = "catalogue.travaux.v2"
}

struct Entreprise {
    var nom: String
    var adresse: String
    var telephone: String
    var email: String
    var siret: String
    var franchiseTVA: Bool
    var validite: Int

    static var actuelle: Entreprise {
        let d = UserDefaults.standard
        return Entreprise(nom: d.string(forKey: Reglages.nom) ?? "",
                          adresse: d.string(forKey: Reglages.adresse) ?? "",
                          telephone: d.string(forKey: Reglages.telephone) ?? "",
                          email: d.string(forKey: Reglages.email) ?? "",
                          siret: d.string(forKey: Reglages.siret) ?? "",
                          franchiseTVA: d.bool(forKey: Reglages.franchiseTVA),
                          validite: (d.object(forKey: Reglages.validite) as? Int) ?? 30)
    }
}

// MARK: - Unités et bases de calcul

enum UniteDevis: String, Codable, CaseIterable {
    case m2 = "m²"
    case ml = "ml"
    case unite = "u"
    case heure = "h"
    case forfait = "forfait"
}

/// D'où vient la quantité d'une prestation.
enum BaseQuantite: String, Codable, CaseIterable, Identifiable {
    case manuelle
    case surfaceSol
    case surfacePlafond
    case surfaceMursNette
    case surfaceMursBrute
    case perimetre
    case plinthes
    case portes
    case fenetres

    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .manuelle: return "Saisie manuelle"
        case .surfaceSol: return "Surface au sol"
        case .surfacePlafond: return "Surface du plafond"
        case .surfaceMursNette: return "Surface des murs (portes et fenêtres déduites)"
        case .surfaceMursBrute: return "Surface des murs (brute)"
        case .perimetre: return "Périmètre"
        case .plinthes: return "Longueur de plinthes (portes déduites)"
        case .portes: return "Nombre de portes"
        case .fenetres: return "Nombre de fenêtres"
        }
    }

    var uniteConseillee: UniteDevis {
        switch self {
        case .manuelle: return .forfait
        case .surfaceSol, .surfacePlafond, .surfaceMursNette, .surfaceMursBrute: return .m2
        case .perimetre, .plinthes: return .ml
        case .portes, .fenetres: return .unite
        }
    }

    func quantite(pour piece: Piece) -> Double {
        switch self {
        case .manuelle: return 0
        case .surfaceSol, .surfacePlafond: return piece.surfaceSol
        case .surfaceMursNette: return piece.surfaceMursNette
        case .surfaceMursBrute: return piece.surfaceMursBrute
        case .perimetre: return piece.perimetre
        case .plinthes: return piece.lineairePlinthes
        case .portes: return Double(piece.segments.filter { $0.genre == .porte }.count)
        case .fenetres: return Double(piece.segments.filter { $0.genre == .fenetre }.count)
        }
    }
}

/// Corps de métier, pour ranger le catalogue.
enum CategorieTravaux: String, CaseIterable, Identifiable {
    case demolition = "Démolition, maçonnerie"
    case electricite = "Électricité"
    case plomberie = "Plomberie"
    case chauffage = "Chauffage"
    case peinture = "Peinture"
    case sols = "Sols"
    case menuiserie = "Menuiserie"
    case divers = "Divers"

    var id: String { rawValue }

    var symbole: String {
        switch self {
        case .demolition: return "hammer"
        case .electricite: return "bolt"
        case .plomberie: return "drop"
        case .chauffage: return "heater.vertical"
        case .peinture: return "paintbrush"
        case .sols: return "square.grid.3x3"
        case .menuiserie: return "door.left.hand.open"
        case .divers: return "ellipsis.circle"
        }
    }

    /// Rangement des prestations créées avant les catégories.
    static func deviner(_ nom: String) -> CategorieTravaux {
        let n = nom.lowercased()
        if n.contains("peinture") || n.contains("enduit") || n.contains("préparation des murs") { return .peinture }
        if n.contains("sol") || n.contains("ragréage") || n.contains("plinthe") || n.contains("carrelage") || n.contains("parquet") { return .sols }
        if n.contains("prise") || n.contains("électri") || n.contains("gaine") || n.contains("saignée") || n.contains("lumin") { return .electricite }
        if n.contains("radiateur") || n.contains("chauffage") { return .chauffage }
        if n.contains("eau") || n.contains("évacuation") || n.contains("lavabo") || n.contains("wc") { return .plomberie }
        if n.contains("porte") || n.contains("fenêtre") || n.contains("placard") { return .menuiserie }
        if n.contains("cloison") || n.contains("dépose") || n.contains("démoli") { return .demolition }
        return .divers
    }
}

enum TauxTVA {
    static let valeurs: [Double] = [0, 5.5, 10, 20]
}

// MARK: - Catalogue et lignes de devis

/// Une prestation de ton catalogue, avec ton prix.
@Model
final class Prestation {
    var nom: String
    var uniteRaw: String
    var prixHT: Double
    var tauxTVA: Double
    var baseRaw: String
    var categorieRaw: String = ""

    init(nom: String, unite: UniteDevis, prixHT: Double, tauxTVA: Double = 10, base: BaseQuantite,
         categorie: CategorieTravaux? = nil) {
        self.nom = nom
        self.uniteRaw = unite.rawValue
        self.prixHT = prixHT
        self.tauxTVA = tauxTVA
        self.baseRaw = base.rawValue
        self.categorieRaw = (categorie ?? CategorieTravaux.deviner(nom)).rawValue
    }

    var unite: UniteDevis { UniteDevis(rawValue: uniteRaw) ?? .unite }
    var base: BaseQuantite { BaseQuantite(rawValue: baseRaw) ?? .manuelle }
    var categorie: CategorieTravaux {
        CategorieTravaux(rawValue: categorieRaw) ?? CategorieTravaux.deviner(nom)
    }
}

/// Une ligne du devis d'un chantier.
@Model
final class LigneDevis {
    var designation: String
    var uniteRaw: String
    var quantite: Double
    var prixHT: Double
    var tauxTVA: Double
    var ordre: Int
    /// Pièce concernée (nom), vide pour les travaux généraux.
    var section: String = ""
    var chantier: Chantier?

    init(designation: String, unite: UniteDevis, quantite: Double, prixHT: Double, tauxTVA: Double, ordre: Int) {
        self.designation = designation
        self.uniteRaw = unite.rawValue
        self.quantite = quantite
        self.prixHT = prixHT
        self.tauxTVA = tauxTVA
        self.ordre = ordre
    }

    var unite: UniteDevis { UniteDevis(rawValue: uniteRaw) ?? .unite }
    var totalHT: Double { (quantite * prixHT * 100).rounded() / 100 }
}

extension Chantier {
    /// Sections du devis : les pièces (ordre de scan), puis les sections orphelines, puis les travaux généraux ("").
    var sectionsDevis: [String] {
        var noms: [String] = []
        for piece in pieces.sorted(by: { $0.dateScan < $1.dateScan }) where !noms.contains(piece.nom) {
            noms.append(piece.nom)
        }
        for ligne in lignesDevis.sorted(by: { $0.ordre < $1.ordre })
        where !ligne.section.isEmpty && !noms.contains(ligne.section) {
            noms.append(ligne.section)
        }
        noms.append("")
        return noms
    }

    func piece(nommee nom: String) -> Piece? {
        pieces.first { $0.nom == nom }
    }
}

struct MontantTVA: Hashable {
    var taux: Double
    var montant: Double
}

struct TotauxDevis {
    var ht: Double = 0
    var tva: [MontantTVA] = []
    var ttc: Double = 0

    init(lignes: [LigneDevis], franchise: Bool) {
        ht = lignes.reduce(0) { $0 + $1.totalHT }
        if !franchise {
            let parTaux = Dictionary(grouping: lignes, by: { $0.tauxTVA })
            tva = parTaux
                .map { taux, groupe in
                    let base = groupe.reduce(0) { $0 + $1.totalHT }
                    return MontantTVA(taux: taux, montant: (base * taux).rounded() / 100)
                }
                .filter { $0.taux > 0 }
                .sorted { $0.taux < $1.taux }
        }
        ttc = ht + tva.reduce(0) { $0 + $1.montant }
    }
}

// MARK: - Catalogue de départ

enum Catalogue {
    /// Ajoute quelques prestations d'exemple au premier lancement (prix à adapter).
    static func initialiserSiBesoin(_ contexte: ModelContext) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Reglages.catalogueInitialise) else { return }
        let exemples: [Prestation] = [
            Prestation(nom: "Peinture des murs, 2 couches", unite: .m2, prixHT: 25, base: .surfaceMursNette),
            Prestation(nom: "Peinture du plafond, 2 couches", unite: .m2, prixHT: 28, base: .surfacePlafond),
            Prestation(nom: "Préparation des murs (rebouchage, ponçage)", unite: .m2, prixHT: 10, base: .surfaceMursNette),
            Prestation(nom: "Pose de revêtement de sol", unite: .m2, prixHT: 35, base: .surfaceSol),
            Prestation(nom: "Ragréage du sol", unite: .m2, prixHT: 18, base: .surfaceSol),
            Prestation(nom: "Fourniture et pose de plinthes", unite: .ml, prixHT: 14, base: .plinthes),
            Prestation(nom: "Protection et nettoyage du chantier", unite: .forfait, prixHT: 150, base: .manuelle),
        ]
        exemples.forEach { contexte.insert($0) }
        d.set(true, forKey: Reglages.catalogueInitialise)
    }

    /// Ajoute les travaux par pièce (électricité, plomberie…) et range le catalogue existant.
    static func completerSiBesoin(_ contexte: ModelContext) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Reglages.catalogueTravaux) else { return }
        let existantes = (try? contexte.fetch(FetchDescriptor<Prestation>())) ?? []
        for prestation in existantes where prestation.categorieRaw.isEmpty {
            prestation.categorieRaw = CategorieTravaux.deviner(prestation.nom).rawValue
        }
        let noms = Set(existantes.map { $0.nom.lowercased() })
        for modele in travauxDeBase where !noms.contains(modele.nom.lowercased()) {
            contexte.insert(Prestation(nom: modele.nom, unite: modele.unite, prixHT: modele.prix,
                                       base: modele.base, categorie: modele.categorie))
        }
        d.set(true, forKey: Reglages.catalogueTravaux)
    }

    struct ModelePrestation {
        var nom: String
        var unite: UniteDevis
        var prix: Double
        var base: BaseQuantite = .manuelle
        var categorie: CategorieTravaux
    }

    /// Prix d'exemple, à adapter dans Réglages > Catalogue.
    static let travauxDeBase: [ModelePrestation] = [
        // Électricité
        ModelePrestation(nom: "Création de saignée dans mur pour passage de gaine", unite: .ml, prix: 25, categorie: .electricite),
        ModelePrestation(nom: "Fourniture et pose de gaine ICTA avec câble", unite: .ml, prix: 9, categorie: .electricite),
        ModelePrestation(nom: "Rebouchage de saignée", unite: .ml, prix: 10, categorie: .electricite),
        ModelePrestation(nom: "Création d'une prise de courant 16 A", unite: .unite, prix: 75, categorie: .electricite),
        ModelePrestation(nom: "Création d'une sortie de câble pour radiateur", unite: .unite, prix: 80, categorie: .electricite),
        ModelePrestation(nom: "Création d'un point lumineux avec interrupteur", unite: .unite, prix: 110, categorie: .electricite),
        ModelePrestation(nom: "Création d'un circuit au tableau électrique", unite: .unite, prix: 65, categorie: .electricite),
        // Chauffage
        ModelePrestation(nom: "Pose d'un radiateur électrique", unite: .unite, prix: 90, categorie: .chauffage),
        ModelePrestation(nom: "Fourniture d'un radiateur électrique", unite: .unite, prix: 350, categorie: .chauffage),
        // Plomberie
        ModelePrestation(nom: "Création d'une alimentation eau froide et eau chaude", unite: .unite, prix: 150, categorie: .plomberie),
        ModelePrestation(nom: "Création d'une évacuation PVC", unite: .unite, prix: 120, categorie: .plomberie),
        ModelePrestation(nom: "Pose d'un lavabo ou d'une vasque", unite: .unite, prix: 180, categorie: .plomberie),
        ModelePrestation(nom: "Pose d'un WC", unite: .unite, prix: 220, categorie: .plomberie),
        ModelePrestation(nom: "Dépose d'une baignoire et de son habillage", unite: .unite, prix: 250, categorie: .plomberie),
        ModelePrestation(nom: "Adaptation de l'évacuation pour receveur", unite: .unite, prix: 180, categorie: .plomberie),
        ModelePrestation(nom: "Fourniture et pose d'un receveur de douche extra-plat", unite: .unite, prix: 450, categorie: .plomberie),
        ModelePrestation(nom: "Fourniture et pose d'une paroi de douche", unite: .unite, prix: 400, categorie: .plomberie),
        ModelePrestation(nom: "Fourniture et pose d'une colonne de douche avec mitigeur", unite: .unite, prix: 280, categorie: .plomberie),
        ModelePrestation(nom: "Système d'étanchéité sous carrelage (SPEC)", unite: .m2, prix: 35, categorie: .plomberie),
        ModelePrestation(nom: "Pose de faïence murale", unite: .m2, prix: 55, categorie: .sols),
        // Démolition, maçonnerie
        ModelePrestation(nom: "Dépose de cloison", unite: .m2, prix: 30, categorie: .demolition),
        ModelePrestation(nom: "Montage de cloison en plaques de plâtre", unite: .m2, prix: 45, categorie: .demolition),
        ModelePrestation(nom: "Création d'une ouverture dans une cloison", unite: .unite, prix: 450, categorie: .demolition),
        ModelePrestation(nom: "Évacuation des gravats", unite: .forfait, prix: 200, categorie: .demolition),
        // Sols
        ModelePrestation(nom: "Dépose de revêtement de sol", unite: .m2, prix: 10, base: .surfaceSol, categorie: .sols),
        ModelePrestation(nom: "Pose de carrelage au sol", unite: .m2, prix: 45, base: .surfaceSol, categorie: .sols),
        ModelePrestation(nom: "Pose de parquet flottant", unite: .m2, prix: 30, base: .surfaceSol, categorie: .sols),
        // Peinture
        ModelePrestation(nom: "Peinture des portes (2 faces)", unite: .unite, prix: 60, base: .portes, categorie: .peinture),
        // Menuiserie
        ModelePrestation(nom: "Pose d'un bloc-porte", unite: .unite, prix: 250, categorie: .menuiserie),
        // Divers
        ModelePrestation(nom: "Main d'œuvre", unite: .heure, prix: 45, categorie: .divers),
    ]

    static func numeroSuivant() -> String {
        let d = UserDefaults.standard
        let numero = max(d.integer(forKey: Reglages.prochainNumero), 1)
        d.set(numero + 1, forKey: Reglages.prochainNumero)
        let annee = Calendar.current.component(.year, from: .now)
        return "D-\(annee)-" + String(format: "%03d", numero)
    }
}

extension Double {
    /// 1 234,56 €
    var enEuros: String { formatted(.currency(code: "EUR")) }

    /// 10 % (le nombre est un pourcentage : 10 = 10 %)
    var enPourcentage: String {
        (self / 100).formatted(.percent.precision(.fractionLength(0...1)))
    }

    /// 12,5 (au plus 2 décimales)
    var enQuantite: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }
}
