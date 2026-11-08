import SwiftUI
import SwiftData
import PDFKit
import VisionKit
import UniformTypeIdentifiers

// MARK: - Données

/// Un fichier rattaché au chantier : relevé ou devis généré, document importé ou scanné.
@Model
final class DocumentChantier {
    var nom: String
    var fichier: String
    var dateAjout: Date
    var typeRaw: String
    var chantier: Chantier?

    enum Genre: String {
        case releve, devis, importe, scan, modele3D

        var libelle: String {
            switch self {
            case .releve: return "Relevé"
            case .devis: return "Devis"
            case .importe: return "Importé"
            case .scan: return "Scan"
            case .modele3D: return "3D"
            }
        }
    }

    init(nom: String, fichier: String, genre: Genre, dateAjout: Date = .now) {
        self.nom = nom
        self.fichier = fichier
        self.typeRaw = genre.rawValue
        self.dateAjout = dateAjout
    }

    var genre: Genre { Genre(rawValue: typeRaw) ?? .importe }
    var url: URL { StockageDocuments.url(fichier) }
    var extensionFichier: String { url.pathExtension.uppercased() }
}

enum StockageDocuments {
    static var dossier: URL {
        let url = URL.documentsDirectory.appending(path: "Fichiers", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(_ nom: String) -> URL { dossier.appending(path: nom) }

    /// Copie un fichier dans le dossier de l'appli et renvoie son nom.
    static func copier(depuis source: URL) -> String? {
        let ext = source.pathExtension.isEmpty ? "pdf" : source.pathExtension.lowercased()
        let nom = UUID().uuidString + "." + ext
        do {
            try FileManager.default.copyItem(at: source, to: url(nom))
            return nom
        } catch {
            return nil
        }
    }

    static func supprimer(_ nom: String) {
        try? FileManager.default.removeItem(at: url(nom))
    }

    /// Vignette de la première page (PDF) ou de l'image.
    static func vignette(_ nom: String) -> UIImage? {
        let adresse = url(nom)
        switch adresse.pathExtension.lowercased() {
        case "pdf":
            return PDFDocument(url: adresse)?.page(at: 0)?.thumbnail(of: CGSize(width: 260, height: 340), for: .mediaBox)
        case "usdz":
            return nil
        default:
            return UIImage(contentsOfFile: adresse.path())?.reduite(coteMax: 400)
        }
    }
}

extension Chantier {
    /// Range un fichier généré (relevé, devis…) dans les fichiers du chantier.
    @discardableResult
    func archiver(_ source: URL, nom: String, genre: DocumentChantier.Genre, contexte: ModelContext) -> DocumentChantier? {
        guard let fichier = StockageDocuments.copier(depuis: source) else { return nil }
        let document = DocumentChantier(nom: nom, fichier: fichier, genre: genre)
        contexte.insert(document)
        documents.append(document)
        return document
    }

    var documentsTries: [DocumentChantier] {
        documents.sorted { $0.dateAjout > $1.dateAjout }
    }
}

// MARK: - Scanner de documents (appareil photo)

struct ScannerDocuments: UIViewControllerRepresentable {
    var quandTermine: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controleur = VNDocumentCameraViewController()
        controleur.delegate = context.coordinator
        return controleur
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinateur { Coordinateur(self) }

    final class Coordinateur: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: ScannerDocuments
        init(_ parent: ScannerDocuments) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            parent.quandTermine(pages)
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}

// MARK: - Section « Fichiers » de la fiche chantier

struct SectionFichiers: View {
    @Environment(\.modelContext) private var contexte
    @Bindable var chantier: Chantier
    var genererReleve: () -> Void
    var genererDevis: () -> Void

    @State private var importOuvert = false
    @State private var scannerOuvert = false
    @State private var apercu: URL?
    @State private var aRenommer: DocumentChantier?
    @State private var nouveauNom = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fichiers").font(.title3.weight(.bold))
                    Text("Rapports, devis, documents scannés ou importés")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !chantier.documents.isEmpty {
                    NavigationLink {
                        TousLesFichiersView(chantier: chantier)
                    } label: {
                        Text("Voir tout (\(chantier.documents.count))")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    Menu {
                        Button {
                            genererReleve()
                        } label: {
                            Label("Générer le relevé", systemImage: "doc.richtext")
                        }
                        .disabled(chantier.pieces.isEmpty)
                        Button {
                            genererDevis()
                        } label: {
                            Label("Générer le devis", systemImage: "eurosign.circle")
                        }
                        .disabled(chantier.lignesDevis.isEmpty)
                        Divider()
                        Button {
                            scannerOuvert = true
                        } label: {
                            Label("Scanner un document", systemImage: "doc.viewfinder")
                        }
                        .disabled(!VNDocumentCameraViewController.isSupported)
                        Button {
                            importOuvert = true
                        } label: {
                            Label("Importer un fichier", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        CercleAjout(titre: "Fichier")
                    }

                    ForEach(chantier.documentsTries) { document in
                        Button {
                            apercu = document.url
                        } label: {
                            CarteDocument(document: document)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { menu(document) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .quickLookPreview($apercu)
        .sheet(isPresented: $scannerOuvert) {
            ScannerDocuments { pages in enregistrerScan(pages) }
                .ignoresSafeArea()
        }
        .fileImporter(isPresented: $importOuvert,
                      allowedContentTypes: [.pdf, .image, .usdz],
                      allowsMultipleSelection: true) { resultat in
            guard case .success(let urls) = resultat else { return }
            for url in urls {
                let acces = url.startAccessingSecurityScopedResource()
                defer { if acces { url.stopAccessingSecurityScopedResource() } }
                if let fichier = StockageDocuments.copier(depuis: url) {
                    let document = DocumentChantier(nom: url.deletingPathExtension().lastPathComponent,
                                                    fichier: fichier, genre: .importe)
                    contexte.insert(document)
                    chantier.documents.append(document)
                }
            }
        }
        .alert("Renommer le fichier",
               isPresented: Binding(get: { aRenommer != nil }, set: { if !$0 { aRenommer = nil } })) {
            TextField("Nom", text: $nouveauNom)
            Button("Annuler", role: .cancel) {}
            Button("Renommer") {
                let nom = nouveauNom.trimmingCharacters(in: .whitespaces)
                if !nom.isEmpty { aRenommer?.nom = nom }
            }
        }
    }

    @ViewBuilder
    private func menu(_ document: DocumentChantier) -> some View {
        ShareLink(item: document.url) {
            Label("Partager", systemImage: "square.and.arrow.up")
        }
        Button {
            nouveauNom = document.nom
            aRenommer = document
        } label: {
            Label("Renommer", systemImage: "pencil")
        }
        Divider()
        Button(role: .destructive) {
            StockageDocuments.supprimer(document.fichier)
            contexte.delete(document)
        } label: {
            Label("Supprimer", systemImage: "trash")
        }
    }

    private func enregistrerScan(_ pages: [UIImage]) {
        guard !pages.isEmpty else { return }
        let pdf = PDFDocument()
        for (index, image) in pages.enumerated() {
            if let page = PDFPage(image: image.reduite(coteMax: 2200)) {
                pdf.insert(page, at: index)
            }
        }
        let temporaire = URL.temporaryDirectory.appending(path: "scan.pdf")
        guard pdf.write(to: temporaire) else { return }
        let date = Date.now.formatted(date: .abbreviated, time: .shortened)
        chantier.archiver(temporaire, nom: "Document scanné du \(date)", genre: .scan, contexte: contexte)
    }
}

struct CarteDocument: View {
    let document: DocumentChantier
    var largeur: CGFloat = 120

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                if let image = StockageDocuments.vignette(document.fichier) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                } else {
                    Image(systemName: document.extensionFichier == "USDZ" ? "cube.transparent" : "doc")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: largeur, height: largeur * 1.25)
            .overlay(alignment: .topTrailing) {
                Text(document.extensionFichier)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            }
            .overlay(alignment: .bottomLeading) {
                Text(document.genre.libelle)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .padding(8)
            }
            .padding(.bottom, 4)
            Text(document.nom)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(document.dateAjout.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: largeur)
    }
}

struct TousLesFichiersView: View {
    @Environment(\.modelContext) private var contexte
    let chantier: Chantier
    @State private var apercu: URL?
    private let colonnes = [GridItem(.adaptive(minimum: 110), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: colonnes, spacing: 18) {
                ForEach(chantier.documentsTries) { document in
                    Button {
                        apercu = document.url
                    } label: {
                        CarteDocument(document: document, largeur: 110)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        ShareLink(item: document.url) {
                            Label("Partager", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            StockageDocuments.supprimer(document.fichier)
                            contexte.delete(document)
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Fichiers")
        .quickLookPreview($apercu)
    }
}
