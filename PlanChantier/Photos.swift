import SwiftUI
import PhotosUI
import UIKit

/// Enregistre les photos des pièces sur l'appareil (dossier Documents/Photos).
enum StockagePhotos {
    static var dossier: URL {
        let url = URL.documentsDirectory.appending(path: "Photos", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func enregistrer(_ image: UIImage) -> String? {
        guard let donnees = image.reduite(coteMax: 2000).jpegData(compressionQuality: 0.8) else { return nil }
        let nom = UUID().uuidString + ".jpg"
        do {
            try donnees.write(to: dossier.appending(path: nom))
            return nom
        } catch {
            return nil
        }
    }

    static func image(_ nom: String) -> UIImage? {
        UIImage(contentsOfFile: dossier.appending(path: nom).path())
    }

    static func supprimer(_ nom: String) {
        try? FileManager.default.removeItem(at: dossier.appending(path: nom))
    }

    static func copier(_ nom: String) -> String? {
        let nouveau = UUID().uuidString + ".jpg"
        do {
            try FileManager.default.copyItem(at: dossier.appending(path: nom), to: dossier.appending(path: nouveau))
            return nouveau
        } catch {
            return nil
        }
    }
}

extension UIImage {
    /// Réduit l'image pour que son plus grand côté ne dépasse pas `coteMax` pixels.
    func reduite(coteMax: CGFloat) -> UIImage {
        let plusGrand = max(size.width, size.height)
        guard plusGrand > coteMax else { return self }
        let ratio = coteMax / plusGrand
        let taille = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: taille, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: taille))
        }
    }
}

/// Ouvre l'appareil photo de l'iPhone.
struct AppareilPhoto: UIViewControllerRepresentable {
    var quandPhotoPrise: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controleur = UIImagePickerController()
        controleur.sourceType = .camera
        controleur.delegate = context.coordinator
        return controleur
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinateur { Coordinateur(self) }

    final class Coordinateur: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: AppareilPhoto
        init(_ parent: AppareilPhoto) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.quandPhotoPrise(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Section « Photos » de la fiche d'une pièce.
struct SectionPhotos: View {
    @Bindable var piece: Piece
    @State private var appareilOuvert = false
    @State private var selection: [PhotosPickerItem] = []
    @State private var photoAffichee: String?

    var body: some View {
        Section("Photos") {
            if !piece.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(piece.photos, id: \.self) { nom in
                            if let image = StockagePhotos.image(nom) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 110, height: 110)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .onTapGesture { photoAffichee = nom }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            supprimer(nom)
                                        } label: {
                                            Label("Supprimer la photo", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                appareilOuvert = true
            } label: {
                Label("Prendre une photo", systemImage: "camera")
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            PhotosPicker(selection: $selection, maxSelectionCount: 10, matching: .images) {
                Label("Ajouter depuis la photothèque", systemImage: "photo.on.rectangle")
            }
        }
        .fullScreenCover(isPresented: $appareilOuvert) {
            AppareilPhoto { image in ajouter(image) }
                .ignoresSafeArea()
        }
        .onChange(of: selection) { _, elements in
            guard !elements.isEmpty else { return }
            Task {
                for element in elements {
                    if let donnees = try? await element.loadTransferable(type: Data.self),
                       let image = UIImage(data: donnees) {
                        ajouter(image)
                    }
                }
                selection = []
            }
        }
        .sheet(isPresented: Binding(get: { photoAffichee != nil },
                                    set: { if !$0 { photoAffichee = nil } })) {
            if let nom = photoAffichee, let image = StockagePhotos.image(nom) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func ajouter(_ image: UIImage) {
        if let nom = StockagePhotos.enregistrer(image) {
            piece.photos.append(nom)
        }
    }

    private func supprimer(_ nom: String) {
        piece.photos.removeAll { $0 == nom }
        StockagePhotos.supprimer(nom)
    }
}
