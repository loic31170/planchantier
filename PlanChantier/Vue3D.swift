import SwiftUI
import SceneKit
import RoomPlan

// MARK: - Modèle 3D des pièces scannées

@MainActor
enum Modele3D {
    enum Erreur: LocalizedError {
        case scanAbsent
        var errorDescription: String? {
            "Le scan 3D d'origine n'est pas disponible pour ce plan. Refais un scan de la pièce pour obtenir la vue 3D."
        }
    }

    static func capture(_ piece: Piece) -> CapturedRoom? {
        guard let fichier = piece.fichierScan,
              let donnees = try? Data(contentsOf: StockageScans.dossier.appending(path: fichier)) else { return nil }
        return try? JSONDecoder().decode(CapturedRoom.self, from: donnees)
    }

    static func nomFichier(_ nom: String) -> String {
        let propre = nom.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
        return propre.isEmpty ? "Modèle 3D" : propre
    }

    /// Exporte les pièces scannées (murs, portes, fenêtres, éléments reconnus) en USDZ.
    static func exporterSalles(_ pieces: [Piece], nom: String) async throws -> URL {
        let salles = pieces.compactMap(capture)
        guard !salles.isEmpty else { throw Erreur.scanAbsent }
        let dossier = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let url = dossier.appending(path: "\(nomFichier(nom)).usdz")

        if salles.count == 1 {
            try salles[0].export(to: url, exportOptions: .parametric)
            return url
        }
        // Plusieurs pièces scannées à la suite : on les assemble en un seul bâtiment.
        if let structure = try? await StructureBuilder(options: [.beautifyObjects]).capturedStructure(from: salles) {
            try structure.export(to: url, exportOptions: .parametric)
            return url
        }
        // Repli : chaque pièce exportée puis réunie dans une même scène (même repère de scan).
        let scene = SCNScene()
        for (index, salle) in salles.enumerated() {
            let fichier = dossier.appending(path: "piece-\(index).usdz")
            try salle.export(to: fichier, exportOptions: .parametric)
            let sousScene = try SCNScene(url: fichier, options: nil)
            let noeud = SCNNode()
            sousScene.rootNode.childNodes.forEach { noeud.addChildNode($0) }
            scene.rootNode.addChildNode(noeud)
        }
        guard scene.write(to: url, options: nil, delegate: nil, progressHandler: nil) else { throw Erreur.scanAbsent }
        return url
    }
}

/// Meuble posé dans une vue 3D (enregistré avec le chantier).
struct MeublePlace: Codable, Identifiable {
    var id = UUID()
    var modele: String
    var x: Float
    var z: Float
    var angle: Float
}

extension Chantier {
    func meublesPlaces(cle: String) -> [MeublePlace] {
        guard let meubles3D,
              let tout = try? JSONDecoder().decode([String: [MeublePlace]].self, from: meubles3D) else { return [] }
        return tout[cle] ?? []
    }

    func enregistrerMeubles(_ meubles: [MeublePlace], cle: String) {
        var tout: [String: [MeublePlace]] = [:]
        if let meubles3D, let existant = try? JSONDecoder().decode([String: [MeublePlace]].self, from: meubles3D) {
            tout = existant
        }
        tout[cle] = meubles
        meubles3D = try? JSONEncoder().encode(tout)
    }
}

final class NoeudMeuble: SCNNode {
    var identifiant = UUID()
    var modeleID = ""
}

// MARK: - Scène

@MainActor
@Observable
final class Scene3D {
    enum Etat {
        case chargement
        case pret
        case erreur(String)
    }

    var etat: Etat = .chargement
    var selection: NoeudMeuble?
    var nombreMeubles = 0

    let scene = SCNScene()
    let racineMeubles = SCNNode()
    let camera = SCNNode()
    @ObservationIgnored var centre = SCNVector3Zero
    @ObservationIgnored var sol: Float = 0
    @ObservationIgnored var urlSalles: URL?
    @ObservationIgnored weak var chantier: Chantier?
    @ObservationIgnored var cle = ""

    func charger(pieces: [Piece], nom: String) async {
        guard case .chargement = etat else { return }
        chantier = pieces.first?.chantier
        let triees = pieces.sorted { $0.dateScan < $1.dateScan }
        cle = triees.first?.sessionScan?.uuidString ?? triees.first?.fichierScan ?? nom
        do {
            let url = try await Modele3D.exporterSalles(triees, nom: nom)
            urlSalles = url
            let salles = try SCNScene(url: url, options: nil)
            let batiment = SCNNode()
            salles.rootNode.childNodes.forEach { batiment.addChildNode($0) }
            scene.rootNode.addChildNode(batiment)

            let (mini, maxi) = Scene3D.limites(batiment)
            sol = mini.y
            centre = SCNVector3((mini.x + maxi.x) / 2, sol, (mini.z + maxi.z) / 2)
            let rayon = max(maxi.x - mini.x, maxi.z - mini.z, 2)

            let objectif = SCNCamera()
            objectif.zNear = 0.05
            objectif.zFar = 300
            objectif.fieldOfView = 55
            camera.camera = objectif
            camera.position = SCNVector3(centre.x, sol + rayon * 1.1 + 1, centre.z + rayon * 1.1)
            camera.look(at: SCNVector3(centre.x, sol + 0.8, centre.z))
            scene.rootNode.addChildNode(camera)

            let ambiance = SCNNode()
            ambiance.light = SCNLight()
            ambiance.light?.type = .ambient
            ambiance.light?.intensity = 600
            scene.rootNode.addChildNode(ambiance)
            let soleil = SCNNode()
            soleil.light = SCNLight()
            soleil.light?.type = .directional
            soleil.light?.intensity = 900
            soleil.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
            scene.rootNode.addChildNode(soleil)

            scene.rootNode.addChildNode(racineMeubles)
            for place in chantier?.meublesPlaces(cle: cle) ?? [] {
                guard let modele = Bibliotheque3D.modele(place.modele) else { continue }
                let noeud = creer(modele)
                noeud.identifiant = place.id
                noeud.position = SCNVector3(place.x, sol, place.z)
                noeud.eulerAngles.y = place.angle
                racineMeubles.addChildNode(noeud)
            }
            nombreMeubles = racineMeubles.childNodes.count
            etat = .pret
        } catch {
            etat = .erreur(error.localizedDescription)
        }
    }

    /// Boîte englobante (repère de la scène) de toute la géométrie sous un nœud.
    static func limites(_ racine: SCNNode) -> (SCNVector3, SCNVector3) {
        var mini = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxi = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        var trouve = false
        racine.enumerateHierarchy { noeud, _ in
            guard noeud.geometry != nil else { return }
            let (a, b) = noeud.boundingBox
            for x in [a.x, b.x] { for y in [a.y, b.y] { for z in [a.z, b.z] {
                let p = noeud.convertPosition(SCNVector3(x, y, z), to: nil)
                mini = SCNVector3(min(mini.x, p.x), min(mini.y, p.y), min(mini.z, p.z))
                maxi = SCNVector3(max(maxi.x, p.x), max(maxi.y, p.y), max(maxi.z, p.z))
                trouve = true
            } } }
        }
        return trouve ? (mini, maxi) : (SCNVector3Zero, SCNVector3Zero)
    }

    private func creer(_ modele: ModeleMeuble) -> NoeudMeuble {
        let noeud = NoeudMeuble()
        noeud.modeleID = modele.id
        noeud.name = modele.nom
        noeud.addChildNode(modele.construire())
        return noeud
    }

    // MARK: Actions

    func ajouter(_ modele: ModeleMeuble) {
        let noeud = creer(modele)
        noeud.position = SCNVector3(centre.x, sol, centre.z)
        racineMeubles.addChildNode(noeud)
        selectionner(noeud)
        enregistrer()
    }

    func selectionner(_ noeud: NoeudMeuble?) {
        if let selection { Scene3D.surligner(selection, actif: false) }
        selection = noeud
        if let noeud { Scene3D.surligner(noeud, actif: true) }
    }

    func tourner(_ angle: Float) {
        guard let selection else { return }
        selection.eulerAngles.y += angle
        enregistrer()
    }

    func dupliquer() {
        guard let selection, let modele = Bibliotheque3D.modele(selection.modeleID) else { return }
        let copie = creer(modele)
        copie.position = SCNVector3(selection.position.x + 0.3, sol, selection.position.z + 0.3)
        copie.eulerAngles = selection.eulerAngles
        racineMeubles.addChildNode(copie)
        selectionner(copie)
        enregistrer()
    }

    func supprimer() {
        guard let selection else { return }
        selection.removeFromParentNode()
        self.selection = nil
        enregistrer()
    }

    func deplacer(_ noeud: NoeudMeuble, vers point: SCNVector3) {
        noeud.position = SCNVector3(point.x, sol, point.z)
    }

    func enregistrer() {
        let meubles = racineMeubles.childNodes.compactMap { $0 as? NoeudMeuble }.map {
            MeublePlace(id: $0.identifiant, modele: $0.modeleID, x: $0.position.x, z: $0.position.z, angle: $0.eulerAngles.y)
        }
        nombreMeubles = meubles.count
        chantier?.enregistrerMeubles(meubles, cle: cle)
    }

    static func surligner(_ noeud: SCNNode, actif: Bool) {
        noeud.enumerateHierarchy { enfant, _ in
            enfant.geometry?.materials.forEach {
                $0.emission.contents = actif ? UIColor(red: 0.2, green: 0.55, blue: 0.45, alpha: 1) : UIColor.black
                $0.emission.intensity = actif ? 0.45 : 0
            }
        }
    }

    // MARK: Export

    /// Exporte la scène (pièces + meubles) en USDZ.
    func exporter(nom: String, avecMeubles: Bool) -> URL? {
        if !avecMeubles { return urlSalles }
        let dejaSelectionne = selection
        selectionner(nil)
        defer { selectionner(dejaSelectionne) }
        let dossier = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let url = dossier.appending(path: "\(Modele3D.nomFichier(nom)) aménagé.usdz")
        camera.isHidden = true
        defer { camera.isHidden = false }
        return scene.write(to: url, options: nil, delegate: nil, progressHandler: nil) ? url : nil
    }

    /// Point du sol sous le doigt.
    func pointSol(_ point: CGPoint, dans vue: SCNView) -> SCNVector3? {
        let a = vue.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
        let b = vue.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
        let dy = b.y - a.y
        guard abs(dy) > 0.00001 else { return nil }
        let t = (sol - a.y) / dy
        guard t > 0 else { return nil }
        return SCNVector3(a.x + (b.x - a.x) * t, sol, a.z + (b.z - a.z) * t)
    }

    func meuble(en point: CGPoint, dans vue: SCNView) -> NoeudMeuble? {
        let resultats = vue.hitTest(point, options: [
            SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue,
            SCNHitTestOption.rootNode: racineMeubles
        ])
        for resultat in resultats {
            var noeud: SCNNode? = resultat.node
            while let courant = noeud {
                if let meuble = courant as? NoeudMeuble { return meuble }
                noeud = courant.parent
            }
        }
        return nil
    }
}

// MARK: - Vue SceneKit

private struct VueScene: UIViewRepresentable {
    let scene3D: Scene3D

    func makeCoordinator() -> Coordinateur { Coordinateur(scene3D: scene3D) }

    func makeUIView(context: Context) -> SCNView {
        let vue = SCNView()
        vue.scene = scene3D.scene
        vue.pointOfView = scene3D.camera
        vue.allowsCameraControl = true
        vue.defaultCameraController.interactionMode = .orbitTurntable
        vue.defaultCameraController.target = scene3D.centre
        vue.defaultCameraController.maximumVerticalAngle = 89
        vue.antialiasingMode = .multisampling4X
        vue.backgroundColor = .secondarySystemBackground

        let glisser = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinateur.glisser(_:)))
        glisser.maximumNumberOfTouches = 1
        glisser.delegate = context.coordinator
        let toucher = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinateur.toucher(_:)))
        // La caméra ne tourne que si le doigt n'a pas attrapé un meuble.
        for geste in vue.gestureRecognizers ?? [] where geste is UIPanGestureRecognizer {
            geste.require(toFail: glisser)
        }
        vue.addGestureRecognizer(glisser)
        vue.addGestureRecognizer(toucher)
        context.coordinator.vue = vue
        return vue
    }

    func updateUIView(_ vue: SCNView, context: Context) {}

    @MainActor
    final class Coordinateur: NSObject, UIGestureRecognizerDelegate {
        let scene3D: Scene3D
        weak var vue: SCNView?
        private var meubleTenu: NoeudMeuble?
        private var decalage = SCNVector3Zero

        init(scene3D: Scene3D) {
            self.scene3D = scene3D
        }

        func gestureRecognizerShouldBegin(_ geste: UIGestureRecognizer) -> Bool {
            guard let vue else { return false }
            return scene3D.meuble(en: geste.location(in: vue), dans: vue) != nil
        }

        @objc func toucher(_ geste: UITapGestureRecognizer) {
            guard let vue else { return }
            scene3D.selectionner(scene3D.meuble(en: geste.location(in: vue), dans: vue))
        }

        @objc func glisser(_ geste: UIPanGestureRecognizer) {
            guard let vue else { return }
            let point = geste.location(in: vue)
            switch geste.state {
            case .began:
                meubleTenu = scene3D.meuble(en: point, dans: vue)
                if let meubleTenu {
                    scene3D.selectionner(meubleTenu)
                    if let sous = scene3D.pointSol(point, dans: vue) {
                        decalage = SCNVector3(meubleTenu.position.x - sous.x, 0, meubleTenu.position.z - sous.z)
                    }
                }
            case .changed:
                if let meubleTenu, let sous = scene3D.pointSol(point, dans: vue) {
                    scene3D.deplacer(meubleTenu, vers: SCNVector3(sous.x + decalage.x, 0, sous.z + decalage.z))
                }
            default:
                if meubleTenu != nil { scene3D.enregistrer() }
                meubleTenu = nil
            }
        }
    }
}

// MARK: - Écran 3D

struct Vue3DView: View {
    let titre: String
    let pieces: [Piece]

    @Environment(\.modelContext) private var contexte
    @State private var scene3D = Scene3D()
    @State private var bibliothequeOuverte = false
    @State private var apercuAR: URL?
    @State private var partage: DocumentPDF?
    @State private var erreurExport = false

    var body: some View {
        ZStack {
            switch scene3D.etat {
            case .chargement:
                ProgressView("Construction du modèle 3D…")
            case .erreur(let texte):
                ContentUnavailableView("Vue 3D indisponible", systemImage: "cube.transparent", description: Text(texte))
            case .pret:
                VueScene(scene3D: scene3D)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .bottom) { barreOutils }
            }
        }
        .navigationTitle(titre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        apercuAR = scene3D.exporter(nom: titre, avecMeubles: true)
                    } label: {
                        Label("Voir en réalité augmentée", systemImage: "arkit")
                    }
                    Button {
                        exporter(avecMeubles: true)
                    } label: {
                        Label("Exporter avec les meubles (USDZ)", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        exporter(avecMeubles: false)
                    } label: {
                        Label("Exporter les pièces seules (USDZ)", systemImage: "cube")
                    }
                } label: {
                    Label("Exporter", systemImage: "square.and.arrow.up")
                }
                .disabled(!estPret)
            }
        }
        .task { await scene3D.charger(pieces: pieces, nom: titre) }
        .sheet(isPresented: $bibliothequeOuverte) {
            BibliothequeMeublesView { modele in scene3D.ajouter(modele) }
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $partage) { document in
            FeuillePartage(elements: [document.url])
        }
        .quickLookPreview($apercuAR)
        .alert("L'export 3D a échoué", isPresented: $erreurExport) {
            Button("OK", role: .cancel) {}
        }
    }

    private var estPret: Bool {
        if case .pret = scene3D.etat { return true }
        return false
    }

    private var barreOutils: some View {
        VStack(spacing: 10) {
            if let selection = scene3D.selection {
                HStack(spacing: 18) {
                    Text(selection.name ?? "Meuble")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    outil("rotate.left") { scene3D.tourner(.pi / 12) }
                    outil("rotate.right") { scene3D.tourner(-.pi / 12) }
                    outil("arrow.clockwise") { scene3D.tourner(-.pi / 2) }
                    outil("plus.square.on.square") { scene3D.dupliquer() }
                    outil("trash", couleur: .red) { scene3D.supprimer() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else if scene3D.nombreMeubles > 0 {
                Text("Touche un meuble pour le sélectionner, fais-le glisser pour le déplacer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
            }
            Button {
                bibliothequeOuverte = true
            } label: {
                Label("Ajouter un meuble", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding()
    }

    private func outil(_ symbole: String, couleur: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbole)
                .font(.title3)
                .foregroundStyle(couleur)
        }
    }

    private func exporter(avecMeubles: Bool) {
        guard let url = scene3D.exporter(nom: titre, avecMeubles: avecMeubles) else {
            erreurExport = true
            return
        }
        if let chantier = pieces.first?.chantier {
            let nom = avecMeubles ? "Modèle 3D \(titre) aménagé" : "Modèle 3D \(titre)"
            _ = chantier.archiver(url, nom: nom, genre: .modele3D, contexte: contexte)
        }
        partage = DocumentPDF(url: url)
    }
}
