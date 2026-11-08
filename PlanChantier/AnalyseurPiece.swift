import Foundation
import RoomPlan
import simd

/// Ce que l'on retient d'un scan RoomPlan.
struct ResultatAnalyse {
    var segments: [SegmentPlan]
    var surfaceSol: Double
    var perimetre: Double
    var hauteur: Double
}

/// Convertit un scan RoomPlan (3D) en plan 2D et en métrés.
enum AnalyseurPiece {

    static func analyser(_ piece: CapturedRoom) -> ResultatAnalyse {
        var segments: [SegmentPlan] = []
        segments += piece.walls.map { segment(de: $0, genre: .mur) }
        segments += piece.openings.map { segment(de: $0, genre: .ouverture) }
        segments += piece.doors.map { segment(de: $0, genre: .porte) }
        segments += piece.windows.map { segment(de: $0, genre: .fenetre) }

        let perimetre = piece.walls.reduce(0.0) { $0 + Double($1.dimensions.x) }
        let hauteur = Double(piece.walls.map { $0.dimensions.y }.max() ?? 0)

        var surface = piece.floors.reduce(0.0) { $0 + aire(du: $1) }
        if surface <= 0 {
            surface = aireDepuisMurs(segments.filter { $0.genre == .mur })
        }

        return ResultatAnalyse(segments: segments,
                               surfaceSol: surface,
                               perimetre: perimetre,
                               hauteur: hauteur)
    }

    /// Projette une surface verticale (mur, porte…) sur le sol : un trait vu de dessus.
    private static func segment(de surface: CapturedRoom.Surface, genre: SegmentPlan.Genre) -> SegmentPlan {
        let t = surface.transform
        let centre = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        var direction = SIMD3<Float>(t.columns.0.x, 0, t.columns.0.z)
        if simd_length(direction) > 0 {
            direction = simd_normalize(direction)
        }
        let demiLongueur = surface.dimensions.x / 2
        let a = centre - direction * demiLongueur
        let b = centre + direction * demiLongueur
        return SegmentPlan(genre: genre,
                           x1: Double(a.x), y1: Double(a.z),
                           x2: Double(b.x), y2: Double(b.z),
                           hauteur: Double(surface.dimensions.y))
    }

    /// Aire d'un sol à partir de ses coins (polygone plan en 3D).
    private static func aire(du sol: CapturedRoom.Surface) -> Double {
        let coins = sol.polygonCorners
        guard coins.count >= 3 else {
            return Double(sol.dimensions.x * sol.dimensions.y)
        }
        var somme = SIMD3<Float>(repeating: 0)
        for i in 0..<coins.count {
            somme += simd_cross(coins[i], coins[(i + 1) % coins.count])
        }
        return Double(simd_length(somme)) / 2
    }

    /// Solution de repli : aire du polygone formé par les murs, triés autour de leur centre.
    private static func aireDepuisMurs(_ murs: [SegmentPlan]) -> Double {
        guard murs.count >= 3 else { return 0 }
        let points = murs.map { (x: ($0.x1 + $0.x2) / 2, y: ($0.y1 + $0.y2) / 2) }
        let cx = points.map { $0.x }.reduce(0, +) / Double(points.count)
        let cy = points.map { $0.y }.reduce(0, +) / Double(points.count)
        let coins = murs
            .flatMap { [(x: $0.x1, y: $0.y1), (x: $0.x2, y: $0.y2)] }
            .sorted { atan2($0.y - cy, $0.x - cx) < atan2($1.y - cy, $1.x - cx) }
        var somme = 0.0
        for i in 0..<coins.count {
            let p = coins[i], q = coins[(i + 1) % coins.count]
            somme += p.x * q.y - q.x * p.y
        }
        return abs(somme) / 2
    }
}

/// Enregistre le scan brut sur l'appareil, pour pouvoir le réutiliser plus tard (3D, export).
enum StockageScans {
    static var dossier: URL {
        let url = URL.documentsDirectory.appending(path: "Scans", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func enregistrer(_ piece: CapturedRoom) -> String? {
        let nomFichier = UUID().uuidString + ".json"
        do {
            let donnees = try JSONEncoder().encode(piece)
            try donnees.write(to: dossier.appending(path: nomFichier))
            return nomFichier
        } catch {
            return nil
        }
    }

    static func copier(_ nomFichier: String?) -> String? {
        guard let nomFichier else { return nil }
        let nouveau = UUID().uuidString + ".json"
        do {
            try FileManager.default.copyItem(at: dossier.appending(path: nomFichier), to: dossier.appending(path: nouveau))
            return nouveau
        } catch {
            return nil
        }
    }

    static func supprimer(_ nomFichier: String?) {
        guard let nomFichier else { return }
        try? FileManager.default.removeItem(at: dossier.appending(path: nomFichier))
    }
}
