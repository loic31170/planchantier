import SwiftUI
import SwiftData
import RoomPlan

// MARK: - Nouveau chantier

struct NouveauChantierView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexte
    @State private var nom = ""
    @State private var client = ""
    @State private var adresse = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom du chantier", text: $nom)
                TextField("Client", text: $client)
                TextField("Adresse", text: $adresse, axis: .vertical)
            }
            .navigationTitle("Nouveau chantier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        contexte.insert(Chantier(nom: nom, client: client, adresse: adresse))
                        dismiss()
                    }
                    .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Détail d'une pièce

struct PieceView: View {
    @Bindable var piece: Piece

    var body: some View {
        let segments = piece.segments
        List {
            Section {
                PlanCoteView(segments: segments, nom: piece.nom)
                    .frame(height: 380)
                    .background(Color(.systemBackground))
                LegendePlan()
            }

            Section("Mesures") {
                LabeledContent("Surface au sol", value: piece.surfaceSol.enMetresCarres)
                LabeledContent("Périmètre", value: piece.perimetre.enMetres)
                LabeledContent("Hauteur sous plafond", value: piece.hauteur.enMetres)
                LabeledContent("Surface des murs (brute)", value: piece.surfaceMursBrute.enMetresCarres)
                LabeledContent("Surface des murs (nette)", value: piece.surfaceMursNette.enMetresCarres)
                LabeledContent("Longueur de plinthes", value: piece.lineairePlinthes.enMetres)
                LabeledContent("Portes", value: "\(segments.filter { $0.genre == .porte }.count)")
                LabeledContent("Fenêtres", value: "\(segments.filter { $0.genre == .fenetre }.count)")
            }

            Section("Murs") {
                ForEach(Array(PlanPieceView.mursOrdonnes(segments).enumerated()), id: \.offset) { index, mur in
                    LabeledContent("Mur \(index + 1)", value: mur.longueur.enMetres)
                }
            }

            SectionPhotos(piece: piece)

            Section("Pièce") {
                TextField("Nom de la pièce", text: $piece.nom)
                TextField("Notes", text: $piece.notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle(piece.nom)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    Vue3DView(titre: piece.nom, pieces: [piece])
                } label: {
                    Label("Vue 3D", systemImage: "cube")
                }
            }
        }
    }
}
