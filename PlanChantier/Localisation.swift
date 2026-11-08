import SwiftUI
import MapKit
import UIKit

// MARK: - Adresse structurée et Plans d'Apple

extension Chantier {
    var coordonnees: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Reconstruit l'adresse affichée à partir des champs (le pays est omis s'il s'agit de la France).
    func composerAdresse() {
        let ville = [adresseCodePostal, adresseVille].filter { !$0.isEmpty }.joined(separator: " ")
        let pays = ["", "France", "FR"].contains(adressePays) ? "" : adressePays
        adresse = [adresseRue, ville, pays].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Ouvre le chantier dans l'appli Plans d'Apple, avec ou sans itinéraire en voiture.
    func ouvrirDansPlans(itineraire: Bool) {
        if let point = coordonnees {
            let lieu = MKMapItem(placemark: MKPlacemark(coordinate: point))
            lieu.name = client.isEmpty ? nom : client
            lieu.openInMaps(launchOptions: itineraire
                            ? [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
                            : nil)
        } else if !adresse.isEmpty {
            var composants = URLComponents(string: "https://maps.apple.com/")
            composants?.queryItems = [URLQueryItem(name: itineraire ? "daddr" : "q",
                                                   value: adresse.replacingOccurrences(of: "\n", with: ", "))]
            if let url = composants?.url { UIApplication.shared.open(url) }
        }
    }
}

struct ChampsAdresse {
    var rue = ""
    var codePostal = ""
    var ville = ""
    var region = ""
    var pays = ""

    init() {}

    init(_ lieu: CLPlacemark) {
        rue = [lieu.subThoroughfare, lieu.thoroughfare].compactMap { $0 }.joined(separator: " ")
        if rue.isEmpty { rue = lieu.name ?? "" }
        codePostal = lieu.postalCode ?? ""
        ville = lieu.locality ?? ""
        region = lieu.administrativeArea ?? ""
        pays = lieu.country ?? ""
    }

    var estVide: Bool { [rue, codePostal, ville, region, pays].allSatisfy { $0.isEmpty } }
}

// MARK: - Carte plein écran

struct LocalisationChantierView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var chantier: Chantier
    @State private var satellite = false
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if let point = chantier.coordonnees {
                    Map(position: $position) {
                        Marker(chantier.client.isEmpty ? chantier.nom : chantier.client,
                               systemImage: "hammer.fill",
                               coordinate: point)
                            .tint(Color.accentColor)
                    }
                    .mapStyle(satellite ? .hybrid(elevation: .realistic) : .standard(elevation: .realistic))
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                    }
                    .onAppear {
                        position = .region(MKCoordinateRegion(center: point, latitudinalMeters: 600, longitudinalMeters: 600))
                    }
                } else {
                    ContentUnavailableView(chantier.adresse.isEmpty ? "Pas encore d'adresse" : "Adresse introuvable",
                                           systemImage: "mappin.slash",
                                           description: Text(chantier.adresse.isEmpty
                                                             ? "Ajoute l'adresse du chantier avec le bouton Modifier."
                                                             : "Vérifie l'adresse avec le bouton Modifier."))
                        .frame(maxHeight: .infinity)
                }

                VStack(spacing: 12) {
                    Text(chantier.adresse.isEmpty ? "Aucune adresse" : chantier.adresse.replacingOccurrences(of: "\n", with: ", "))
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        Button {
                            chantier.ouvrirDansPlans(itineraire: true)
                        } label: {
                            Label("Itinéraire", systemImage: "car.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(chantier.adresse.isEmpty)

                        NavigationLink {
                            EditionAdresseView(chantier: chantier)
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .controlSize(.large)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding()
            }
            .navigationTitle("Localisation du chantier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            satellite = false
                        } label: {
                            Label("Plan", systemImage: satellite ? "map" : "checkmark")
                        }
                        Button {
                            satellite = true
                        } label: {
                            Label("Satellite", systemImage: satellite ? "checkmark" : "globe.europe.africa")
                        }
                        Divider()
                        Button {
                            chantier.ouvrirDansPlans(itineraire: false)
                        } label: {
                            Label("Ouvrir dans Plans", systemImage: "map.fill")
                        }
                        .disabled(chantier.adresse.isEmpty)
                    } label: {
                        Image(systemName: satellite ? "globe.europe.africa.fill" : "map")
                    }
                }
            }
        }
    }
}

// MARK: - Modification de l'adresse

final class SuggestionsAdresse: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var resultats: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func chercher(_ texte: String) {
        if texte.trimmingCharacters(in: .whitespaces).count < 3 {
            resultats = []
        } else {
            completer.queryFragment = texte
        }
    }

    func vider() { resultats = [] }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        resultats = Array(completer.results.prefix(5))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        resultats = []
    }
}

struct EditionAdresseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var chantier: Chantier

    @State private var champs = ChampsAdresse()
    @State private var position: CLLocationCoordinate2D?
    @StateObject private var suggestions = SuggestionsAdresse()
    @State private var saisieRue = false
    @State private var confirmerSuppression = false
    @FocusState private var focusRue: Bool

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adresse (rue)").font(.caption).foregroundStyle(.secondary)
                    TextField("ex. 12 rue des Lilas", text: $champs.rue)
                        .focused($focusRue)
                        .textContentType(.fullStreetAddress)
                        .onChange(of: champs.rue) { _, texte in
                            if focusRue {
                                position = nil
                                suggestions.chercher(texte)
                            }
                        }
                }
                if focusRue && !suggestions.resultats.isEmpty {
                    ForEach(suggestions.resultats, id: \.self) { suggestion in
                        Button {
                            choisir(suggestion)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(suggestion.title).foregroundStyle(.primary)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                champ("Ville", $champs.ville, contenu: .addressCity)
                champ("Code postal", $champs.codePostal, contenu: .postalCode)
                    .keyboardType(.numberPad)
                champ("Région", $champs.region, contenu: .addressState)
                champ("Pays", $champs.pays, contenu: .countryName)
            } footer: {
                Text("Commence à taper la rue : Plans d'Apple te propose des adresses qui remplissent les autres champs.")
            }

            if !chantier.adresse.isEmpty {
                Section {
                    Button("Supprimer l'adresse…", role: .destructive) {
                        confirmerSuppression = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Modifier l'adresse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Sauvegarder") { sauvegarder() }
            }
        }
        .confirmationDialog("Supprimer l'adresse de ce chantier ?", isPresented: $confirmerSuppression, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                champs = ChampsAdresse()
                position = nil
                sauvegarder()
            }
        }
        .task {
            await chargerChamps()
        }
    }

    private func champ(_ titre: String, _ texte: Binding<String>, contenu: UITextContentType) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titre).font(.caption).foregroundStyle(.secondary)
            TextField(titre, text: texte)
                .textContentType(contenu)
        }
    }

    /// Remplit les champs : ceux déjà enregistrés, sinon l'ancienne adresse découpée par Apple.
    private func chargerChamps() async {
        champs.rue = chantier.adresseRue
        champs.codePostal = chantier.adresseCodePostal
        champs.ville = chantier.adresseVille
        champs.region = chantier.adresseRegion
        champs.pays = chantier.adressePays
        position = chantier.coordonnees
        guard champs.estVide, !chantier.adresse.isEmpty else { return }
        champs.rue = chantier.adresse.replacingOccurrences(of: "\n", with: ", ")
        if let lieu = try? await CLGeocoder().geocodeAddressString(chantier.adresse).first {
            champs = ChampsAdresse(lieu)
            position = lieu.location?.coordinate
        }
    }

    private func choisir(_ suggestion: MKLocalSearchCompletion) {
        focusRue = false
        suggestions.vider()
        Task {
            let requete = MKLocalSearch.Request(completion: suggestion)
            if let lieu = try? await MKLocalSearch(request: requete).start().mapItems.first?.placemark {
                champs = ChampsAdresse(lieu)
                position = lieu.coordinate
            } else {
                champs.rue = suggestion.title
            }
        }
    }

    private func sauvegarder() {
        chantier.adresseRue = champs.rue.trimmingCharacters(in: .whitespaces)
        chantier.adresseCodePostal = champs.codePostal.trimmingCharacters(in: .whitespaces)
        chantier.adresseVille = champs.ville.trimmingCharacters(in: .whitespaces)
        chantier.adresseRegion = champs.region.trimmingCharacters(in: .whitespaces)
        chantier.adressePays = champs.pays.trimmingCharacters(in: .whitespaces)
        let ancienneAdresse = chantier.adresse
        chantier.composerAdresse()
        if let position {
            chantier.latitude = position.latitude
            chantier.longitude = position.longitude
        } else if chantier.adresse != ancienneAdresse {
            // la fiche chantier relocalisera la nouvelle adresse
            chantier.latitude = nil
            chantier.longitude = nil
        }
        dismiss()
    }
}
