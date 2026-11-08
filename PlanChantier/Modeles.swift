import Foundation
import SwiftData

/// Un chantier regroupe les pièces relevées chez un client.
@Model
final class Chantier {
    var nom: String
    var client: String
    var adresse: String
    var dateCreation: Date
    var favori: Bool = false
    var archive: Bool = false
    var descriptionChantier: String = ""
    /// Photos générales du chantier (dossier Documents/Photos).
    var photos: [String] = []
    /// Position de l'adresse, calculée automatiquement.
    var latitude: Double?
    var longitude: Double?

    @Relationship(deleteRule: .cascade, inverse: \Piece.chantier)
    var pieces: [Piece] = []

    @Relationship(deleteRule: .cascade, inverse: \LigneDevis.chantier)
    var lignesDevis: [LigneDevis] = []

    /// Numéro attribué au premier ajout d'une ligne de devis (ex. D-2026-001).
    var numeroDevis: String = ""
    var dateDevis: Date?

    init(nom: String, client: String = "", adresse: String = "", dateCreation: Date = .now) {
        self.nom = nom
        self.client = client
        self.adresse = adresse
        self.dateCreation = dateCreation
    }

    var surfaceTotale: Double {
        pieces.reduce(0) { $0 + $1.surfaceSol }
    }

    /// Supprime les fichiers du chantier (scans et photos).
    func supprimerFichiers() {
        pieces.forEach { $0.supprimerFichiers() }
        photos.forEach { StockagePhotos.supprimer($0) }
    }

    /// Crée une copie complète du chantier : pièces, photos et lignes de devis (sans numéro de devis).
    @discardableResult
    func dupliquer(dans contexte: ModelContext) -> Chantier {
        let copie = Chantier(nom: nom + " (copie)", client: client, adresse: adresse)
        copie.descriptionChantier = descriptionChantier
        copie.latitude = latitude
        copie.longitude = longitude
        copie.photos = photos.compactMap { StockagePhotos.copier($0) }
        contexte.insert(copie)

        var sessions: [UUID: UUID] = [:]
        for piece in pieces {
            let nouvelle = Piece(nom: piece.nom,
                                 dateScan: piece.dateScan,
                                 surfaceSol: piece.surfaceSol,
                                 perimetre: piece.perimetre,
                                 hauteur: piece.hauteur,
                                 segments: piece.segments,
                                 fichierScan: StockageScans.copier(piece.fichierScan))
            nouvelle.notes = piece.notes
            nouvelle.photos = piece.photos.compactMap { StockagePhotos.copier($0) }
            if let session = piece.sessionScan {
                let nouvelleSession = sessions[session] ?? UUID()
                sessions[session] = nouvelleSession
                nouvelle.sessionScan = nouvelleSession
            }
            contexte.insert(nouvelle)
            copie.pieces.append(nouvelle)
        }
        for ligne in lignesDevis {
            let nouvelle = LigneDevis(designation: ligne.designation, unite: ligne.unite, quantite: ligne.quantite,
                                      prixHT: ligne.prixHT, tauxTVA: ligne.tauxTVA, ordre: ligne.ordre)
            contexte.insert(nouvelle)
            copie.lignesDevis.append(nouvelle)
        }
        return copie
    }

    /// Groupes d'au moins 2 pièces scannées à la suite (un groupe = un plan d'étage).
    var etages: [[Piece]] {
        Dictionary(grouping: pieces.filter { $0.sessionScan != nil }, by: { $0.sessionScan })
            .values
            .filter { $0.count >= 2 }
            .map { $0.sorted { $0.dateScan < $1.dateScan } }
            .sorted { ($0.first?.dateScan ?? .now) < ($1.first?.dateScan ?? .now) }
    }
}

/// Une pièce scannée, avec son plan 2D et ses mesures (en mètres).
@Model
final class Piece {
    var nom: String
    var dateScan: Date
    var surfaceSol: Double
    var perimetre: Double
    var hauteur: Double
    var segmentsData: Data
    /// Nom du fichier contenant le scan brut (dossier Documents/Scans).
    var fichierScan: String?
    var notes: String = ""
    /// Noms des fichiers photo (dossier Documents/Photos).
    var photos: [String] = []
    /// Pièces scannées à la suite dans la même session : elles partagent le même repère
    /// et peuvent être assemblées en plan d'étage.
    var sessionScan: UUID? = nil
    var chantier: Chantier?

    init(nom: String,
         dateScan: Date = .now,
         surfaceSol: Double,
         perimetre: Double,
         hauteur: Double,
         segments: [SegmentPlan],
         fichierScan: String?) {
        self.nom = nom
        self.dateScan = dateScan
        self.surfaceSol = surfaceSol
        self.perimetre = perimetre
        self.hauteur = hauteur
        self.segmentsData = (try? JSONEncoder().encode(segments)) ?? Data()
        self.fichierScan = fichierScan
    }

    var segments: [SegmentPlan] {
        (try? JSONDecoder().decode([SegmentPlan].self, from: segmentsData)) ?? []
    }

    var murs: [SegmentPlan] { segments.filter { $0.genre == .mur } }

    var surfaceMursBrute: Double { perimetre * hauteur }

    /// Surface des portes et fenêtres. Pour les anciens scans sans hauteur,
    /// on prend 2,04 m pour une porte et 1,25 m pour une fenêtre.
    var surfaceOuvertures: Double {
        segments
            .filter { $0.genre == .porte || $0.genre == .fenetre }
            .reduce(0) { $0 + $1.longueur * ($1.hauteur ?? ($1.genre == .porte ? 2.04 : 1.25)) }
    }

    var surfaceMursNette: Double { max(surfaceMursBrute - surfaceOuvertures, 0) }

    /// Périmètre moins la largeur des portes et ouvertures.
    var lineairePlinthes: Double {
        let passages = segments
            .filter { $0.genre == .porte || $0.genre == .ouverture }
            .reduce(0) { $0 + $1.longueur }
        return max(perimetre - passages, 0)
    }

    /// Supprime les fichiers liés à la pièce (scan brut et photos).
    func supprimerFichiers() {
        StockageScans.supprimer(fichierScan)
        photos.forEach { StockagePhotos.supprimer($0) }
    }
}

/// Un trait du plan vu de dessus : mur, porte, fenêtre ou ouverture.
struct SegmentPlan: Codable, Hashable {
    enum Genre: String, Codable {
        case mur, porte, fenetre, ouverture
    }

    var genre: Genre
    var x1: Double
    var y1: Double
    var x2: Double
    var y2: Double
    /// Hauteur de l'élément (portes, fenêtres), en mètres.
    var hauteur: Double? = nil

    var longueur: Double { hypot(x2 - x1, y2 - y1) }
}

extension Double {
    /// 3,42 m
    var enMetres: String {
        formatted(.number.precision(.fractionLength(2))) + " m"
    }

    /// 12,5 m²
    var enMetresCarres: String {
        formatted(.number.precision(.fractionLength(2))) + " m²"
    }
}
