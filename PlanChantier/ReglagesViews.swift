import SwiftUI
import SwiftData

// MARK: - Réglages

struct ReglagesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Reglages.nom) private var nom = ""
    @AppStorage(Reglages.adresse) private var adresse = ""
    @AppStorage(Reglages.telephone) private var telephone = ""
    @AppStorage(Reglages.email) private var email = ""
    @AppStorage(Reglages.siret) private var siret = ""
    @AppStorage(Reglages.franchiseTVA) private var franchiseTVA = false
    @AppStorage(Reglages.validite) private var validite = 30

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom de l'entreprise", text: $nom)
                    TextField("Adresse", text: $adresse, axis: .vertical)
                    TextField("Téléphone", text: $telephone)
                        .keyboardType(.phonePad)
                    TextField("E-mail", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("SIRET", text: $siret)
                        .keyboardType(.numberPad)
                    ReglageLogo()
                } header: {
                    Text("Mon entreprise")
                } footer: {
                    Text("Ces informations et ton logo apparaissent en haut de tes devis et relevés.")
                }

                Section {
                    Toggle("Franchise de TVA (micro-entreprise)", isOn: $franchiseTVA)
                    Stepper("Devis valable \(validite) jours", value: $validite, in: 7...180, step: 1)
                } header: {
                    Text("Devis")
                } footer: {
                    Text(franchiseTVA
                         ? "Les devis afficheront « TVA non applicable, art. 293 B du CGI »."
                         : "Le taux de TVA se règle pour chaque prestation (10 % pour la rénovation d'un logement de plus de 2 ans, 20 % sinon).")
                }

                Section {
                    NavigationLink {
                        CatalogueView()
                    } label: {
                        Label("Catalogue de prestations", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Catalogue

struct CatalogueView: View {
    @Environment(\.modelContext) private var contexte
    @Query(sort: \Prestation.nom) private var prestations: [Prestation]
    @State private var prestationEditee: Prestation?

    var body: some View {
        List {
            Section {
                ForEach(prestations) { prestation in
                    Button {
                        prestationEditee = prestation
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(prestation.nom).foregroundStyle(.primary)
                            Text("\(prestation.prixHT.enEuros) HT / \(prestation.unite.rawValue) · \(prestation.base.libelle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { positions in
                    for i in positions { contexte.delete(prestations[i]) }
                }
            } footer: {
                Text("Les prix de départ sont des exemples : adapte-les à tes tarifs.")
            }
        }
        .navigationTitle("Catalogue")
        .toolbar {
            Button {
                let nouvelle = Prestation(nom: "Nouvelle prestation", unite: .m2, prixHT: 0, base: .surfaceSol)
                contexte.insert(nouvelle)
                prestationEditee = nouvelle
            } label: {
                Label("Nouvelle prestation", systemImage: "plus")
            }
        }
        .sheet(item: $prestationEditee) { prestation in
            PrestationFormView(prestation: prestation)
        }
    }
}

struct PrestationFormView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Reglages.franchiseTVA) private var franchiseTVA = false
    @Bindable var prestation: Prestation

    var body: some View {
        NavigationStack {
            Form {
                Section("Prestation") {
                    TextField("Nom", text: $prestation.nom, axis: .vertical)
                }
                Section {
                    Picker("Quantité calculée à partir de", selection: $prestation.baseRaw) {
                        ForEach(BaseQuantite.allCases) { base in
                            Text(base.libelle).tag(base.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    Picker("Unité", selection: $prestation.uniteRaw) {
                        ForEach(UniteDevis.allCases, id: \.self) { unite in
                            Text(unite.rawValue).tag(unite.rawValue)
                        }
                    }
                } header: {
                    Text("Calcul")
                } footer: {
                    Text("La quantité est calculée automatiquement à partir des mesures des pièces scannées.")
                }
                Section("Prix") {
                    LabeledContent("Prix unitaire HT") {
                        TextField("0", value: $prestation.prixHT, format: .currency(code: "EUR"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if !franchiseTVA {
                        Picker("TVA", selection: $prestation.tauxTVA) {
                            ForEach(TauxTVA.valeurs, id: \.self) { taux in
                                Text(taux.enPourcentage).tag(taux)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Prestation")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: prestation.baseRaw) { _, _ in
                prestation.uniteRaw = prestation.base.uniteConseillee.rawValue
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}
