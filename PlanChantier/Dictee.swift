import SwiftUI
import SwiftData
import Speech
import AVFoundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Micro et transcription (sur l'iPhone)

@MainActor
@Observable
final class Dictaphone {
    var texte = ""
    var enEcoute = false
    var erreur: String?

    private let reconnaisseur = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private let moteur = AVAudioEngine()
    @ObservationIgnored private var requete: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var tache: SFSpeechRecognitionTask?
    @ObservationIgnored private var debut = ""

    func basculer() async {
        if enEcoute { arreter() } else { await demarrer() }
    }

    func demarrer() async {
        erreur = nil
        let parole = await withCheckedContinuation { suite in
            SFSpeechRecognizer.requestAuthorization { suite.resume(returning: $0 == .authorized) }
        }
        guard parole else {
            erreur = "Autorise la reconnaissance vocale dans Réglages > PlanChantier."
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            erreur = "Autorise le micro dans Réglages > PlanChantier."
            return
        }
        guard let reconnaisseur, reconnaisseur.isAvailable else {
            erreur = "La reconnaissance vocale en français n'est pas disponible pour le moment."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let requete = SFSpeechAudioBufferRecognitionRequest()
            requete.shouldReportPartialResults = true
            requete.addsPunctuation = true
            if reconnaisseur.supportsOnDeviceRecognition { requete.requiresOnDeviceRecognition = true }

            Dictaphone.brancher(moteur.inputNode, sur: requete)
            moteur.prepare()
            try moteur.start()

            debut = texte.isEmpty ? "" : texte + " "
            self.requete = requete
            tache = Dictaphone.ecouter(reconnaisseur, requete: requete) { [weak self] transcription, fini in
                guard let self else { return }
                if let transcription { self.texte = self.debut + transcription }
                if fini { self.arreter() }
            }
            enEcoute = true
        } catch {
            erreur = error.localizedDescription
            arreter()
        }
    }

    func arreter() {
        if moteur.isRunning {
            moteur.stop()
            moteur.inputNode.removeTap(onBus: 0)
        }
        requete?.endAudio()
        tache?.finish()
        requete = nil
        tache = nil
        enEcoute = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Envoie le son du micro à la reconnaissance (appelé hors du fil principal).
    nonisolated private static func brancher(_ entree: AVAudioInputNode, sur requete: SFSpeechAudioBufferRecognitionRequest) {
        let format = entree.outputFormat(forBus: 0)
        entree.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            requete.append(buffer)
        }
    }

    nonisolated private static func ecouter(_ reconnaisseur: SFSpeechRecognizer,
                                            requete: SFSpeechAudioBufferRecognitionRequest,
                                            resultat: @escaping @MainActor (String?, Bool) -> Void) -> SFSpeechRecognitionTask {
        reconnaisseur.recognitionTask(with: requete) { reponse, erreur in
            let texte = reponse?.bestTranscription.formattedString
            let fini = erreur != nil || reponse?.isFinal == true
            Task { @MainActor in resultat(texte, fini) }
        }
    }
}

// MARK: - Proposition de lignes

struct PropositionLigne: Identifiable {
    let id = UUID()
    var section: String
    var designation: String
    var unite: UniteDevis
    var quantite: Double
    var prix: Double
    var tva: Double
    var retenue = true
    /// Faux quand rien ne correspond dans le catalogue (prix à saisir).
    var reconnue = true
}

/// Travail compris dans la dictée, avant rapprochement avec le catalogue.
struct TravailCompris {
    var piece: String
    var prestation: String
    var ouvrage: String
    var description: String
    var quantite: Double
    var unite: String
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct DicteeIA {
    @Guide(description: "Chaque travail distinct dicté par l'artisan, dans l'ordre")
    var travaux: [TravailIA]
}

@available(iOS 26.0, *)
@Generable
struct TravailIA {
    @Guide(description: "Nom de la pièce concernée, recopié exactement depuis la liste des pièces, ou vide si travail général")
    var piece: String
    @Guide(description: "Nom exact de la prestation du catalogue qui correspond, ou vide si aucune ne correspond")
    var prestation: String
    @Guide(description: "Nom exact de l'ouvrage tout prêt qui correspond, ou vide")
    var ouvrage: String
    @Guide(description: "Description courte du travail, en français, telle que l'artisan l'a dite")
    var description: String
    @Guide(description: "Quantité dite par l'artisan (mètres, nombre, m²), ou 0 si elle n'est pas dite")
    var quantite: Double
    @Guide(description: "Unité de la quantité", .anyOf(["m2", "ml", "u", "h", "forfait"]))
    var unite: String
}
#endif

@MainActor
enum AnalyseDictee {
    static func analyser(_ texte: String, chantier: Chantier, catalogue: [Prestation]) async -> (lignes: [PropositionLigne], methode: String) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability,
               let travaux = try? await viaIA(texte, chantier: chantier, catalogue: catalogue), !travaux.isEmpty {
                return (convertir(travaux, chantier: chantier, catalogue: catalogue), "Analysé par l'IA d'Apple, sur ton iPhone.")
            }
        }
        #endif
        return (convertir(parMotsCles(texte, chantier: chantier), chantier: chantier, catalogue: catalogue),
                "Analysé par mots-clés (l'IA d'Apple n'est pas disponible sur cet iPhone).")
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func viaIA(_ texte: String, chantier: Chantier, catalogue: [Prestation]) async throws -> [TravailCompris] {
        let pieces = chantier.pieces.map(\.nom)
        let prestations = catalogue.prefix(150).map { "- \($0.nom) (\($0.unite.rawValue))" }.joined(separator: "\n")
        let ouvrages = Ouvrage.tous.map { "- \($0.nom)" }.joined(separator: "\n")
        let consignes = """
        Tu aides un artisan du bâtiment à préparer un devis à partir de ce qu'il dicte sur le chantier.
        Découpe la dictée en travaux distincts. Pour chaque travail :
        - la pièce, choisie dans cette liste : \(pieces.isEmpty ? "aucune" : pieces.joined(separator: ", ")) ;
        - si le travail correspond à un ouvrage tout prêt, son nom exact ;
        - sinon la prestation du catalogue la plus proche, nom exact ;
        - la quantité seulement si elle est dite.
        Une phrase peut contenir plusieurs travaux. N'invente aucun travail.

        Ouvrages tout prêts :
        \(ouvrages)

        Catalogue :
        \(prestations)
        """
        let session = LanguageModelSession(instructions: consignes)
        let reponse = try await session.respond(to: texte, generating: DicteeIA.self)
        return reponse.content.travaux.map {
            TravailCompris(piece: $0.piece, prestation: $0.prestation, ouvrage: $0.ouvrage,
                           description: $0.description, quantite: $0.quantite, unite: $0.unite)
        }
    }
    #endif

    // MARK: Mots-clés (secours)

    static func plier(_ texte: String) -> String {
        texte.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    private static let nombresEnLettres: [String: Double] = [
        "un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4, "cinq": 5, "six": 6, "sept": 7,
        "huit": 8, "neuf": 9, "dix": 10, "douze": 12, "quinze": 15, "vingt": 20,
    ]

    private static let ouvragesMotsCles: [(String, [String])] = [
        ("baignoire-douche", ["baignoire"]),
        ("radiateur", ["radiateur"]),
        ("prise", ["prise"]),
        ("lumiere", ["point lumineux", "lumiere", "luminaire", "plafonnier", "eclairage"]),
        ("lavabo", ["lavabo", "vasque"]),
        ("wc", ["wc", "toilette"]),
    ]

    private static let verbesCreation = ["cre", "install", "ajout", "mettre", "mets", "met ", "remplac", "aliment", "rajout", "pose", "poser", "tirer"]

    static func parMotsCles(_ texte: String, chantier: Chantier) -> [TravailCompris] {
        var morceaux = [plier(texte)]
        for coupure in [".", ";", "\n", ",", " puis ", " ensuite ", " et aussi ", " apres "] {
            morceaux = morceaux.flatMap { $0.components(separatedBy: coupure) }
        }
        let pieces = chantier.pieces.map { ($0.nom, plier($0.nom)) }
        var pieceCourante = ""
        var resultat: [TravailCompris] = []

        for morceau in morceaux {
            let m = morceau.trimmingCharacters(in: .whitespaces)
            guard !m.isEmpty else { continue }
            if let trouvee = pieces.first(where: { m.contains($0.1) }) { pieceCourante = trouvee.0 }

            let (quantite, unite) = quantiteDite(m)
            var ouvrage = ""
            if verbesCreation.contains(where: { m.contains($0) }) {
                ouvrage = ouvragesMotsCles.first { $0.1.contains(where: { m.contains($0) }) }
                    .flatMap { cle in Ouvrage.tous.first { $0.id == cle.0 }?.nom } ?? ""
            }
            let mots = m.split(separator: " ").filter { $0.count >= 4 }
            guard !ouvrage.isEmpty || !mots.isEmpty else { continue }
            resultat.append(TravailCompris(piece: pieceCourante, prestation: "", ouvrage: ouvrage,
                                           description: m, quantite: quantite, unite: unite))
        }
        return resultat
    }

    private static func quantiteDite(_ texte: String) -> (Double, String) {
        let mots = texte.replacingOccurrences(of: ",", with: ".").split(separator: " ").map(String.init)
        for (i, mot) in mots.enumerated() {
            let valeur = Double(mot.replacingOccurrences(of: "m2", with: "").replacingOccurrences(of: "m", with: ""))
                ?? nombresEnLettres[mot]
            guard let valeur, valeur > 0 else { continue }
            let suite = mots.dropFirst(i + 1).prefix(2).joined(separator: " ")
            if mot.hasSuffix("m2") || suite.hasPrefix("m2") || suite.hasPrefix("metre carre") || suite.hasPrefix("metres carres") {
                return (valeur, "m2")
            }
            if mot.hasSuffix("m") || suite.hasPrefix("m ") || suite == "m" || suite.hasPrefix("metre") || suite.hasPrefix("ml") {
                return (valeur, "ml")
            }
            if nombresEnLettres[mot] == 1 && !suite.contains("metre") { continue } // « un », « une » : article
            return (valeur, "u")
        }
        return (0, "u")
    }

    // MARK: Rapprochement avec le catalogue

    private static let synonymes: [String: String] = [
        "repeindre": "peinture", "peindre": "peinture", "carreler": "carrelage", "faience": "faience",
        "parquet": "parquet", "demolir": "depose", "enlever": "depose", "retirer": "depose", "casser": "depose",
        "cloison": "cloison", "placo": "plaques", "gravats": "gravats", "plinthe": "plinthes",
    ]

    private static let motsVides: Set<String> = ["dans", "pour", "avec", "sans", "faire", "fait", "sera", "cette",
                                                  "piece", "aussi", "mettre", "poser", "veux", "faut", "besoin"]

    private static func racines(_ texte: String) -> Set<String> {
        Set(plier(texte)
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 4 && !motsVides.contains($0) }
            .map { synonymes[$0] ?? $0 }
            .map { String($0.prefix(5)) })
    }

    static func meilleurePrestation(_ description: String, dans catalogue: [Prestation]) -> Prestation? {
        let dits = racines(description)
        guard !dits.isEmpty else { return nil }
        var meilleure: (Prestation, Double)?
        for prestation in catalogue {
            let siens = racines(prestation.nom)
            guard !siens.isEmpty else { continue }
            let communs = Double(siens.intersection(dits).count)
            guard communs > 0 else { continue }
            let score = communs / Double(siens.count) + communs * 0.1
            if score > (meilleure?.1 ?? 0) { meilleure = (prestation, score) }
        }
        guard let meilleure, meilleure.1 >= 0.34 else { return nil }
        return meilleure.0
    }

    private static func uniteDite(_ code: String) -> UniteDevis {
        switch code {
        case "m2": return .m2
        case "ml": return .ml
        case "h": return .heure
        case "forfait": return .forfait
        default: return .unite
        }
    }

    static func convertir(_ travaux: [TravailCompris], chantier: Chantier, catalogue: [Prestation]) -> [PropositionLigne] {
        let franchise = Entreprise.actuelle.franchiseTVA
        var lignes: [PropositionLigne] = []
        for travail in travaux {
            let piece = chantier.pieces.first { plier($0.nom) == plier(travail.piece) }
                ?? chantier.pieces.first { !travail.piece.isEmpty && plier(travail.piece).contains(plier($0.nom)) }
            let section = piece?.nom ?? ""

            if let ouvrage = Ouvrage.tous.first(where: { !travail.ouvrage.isEmpty && plier($0.nom) == plier(travail.ouvrage) }) {
                let parametre = travail.quantite > 0 && ouvrage.longueurParDefaut != nil ? travail.quantite : (ouvrage.longueurParDefaut ?? 0)
                for composant in ouvrage.composants where composant.coche {
                    let p = catalogue.first { plier($0.nom) == plier(composant.prestation) }
                    lignes.append(PropositionLigne(section: section,
                                                   designation: composant.prestation,
                                                   unite: p?.unite ?? composant.unite,
                                                   quantite: (composant.quantite(parametre) * 100).rounded() / 100,
                                                   prix: p?.prixHT ?? composant.prixParDefaut,
                                                   tva: franchise ? 0 : (p?.tauxTVA ?? 10)))
                }
                continue
            }

            let prestation = catalogue.first { !travail.prestation.isEmpty && plier($0.nom) == plier(travail.prestation) }
                ?? meilleurePrestation(travail.prestation + " " + travail.description, dans: catalogue)
            var quantite = travail.quantite
            if quantite <= 0 {
                if let prestation, let piece, prestation.base != .manuelle {
                    quantite = (prestation.base.quantite(pour: piece) * 100).rounded() / 100
                } else {
                    quantite = 1
                }
            }
            let description = travail.description.trimmingCharacters(in: .whitespaces)
            lignes.append(PropositionLigne(section: section,
                                           designation: prestation?.nom ?? (description.prefix(1).uppercased() + description.dropFirst()),
                                           unite: prestation?.unite ?? uniteDite(travail.unite),
                                           quantite: quantite,
                                           prix: prestation?.prixHT ?? 0,
                                           tva: franchise ? 0 : (prestation?.tauxTVA ?? 10),
                                           reconnue: prestation != nil))
        }
        return lignes
    }
}

// MARK: - Écran de dictée

struct DicteeDevisView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexte
    @Query(sort: \Prestation.nom) private var catalogue: [Prestation]
    let chantier: Chantier

    @State private var dictaphone = Dictaphone()
    @State private var propositions: [PropositionLigne] = []
    @State private var methode = ""
    @State private var analyseEnCours = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        Button {
                            Task { await dictaphone.basculer() }
                        } label: {
                            Image(systemName: dictaphone.enEcoute ? "stop.fill" : "mic.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(.white)
                                .frame(width: 84, height: 84)
                                .background(dictaphone.enEcoute ? Color.red : Color.accentColor, in: Circle())
                                .symbolEffect(.pulse, isActive: dictaphone.enEcoute)
                        }
                        .buttonStyle(.plain)
                        Text(dictaphone.enEcoute ? "Je t'écoute… touche pour arrêter" : "Touche le micro et décris les travaux, pièce par pièce")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    if let erreur = dictaphone.erreur {
                        Text(erreur).font(.footnote).foregroundStyle(.red)
                    }
                } footer: {
                    Text("Exemple : « Dans la salle de bains, je dépose la baignoire et je mets une douche avec 5 m² de faïence. Dans la chambre, alimentation d'un radiateur avec 3 mètres de saignée, et peinture des murs. »")
                }

                Section("Texte (modifiable)") {
                    TextField("Ce que tu as dit apparaît ici", text: $dictaphone.texte, axis: .vertical)
                        .lineLimit(3...10)
                    Button {
                        analyser()
                    } label: {
                        if analyseEnCours {
                            HStack { ProgressView(); Text("Analyse en cours…") }
                        } else {
                            Label("Transformer en lignes de devis", systemImage: "wand.and.stars")
                        }
                    }
                    .disabled(dictaphone.texte.trimmingCharacters(in: .whitespaces).isEmpty || analyseEnCours || dictaphone.enEcoute)
                }

                if !propositions.isEmpty {
                    ForEach(sections, id: \.self) { section in
                        Section {
                            ForEach($propositions) { $ligne in
                                if ligne.section == section {
                                    LigneProposee(ligne: $ligne)
                                }
                            }
                        } header: {
                            Text(section.isEmpty ? "Travaux généraux" : section)
                        }
                    }
                    Section {
                        Text(methode)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Dicter des travaux")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dictaphone.arreter()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter (\(propositions.filter(\.retenue).count))") { ajouter() }
                        .disabled(!propositions.contains(where: \.retenue))
                }
            }
            .onDisappear { dictaphone.arreter() }
        }
    }

    private var sections: [String] {
        var liste: [String] = []
        for ligne in propositions where !liste.contains(ligne.section) { liste.append(ligne.section) }
        return liste
    }

    private func analyser() {
        analyseEnCours = true
        Task {
            let resultat = await AnalyseDictee.analyser(dictaphone.texte, chantier: chantier, catalogue: catalogue)
            propositions = resultat.lignes
            methode = resultat.lignes.isEmpty ? "Aucun travail reconnu. Reformule ou complète le texte." : resultat.methode
            analyseEnCours = false
        }
    }

    private func ajouter() {
        for proposition in propositions where proposition.retenue {
            let ligne = LigneDevis(designation: proposition.designation,
                                   unite: proposition.unite,
                                   quantite: proposition.quantite,
                                   prixHT: proposition.prix,
                                   tauxTVA: proposition.tva,
                                   ordre: chantier.lignesDevis.count)
            ligne.section = proposition.section
            DevisView.ajouter(ligne, a: chantier, contexte: contexte)
        }
        dismiss()
    }
}

private struct LigneProposee: View {
    @Binding var ligne: PropositionLigne

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Button {
                    ligne.retenue.toggle()
                } label: {
                    Image(systemName: ligne.retenue ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(ligne.retenue ? Color.accentColor : Color.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                TextField("Désignation", text: $ligne.designation, axis: .vertical)
            }
            HStack(spacing: 8) {
                TextField("Qté", value: $ligne.quantite, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                Text(ligne.unite.rawValue).foregroundStyle(.secondary)
                Text("×")
                TextField("Prix", value: $ligne.prix, format: .currency(code: "EUR"))
                    .keyboardType(.decimalPad)
                    .frame(width: 90)
                    .textFieldStyle(.roundedBorder)
                Spacer()
                Text((ligne.quantite * ligne.prix).enEuros).fontWeight(.semibold)
            }
            .font(.subheadline)
            if !ligne.reconnue {
                Text("Pas trouvé dans ton catalogue : vérifie le libellé et saisis le prix.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .opacity(ligne.retenue ? 1 : 0.5)
    }
}
