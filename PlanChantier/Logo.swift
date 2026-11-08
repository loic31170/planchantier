import SwiftUI
import PhotosUI
import UIKit

/// Logo de l'entreprise affiché sur les PDF.
/// Priorité au logo choisi dans les réglages, sinon celui fourni avec l'appli (Assets, « LogoEntreprise »).
enum StockageLogo {
    static var url: URL { URL.documentsDirectory.appending(path: "logo.png") }

    static var image: UIImage? {
        if let choisi = UIImage(contentsOfFile: url.path()) { return choisi }
        return UIImage(named: "LogoEntreprise")
    }

    static func enregistrer(_ image: UIImage) {
        try? image.reduite(coteMax: 800).pngData()?.write(to: url)
    }

    static func supprimer() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Ligne des réglages pour choisir ou retirer le logo.
struct ReglageLogo: View {
    @State private var selection: PhotosPickerItem?
    @State private var apercu: UIImage? = StockageLogo.image

    var body: some View {
        if let apercu {
            HStack {
                Spacer()
                Image(uiImage: apercu)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 80)
                Spacer()
            }
        }
        PhotosPicker(selection: $selection, matching: .images) {
            Label(apercu == nil ? "Choisir un logo" : "Changer le logo", systemImage: "photo")
        }
        .onChange(of: selection) { _, element in
            guard let element else { return }
            Task {
                if let donnees = try? await element.loadTransferable(type: Data.self),
                   let image = UIImage(data: donnees) {
                    StockageLogo.enregistrer(image)
                    apercu = StockageLogo.image
                }
                selection = nil
            }
        }
        if FileManager.default.fileExists(atPath: StockageLogo.url.path()) {
            Button("Retirer le logo choisi", role: .destructive) {
                StockageLogo.supprimer()
                apercu = StockageLogo.image
            }
        }
    }
}

/// Logo à afficher en haut d'une page PDF (rien s'il n'y a pas de logo).
struct LogoPDF: View {
    var hauteurMax: CGFloat = 54

    var body: some View {
        if let logo = StockageLogo.image {
            Image(uiImage: logo)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 170, maxHeight: hauteurMax, alignment: .leading)
        }
    }
}
