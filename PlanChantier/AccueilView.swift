import SwiftUI
import SwiftData

enum FiltreChantiers: String, CaseIterable, Identifiable {
    case tous = "Tous"
    case favoris = "Favoris"
    case archives = "Archivés"

    var id: String { rawValue }

    var icone: String {
        switch self {
        case .tous: return "square.stack"
        case .favoris: return "star"
        case .archives: return "archivebox"
        }
    }
}

// MARK: - Page d'accueil : les chantiers en cartes

struct ListeChantiersView: View {
    @Environment(\.modelContext) private var contexte
    @Query(sort: \Chantier.dateCreation, order: .reverse) private var chantiers: [Chantier]
    @AppStorage(Reglages.nom) private var nomEntreprise = ""

    @State private var filtre: FiltreChantiers = .tous
    @State private var recherche = ""
    @State private var nouveauChantier = false
    @State private var reglagesOuverts = false
    @State private var aSupprimer: Chantier?

    private let colonnes = [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 16)]

    private var chantiersAffiches: [Chantier] {
        chantiers
            .filter { chantier in
                switch filtre {
                case .tous: return !chantier.archive
                case .favoris: return chantier.favori && !chantier.archive
                case .archives: return chantier.archive
                }
            }
            .filter { chantier in
                let texte = recherche.trimmingCharacters(in: .whitespaces)
                guard !texte.isEmpty else { return true }
                return [chantier.nom, chantier.client, chantier.adresse]
                    .contains { $0.localizedCaseInsensitiveContains(texte) }
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    enTete
                    filtres

                    LazyVGrid(columns: colonnes, alignment: .leading, spacing: 22) {
                        if filtre == .tous && recherche.isEmpty {
                            Button {
                                nouveauChantier = true
                            } label: {
                                CarteNouveauChantier()
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(chantiersAffiches) { chantier in
                            NavigationLink(value: chantier) {
                                CarteChantier(chantier: chantier)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { menu(chantier) }
                        }
                    }

                    if chantiersAffiches.isEmpty && (filtre != .tous || !recherche.isEmpty) {
                        ContentUnavailableView(recherche.isEmpty ? "Aucun chantier ici" : "Aucun résultat",
                                               systemImage: recherche.isEmpty ? filtre.icone : "magnifyingglass",
                                               description: Text(recherche.isEmpty
                                                                 ? "Fais un appui long sur un chantier pour le mettre en favori ou l'archiver."
                                                                 : "Essaie avec un autre nom, client ou adresse."))
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .searchable(text: $recherche, prompt: "Chantier, client, adresse…")
            .navigationTitle("Chantiers")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Chantier.self) { ChantierView(chantier: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reglagesOuverts = true
                    } label: {
                        Label("Réglages", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $nouveauChantier) {
                NouveauChantierView()
            }
            .sheet(isPresented: $reglagesOuverts) {
                ReglagesView()
            }
            .confirmationDialog("Supprimer ce chantier ?",
                                isPresented: Binding(get: { aSupprimer != nil },
                                                     set: { if !$0 { aSupprimer = nil } }),
                                titleVisibility: .visible) {
                Button("Supprimer définitivement", role: .destructive) {
                    if let chantier = aSupprimer {
                        chantier.supprimerFichiers()
                        contexte.delete(chantier)
                    }
                    aSupprimer = nil
                }
            } message: {
                Text("Les pièces, photos et le devis de ce chantier seront supprimés.")
            }
            .onAppear {
                Catalogue.initialiserSiBesoin(contexte)
            }
        }
    }

    // MARK: En-tête et filtres

    private var enTete: some View {
        HStack(spacing: 12) {
            Group {
                if let logo = StockageLogo.image {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image(systemName: "building.2")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 52, height: 52)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(nomEntreprise.isEmpty ? "Mes chantiers" : nomEntreprise)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                let actifs = chantiers.filter { !$0.archive }.count
                Text("\(actifs) chantier\(actifs > 1 ? "s" : "") en cours")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var filtres: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FiltreChantiers.allCases) { element in
                    let actif = element == filtre
                    Button {
                        withAnimation(.snappy) { filtre = element }
                    } label: {
                        Label(element.rawValue, systemImage: element.icone)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .foregroundStyle(actif ? Color.white : Color.primary)
                            .background(actif ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                                        in: Capsule())
                            .overlay(Capsule().stroke(actif ? Color.clear : Color(.separator), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func menu(_ chantier: Chantier) -> some View {
        Button {
            chantier.favori.toggle()
        } label: {
            Label(chantier.favori ? "Retirer des favoris" : "Ajouter aux favoris",
                  systemImage: chantier.favori ? "star.slash" : "star")
        }
        Button {
            chantier.archive.toggle()
        } label: {
            Label(chantier.archive ? "Désarchiver" : "Archiver",
                  systemImage: chantier.archive ? "tray.and.arrow.up" : "archivebox")
        }
        Divider()
        Button(role: .destructive) {
            aSupprimer = chantier
        } label: {
            Label("Supprimer", systemImage: "trash")
        }
    }
}

// MARK: - Cartes

struct CarteNouveauChantier: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color.accentColor)
                }
            Text("Nouveau chantier")
                .font(.headline)
                .frame(maxWidth: .infinity)
            Text(" ").font(.subheadline)
        }
    }
}

struct CarteChantier: View {
    let chantier: Chantier

    /// Le plan d'étage s'il existe, sinon la première pièce scannée.
    private var piecesApercu: [Piece] {
        if let etage = chantier.etages.first { return etage }
        if let premiere = chantier.pieces.sorted(by: { $0.dateScan < $1.dateScan }).first { return [premiere] }
        return []
    }

    private var initiales: String {
        let source = chantier.client.isEmpty ? chantier.nom : chantier.client
        let lettres = source.split(separator: " ").prefix(2).compactMap { $0.first }
        return String(lettres).uppercased()
    }

    private var sousTitre: String {
        if !chantier.adresse.isEmpty { return chantier.adresse.replacingOccurrences(of: "\n", with: ", ") }
        if !chantier.client.isEmpty { return chantier.client }
        return "Sans adresse"
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemGroupedBackground))
                if piecesApercu.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 34, weight: .light))
                        Text("Aucune pièce")
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                } else {
                    PlanEtageView(pieces: piecesApercu, afficherNoms: false, epaisseur: 3, marge: 14)
                        .padding(6)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                if !initiales.isEmpty {
                    Text(initiales)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.15), in: Circle())
                        .padding(10)
                }
            }
            .overlay(alignment: .topTrailing) {
                if chantier.favori {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .padding(10)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !chantier.pieces.isEmpty {
                    Text(chantier.surfaceTotale.enMetresCarres)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                        .padding(10)
                }
            }
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .padding(.bottom, 6)

            Text(chantier.nom)
                .font(.headline)
                .lineLimit(1)
            Text(sousTitre)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(chantier.dateCreation.formatted(.dateTime.day().month(.abbreviated))) · \(chantier.pieces.count) pièce\(chantier.pieces.count > 1 ? "s" : "")")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}
