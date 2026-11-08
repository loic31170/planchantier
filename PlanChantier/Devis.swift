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

    init(nom: String, unite: UniteDevis, prixHT: Double, tauxTVA: Double = 10, base: BaseQuantite) {
        self.nom = nom
        self.uniteRaw = unite.rawValue
        self.prixHT = prixHT
        self.tauxTVA = tauxTVA
        self.baseRaw = base.rawValue
    }

    var unite: UniteDevis { UniteDevis(rawValue: uniteRaw) ?? .unite }
    var base: BaseQuantite { BaseQuantite(rawValue: baseRaw) ?? .manuelle }
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
