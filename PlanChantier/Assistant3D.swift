import SwiftUI
import SwiftData

/// Plan 3D depuis l'accueil : choix du chantier, puis des étages et des pièces.
struct Assistant3DView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Chantier.dateCreation, order: .reverse) private var chantiers: [Chantier]

    private var chantiersAvecPieces: [Chantier] {
        chantiers.filter { !$0.pieces.isEmpty && !$0.archive }
    }

    var body: some View {
        NavigationStack {
            List {
                if chantiersAvecPieces.isEmpty {
                    ContentUnavailableView("Aucun chantier scanné",
                                           systemImage: "cube.transparent",
                                           description: Text("Scanne d'abord une pièce dans un chantier pour pouvoir générer son plan 3D."))
                } else {
                    Section {
                        ForEach(chantiersAvecPieces) { chantier in
                            NavigationLink {
                                ChoixPieces3DView(chantier: chantier)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chantier.nom).font(.headline)
                                    Text(resume(chantier))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } header: {
                        Text("1. Choisis le chantier")
                    }
                }
            }
            .navigationTitle("Plan 3D")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func resume(_ chantier: Chantier) -> String {
        var elements: [String] = []
        if !chantier.client.isEmpty { elements.append(chantier.client) }
        elements.append("\(chantier.pieces.count) pièce\(chantier.pieces.count > 1 ? "s" : "")")
        if !chantier.etages.isEmpty {
            elements.append("\(chantier.etages.count) étage\(chantier.etages.count > 1 ? "s" : "")")
        }
        elements.append(chantier.surfaceTotale.enMetresCarres)
        return elements.joined(separator: " · ")
    }
}

struct ChoixPieces3DView: View {
    let chantier: Chantier
    @State private var choisies: Set<PersistentIdentifier> = []

    private var selection: [Piece] {
        chantier.pieces
            .filter { choisies.contains($0.persistentModelID) }
            .sorted { $0.dateScan < $1.dateScan }
    }

    /// Pièces venant de scans différents : elles ne partagent pas le même repère.
    private var scansDifferents: Bool {
        let sessions = Set(selection.map { $0.sessionScan?.uuidString ?? $0.persistentModelID.hashValue.description })
        return sessions.count > 1
    }

    private var titre: String {
        if selection.count == 1, let piece = selection.first { return piece.nom }
        for (index, etage) in chantier.etages.enumerated()
        where Set(etage.map(\.persistentModelID)) == choisies {
            return "\(chantier.nom) – étage \(index + 1)"
        }
        return chantier.nom
    }

    var body: some View {
        List {
            Section {
                Button(choisies.count == chantier.pieces.count ? "Tout désélectionner" : "Tout sélectionner") {
                    if choisies.count == chantier.pieces.count {
                        choisies = []
                    } else {
                        choisies = Set(chantier.pieces.map(\.persistentModelID))
                    }
                }
            }

            ForEach(Array(chantier.etages.enumerated()), id: \.offset) { index, etage in
                Section {
                    ligneEtage(etage, titre: "Tout l'étage \(index + 1)")
                    ForEach(etage) { piece in ligne(piece) }
                } header: {
                    Text("Étage \(index + 1)")
                }
            }

            if !chantier.piecesSeules.isEmpty {
                Section {
                    ForEach(chantier.piecesSeules) { piece in ligne(piece) }
                } header: {
                    Text(chantier.etages.isEmpty ? "Pièces" : "Pièces seules")
                }
            }

            if scansDifferents {
                Section {
                    Label("Ces pièces viennent de scans différents : elles risquent d'être mal placées les unes par rapport aux autres. Pour un plan 3D d'étage fidèle, scanne les pièces à la suite avec « Scanner la pièce suivante ».",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(chantier.nom)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            NavigationLink {
                Vue3DView(titre: titre, pieces: selection)
            } label: {
                Label(selection.isEmpty ? "Choisis au moins une pièce"
                                        : "Générer le plan 3D (\(selection.count) pièce\(selection.count > 1 ? "s" : ""))",
                      systemImage: "cube")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selection.isEmpty ? Color.gray : Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .disabled(selection.isEmpty)
            .padding()
            .background(.bar)
        }
        .onAppear {
            // Par défaut : le premier étage, sinon toutes les pièces.
            if choisies.isEmpty {
                let defaut = chantier.etages.first ?? chantier.pieces
                choisies = Set(defaut.map(\.persistentModelID))
            }
        }
    }

    private func ligneEtage(_ etage: [Piece], titre: String) -> some View {
        let ids = Set(etage.map(\.persistentModelID))
        let tout = ids.isSubset(of: choisies)
        return Button {
            if tout { choisies.subtract(ids) } else { choisies.formUnion(ids) }
        } label: {
            HStack {
                Image(systemName: tout ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(tout ? Color.accentColor : Color.secondary)
                Text(titre).fontWeight(.semibold)
                Spacer()
                Text(etage.reduce(0) { $0 + $1.surfaceSol }.enMetresCarres)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }

    private func ligne(_ piece: Piece) -> some View {
        let coche = choisies.contains(piece.persistentModelID)
        return Button {
            if coche { choisies.remove(piece.persistentModelID) } else { choisies.insert(piece.persistentModelID) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: coche ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(coche ? Color.accentColor : Color.secondary)
                PlanPieceView(segments: piece.segments)
                    .frame(width: 44, height: 44)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(piece.nom)
                    Text(piece.surfaceSol.enMetresCarres)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if piece.fichierScan == nil {
                    Text("Pas de scan 3D")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

struct CartePlan3D: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.accentColor.gradient)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.white)
                }
            Text("Plan 3D")
                .font(.headline)
                .frame(maxWidth: .infinity)
            Text("Choisir chantier et pièces")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
