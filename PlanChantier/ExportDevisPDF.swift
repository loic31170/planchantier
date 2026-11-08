import SwiftUI

/// Génère le PDF du devis d'un chantier.
/// Une ligne du tableau du devis : titre de pièce, prestation ou sous-total.
enum RangDevis: Identifiable {
    case titre(String)
    case ligne(LigneDevis)
    case sousTotal(String, Double)

    var id: String {
        switch self {
        case .titre(let nom): return "t-" + nom
        case .ligne(let ligne): return "l-\(ligne.persistentModelID.hashValue)"
        case .sousTotal(let nom, _): return "s-" + nom
        }
    }

    /// Place occupée, en lignes ordinaires.
    var poids: Int {
        switch self {
        case .ligne(let ligne): return ligne.designation.count > 70 ? 2 : 1
        default: return 1
        }
    }
}

/// Génère le PDF du devis d'un chantier, regroupé par pièce.
@MainActor
enum ExportDevisPDF {
    static let lignesPremierePage = 14
    static let lignesParPage = 24

    static func rangs(_ chantier: Chantier) -> [RangDevis] {
        let lignes = chantier.lignesDevis.sorted { $0.ordre < $1.ordre }
        let parPiece = lignes.contains { !$0.section.isEmpty }
        guard parPiece else { return lignes.map { .ligne($0) } }
        var rangs: [RangDevis] = []
        for section in chantier.sectionsDevis {
            let liste = lignes.filter { $0.section == section }
            guard !liste.isEmpty else { continue }
            let titre = section.isEmpty ? "Travaux généraux" : section
            rangs.append(.titre(titre))
            rangs.append(contentsOf: liste.map { .ligne($0) })
            rangs.append(.sousTotal(titre, liste.reduce(0) { $0 + $1.totalHT }))
        }
        return rangs
    }

    static func generer(_ chantier: Chantier) -> URL? {
        let entreprise = Entreprise.actuelle
        let totaux = TotauxDevis(lignes: chantier.lignesDevis, franchise: entreprise.franchiseTVA)

        var groupes: [[RangDevis]] = [[]]
        var place = lignesPremierePage
        for rang in rangs(chantier) {
            if rang.poids > place, !(groupes.last ?? []).isEmpty {
                groupes.append([])
                place = lignesParPage
            }
            groupes[groupes.count - 1].append(rang)
            place -= rang.poids
        }
        // Les totaux et la signature doivent tenir sur la dernière page.
        if groupes.count > 1, (groupes.last ?? []).reduce(0, { $0 + $1.poids }) > 16 {
            groupes.append([])
        }

        let pages: [AnyView] = groupes.enumerated().map { index, groupe in
            AnyView(PageDevisPDF(chantier: chantier,
                                 entreprise: entreprise,
                                 rangs: groupe,
                                 totaux: totaux,
                                 premiere: index == 0,
                                 derniere: index == groupes.count - 1))
        }
        let numero = chantier.numeroDevis.isEmpty ? "brouillon" : chantier.numeroDevis
        return ExportPDF.rendre(pages: pages, nomFichier: "Devis \(numero)")
    }
}

struct PageDevisPDF: View {
    let chantier: Chantier
    let entreprise: Entreprise
    let rangs: [RangDevis]
    let totaux: TotauxDevis
    let premiere: Bool
    let derniere: Bool

    private var dateDevis: Date { chantier.dateDevis ?? .now }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if premiere {
                enTete
            } else {
                Text("Devis n° \(chantier.numeroDevis) (suite)")
                    .font(.system(size: 12, weight: .semibold))
            }

            tableau

            if derniere {
                HStack {
                    Spacer()
                    blocTotaux
                }
                if entreprise.franchiseTVA {
                    Text("TVA non applicable, art. 293 B du CGI")
                        .font(.system(size: 9))
                }
                Spacer()
                signature
            } else {
                Spacer()
            }
        }
        .foregroundStyle(.black)
        .padding(40)
        .frame(width: ExportPDF.largeur, height: ExportPDF.hauteur, alignment: .topLeading)
    }

    private var enTete: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    LogoPDF()
                        .padding(.bottom, 6)
                    Text(entreprise.nom.isEmpty ? "Mon entreprise" : entreprise.nom)
                        .font(.system(size: 14, weight: .bold))
                    if !entreprise.adresse.isEmpty { Text(entreprise.adresse) }
                    if !entreprise.telephone.isEmpty { Text("Tél. \(entreprise.telephone)") }
                    if !entreprise.email.isEmpty { Text(entreprise.email) }
                    if !entreprise.siret.isEmpty { Text("SIRET \(entreprise.siret)") }
                }
                .font(.system(size: 9))
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("CLIENT")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(chantier.client.isEmpty ? "—" : chantier.client)
                        .font(.system(size: 11, weight: .semibold))
                    if !chantier.adresse.isEmpty {
                        Text(chantier.adresse).font(.system(size: 9))
                    }
                }
                .frame(width: 200, alignment: .leading)
                .padding(10)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.4)))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("DEVIS N° \(chantier.numeroDevis)")
                    .font(.system(size: 20, weight: .bold))
                Group {
                    Text("Date : \(dateDevis.formatted(date: .long, time: .omitted))")
                    Text("Valable \(entreprise.validite) jours, jusqu'au \(dateDevis.addingTimeInterval(Double(entreprise.validite) * 86_400).formatted(date: .long, time: .omitted))")
                    Text("Chantier : \(chantier.nom)")
                }
                .font(.system(size: 9))
            }
        }
    }

    private var tableau: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Désignation").frame(maxWidth: .infinity, alignment: .leading)
                Text("Qté").frame(width: 46, alignment: .trailing)
                Text("Unité").frame(width: 40, alignment: .leading)
                Text("PU HT").frame(width: 62, alignment: .trailing)
                if !entreprise.franchiseTVA {
                    Text("TVA").frame(width: 34, alignment: .trailing)
                }
                Text("Total HT").frame(width: 70, alignment: .trailing)
            }
            .font(.system(size: 8.5, weight: .semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(Color.gray.opacity(0.12))

            ForEach(rangs) { rang in
                switch rang {
                case .titre(let nom):
                    Text(nom.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                        .padding(.horizontal, 6)
                case .ligne(let ligne):
                    HStack(alignment: .top, spacing: 8) {
                        Text(ligne.designation)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(ligne.quantite.enQuantite).frame(width: 46, alignment: .trailing)
                        Text(ligne.unite.rawValue).frame(width: 40, alignment: .leading)
                        Text(ligne.prixHT.enEuros).frame(width: 62, alignment: .trailing)
                        if !entreprise.franchiseTVA {
                            Text(ligne.tauxTVA.enPourcentage).frame(width: 34, alignment: .trailing)
                        }
                        Text(ligne.totalHT.enEuros).frame(width: 70, alignment: .trailing)
                    }
                    .font(.system(size: 9))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 6)
                    Divider()
                case .sousTotal(let nom, let montant):
                    HStack {
                        Spacer()
                        Text("Sous-total \(nom)")
                        Text(montant.enEuros).frame(width: 70, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 6)
                    .background(Color.gray.opacity(0.06))
                }
            }
        }
    }

    private var blocTotaux: some View {
        Grid(alignment: .trailing, horizontalSpacing: 24, verticalSpacing: 5) {
            GridRow {
                Text("Total HT")
                Text(totaux.ht.enEuros)
            }
            ForEach(totaux.tva, id: \.taux) { tva in
                GridRow {
                    Text("TVA \(tva.taux.enPourcentage)")
                    Text(tva.montant.enEuros)
                }
            }
            Divider().gridCellUnsizedAxes(.horizontal)
            GridRow {
                Text(entreprise.franchiseTVA ? "Net à payer" : "Total TTC")
                    .font(.system(size: 12, weight: .bold))
                Text(totaux.ttc.enEuros)
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .font(.system(size: 10))
        .frame(width: 230)
    }

    private var signature: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Bon pour accord")
                    .font(.system(size: 10, weight: .semibold))
                Text("Date et signature du client, précédées de la mention « Devis reçu avant l'exécution des travaux ».")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.5))
                    .frame(height: 80)
            }
            .frame(width: 240)
        }
    }
}
