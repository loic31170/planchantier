import SwiftUI
import SwiftData
import RoomPlan
import ARKit

/// Pilote la session de scan RoomPlan et récupère le résultat.
/// La session AR reste ouverte entre deux pièces : les pièces scannées à la suite
/// partagent le même repère, ce qui permet de les assembler en plan d'étage.
final class ControleurScan: NSObject, ObservableObject, RoomCaptureViewDelegate {
    let sessionAR: ARSession
    let vueCapture: RoomCaptureView

    @Published var enCours = false
    @Published var resultat: CapturedRoom?
    @Published var erreur: String?

    override init() {
        let session = ARSession()
        sessionAR = session
        vueCapture = RoomCaptureView(frame: .zero, arSession: session)
        super.init()
        vueCapture.delegate = self
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func encode(with coder: NSCoder) {}

    func demarrer() {
        guard !enCours, resultat == nil else { return }
        enCours = true
        vueCapture.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }

    /// Termine la pièce en cours sans couper la caméra (pour enchaîner la suivante).
    func terminer() {
        vueCapture.captureSession.stop(pauseARSession: false)
        enCours = false
    }

    func pieceSuivante() {
        resultat = nil
        enCours = true
        vueCapture.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }

    /// Arrête tout (caméra comprise).
    func fermer() {
        if enCours {
            vueCapture.captureSession.stop()
            enCours = false
        }
        sessionAR.pause()
    }

    // MARK: RoomCaptureViewDelegate

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        DispatchQueue.main.async {
            if let error {
                self.erreur = error.localizedDescription
            }
            self.resultat = processedResult
        }
    }
}

struct VueCaptureRepresentable: UIViewRepresentable {
    let controleur: ControleurScan

    func makeUIView(context: Context) -> RoomCaptureView {
        controleur.vueCapture
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}

/// Écran plein écran : on filme une ou plusieurs pièces à la suite.
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexte

    let chantier: Chantier

    @StateObject private var controleur = ControleurScan()
    @State private var nomPiece = ""
    @State private var sessionID = UUID()
    @State private var piecesEnregistrees = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VueCaptureRepresentable(controleur: controleur)
                    .ignoresSafeArea()

                if controleur.resultat == nil {
                    VStack(spacing: 12) {
                        Text(piecesEnregistrees == 0
                             ? "Fais lentement le tour de la pièce en filmant les murs, le sol et les ouvertures."
                             : "Pièce \(piecesEnregistrees + 1) : passe par la porte et scanne la pièce suivante.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        Button {
                            controleur.terminer()
                        } label: {
                            Label("Terminer cette pièce", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!controleur.enCours)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        TextField("Nom de la pièce (ex. Salon)", text: $nomPiece)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            enregistrer(suivante: true)
                        } label: {
                            Label("Enregistrer et scanner la pièce suivante", systemImage: "arrow.right.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        Button {
                            enregistrer(suivante: false)
                        } label: {
                            Text("Enregistrer et terminer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        Text("Les pièces scannées à la suite sont assemblées en plan d'étage.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(piecesEnregistrees == 0 ? "Annuler" : "Fermer") {
                        controleur.fermer()
                        dismiss()
                    }
                }
            }
            .onAppear { controleur.demarrer() }
            .alert("Problème pendant le scan",
                   isPresented: Binding(get: { controleur.erreur != nil },
                                        set: { if !$0 { controleur.erreur = nil } })) {
                Button("OK") {}
            } message: {
                Text(controleur.erreur ?? "")
            }
        }
    }

    private func enregistrer(suivante: Bool) {
        guard let scan = controleur.resultat else { return }
        let analyse = AnalyseurPiece.analyser(scan)
        let nomSaisi = nomPiece.trimmingCharacters(in: .whitespacesAndNewlines)
        let nom = nomSaisi.isEmpty ? "Pièce \(chantier.pieces.count + 1)" : nomSaisi

        let piece = Piece(nom: nom,
                          surfaceSol: analyse.surfaceSol,
                          perimetre: analyse.perimetre,
                          hauteur: analyse.hauteur,
                          segments: analyse.segments,
                          fichierScan: StockageScans.enregistrer(scan))
        piece.sessionScan = sessionID
        contexte.insert(piece)
        chantier.pieces.append(piece)
        piecesEnregistrees += 1

        if suivante {
            nomPiece = ""
            controleur.pieceSuivante()
        } else {
            controleur.fermer()
            dismiss()
        }
    }
}
