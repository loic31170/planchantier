import SwiftUI
import SwiftData

@main
struct PlanChantierApp: App {
    var body: some Scene {
        WindowGroup {
            ListeChantiersView()
        }
        .modelContainer(for: [Chantier.self, Piece.self, Prestation.self, LigneDevis.self])
    }
}
