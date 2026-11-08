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

// MARK: - Détail d'un chantier

struct ChantierView: View {
    @Environment(\.modelContext) private var contexte
    @Bindable var chantier: Chantier
    @State private var scanOuvert = false
    @State private var lidarAbsent = false
    @State private var documentPDF: DocumentPDF?

    private var piecesTriees: [Piece] {
        chantier.pieces.sorted { $0.dateScan < $1.dateScan }
    }

    var body: some View {
        List {
            Section("Informations") {
                TextField("Nom", text: $chantier.nom)
                TextField("Client", text: $chantier.client)
                TextField("Adresse", text: $chantier.adresse, axis: .vertical)
            }

            Section("Pièces") {
                ForEach(piecesTriees) { piece in
                    NavigationLink {
                        PieceView(piece: piece)
                    } label: {
                        HStack {
                            Text(piece.nom)
                            Spacer()
                            Text(piece.surfaceSol.enMetresCarres)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { positions in
                    let pieces = piecesTriees
                    for i in positions {
                        pieces[i].supprimerFichiers()
                        contexte.delete(pieces[i])
                    }
                }

                Button {
                    if RoomCaptureSession.isSupported {
                        scanOuvert = true
                    } else {
                        lidarAbsent = true
                    }
                } label: {
                    Label("Scanner une pièce", systemImage: "camera.viewfinder")
                }
            }

            if !chantier.etages.isEmpty {
                Section("Plans d'étage") {
                    ForEach(Array(chantier.etages.enumerated()), id: \.offset) { index, pieces in
                        NavigationLink {
                            EcranPlanEtage(titre: "Plan d'étage \(index + 1)", pieces: pieces)
                        } label: {
                            LabeledContent {
                                Text("\(pieces.count) pièces")
                            } label: {
                                Label("Plan d'étage \(index + 1)", systemImage: "square.split.2x2")
                            }
                        }
                    }
                }
            }

            Section("Devis") {
                NavigationLink {
                    DevisView(chantier: chantier)
                } label: {
                    LabeledContent {
                        Text(chantier.lignesDevis.isEmpty
                             ? "à faire"
                             : TotauxDevis(lignes: chantier.lignesDevis,
                                           franchise: Entreprise.actuelle.franchiseTVA).ttc.enEuros)
                    } label: {
                        Label("Devis", systemImage: "eurosign.circle")
                    }
                }
            }

            if !chantier.pieces.isEmpty {
                Section("Total du chantier") {
                    LabeledContent("Surface au sol", value: chantier.surfaceTotale.enMetresCarres)
                    LabeledContent("Nombre de pièces", value: "\(chantier.pieces.count)")
                }
            }
        }
        .navigationTitle(chantier.nom)
        .toolbar {
            Button {
                if let url = ExportPDF.generer(chantier) {
                    documentPDF = DocumentPDF(url: url)
                }
            } label: {
                Label("Exporter en PDF", systemImage: "square.and.arrow.up")
            }
            .disabled(chantier.pieces.isEmpty)
        }
        .sheet(item: $documentPDF) { document in
            FeuillePartage(elements: [document.url])
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $scanOuvert) {
            ScanView(chantier: chantier)
        }
        .alert("Scan impossible", isPresented: $lidarAbsent) {
            Button("OK") {}
        } message: {
            Text("Cet appareil n'a pas de capteur LiDAR. Le scan fonctionne sur les iPhone Pro (12 Pro et plus récents) et les iPad Pro.")
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
                PlanPieceView(segments: segments)
                    .frame(height: 340)
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
    }
}
