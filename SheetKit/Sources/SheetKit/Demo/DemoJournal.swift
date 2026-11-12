import Foundation
import SwiftData
import CoreGraphics
import UniformTypeIdentifiers

extension DemoData {
    /// Journal d'exemple (captures, essais : `-demoJournal YES`) : trois sessions, des PNJ, un lieu,
    /// un indice, et une carte en PDF. Ne fait rien si le personnage a déjà un journal non vide.
    @discardableResult
    public static func addDemoJournal(to character: PlayerCharacter, now: Date = Date(),
                                      in context: ModelContext) -> Journal? {
        let journal = character.ensureJournal(in: context)
        guard journal.isEmpty else { return nil }
        let day: TimeInterval = 86_400

        let marchand = journal.addEntry(named: "Aldo Brisetout", kind: .npc, in: context)
        marchand.status = "vivant"
        marchand.summary = "Marchand d'épices du port. Doit une faveur à Leo, cache quelque chose sur la cargaison."
        let capitaine = journal.addEntry(named: "Capitaine Mereth", kind: .npc, in: context)
        capitaine.status = "disparue"
        capitaine.summary = "Commande la Mouette grise. Vue pour la dernière fois au phare."
        let phare = journal.addEntry(named: "Le phare de Kerlaz", kind: .place, in: context)
        phare.summary = "Phare abandonné au nord de la baie ; on y voit de la lumière certaines nuits."
        let sceau = journal.addEntry(named: "Sceau à l'étoile brisée", kind: .clue, in: context)
        sceau.status = "non résolu"
        sceau.summary = "Trouvé sur la lettre adressée au capitaine. Même motif gravé sur la porte du phare."
        let guilde = journal.addEntry(named: "Guilde des haleurs", kind: .faction, in: context)
        guilde.summary = "Tient les quais. Neutre pour l'instant."

        let first = journal.addSession(date: now.addingTimeInterval(-15 * day), in: context)
        first.title = "Arrivée à Port-Lune"
        first.gameDate = "3 Thermidor 1792"
        first.summary = "Leo débarque, rencontre Aldo et accepte de retrouver la Mouette grise."
        first.plainText = """
        Arrivée au port à la tombée du jour. Aldo Brisetout nous attend sur le quai, nerveux.
        La Mouette grise n'est pas rentrée depuis neuf jours ; sa capitaine non plus.
        Nous acceptons de mener l'enquête contre 50 po et un passage gratuit vers le sud.
        """
        first.gains = "50 po d'avance. Lettre de recommandation d'Aldo."
        first.setAppears(marchand, true)
        first.setAppears(capitaine, true)
        first.setAppears(guilde, true)

        let second = journal.addSession(date: now.addingTimeInterval(-8 * day), in: context)
        second.title = "La lettre scellée"
        second.gameDate = "5 Thermidor 1792"
        second.summary = "Fouille de la cabine du capitaine : une lettre au sceau étrange."
        second.plainText = """
        La cabine a été fouillée avant nous. Dans le double fond du coffre : une lettre au sceau \
        à l'étoile brisée, qui donne rendez-vous « là où la lumière ne guide plus personne ».
        Le phare de Kerlaz ?
        """
        second.gains = "Expérience : Fouiller, Discrétion."
        second.setAppears(capitaine, true)
        second.setAppears(sceau, true)
        second.setAppears(phare, true)

        let third = journal.addSession(date: now.addingTimeInterval(-1 * day), in: context)
        third.title = "Nuit au phare"
        third.gameDate = "6 Thermidor 1792"
        third.summary = "Le phare est occupé. Combat dans l'escalier, fuite par la grève."
        third.plainText = "Des silhouettes en robe grise. Le même sceau sur la porte. Leo est blessé (PV −4)."
        third.gains = "Expérience : Épée courte, Esquive. Une clé de bronze."
        third.setAppears(phare, true)
        third.setAppears(sceau, true)

        if let map = demoMapPDF() {
            journal.addDocument(title: "Carte de la baie", contentType: .pdf, data: map, session: second, entry: phare,
                                in: context)
        }
        return journal
    }

    /// Petite carte en PDF (une page, dessinée) : de quoi essayer la consultation des documents.
    static func demoMapPDF() -> Data? {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 420, height: 297)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        pdf.beginPDFPage(nil)
        pdf.setFillColor(CGColor(red: 0.95, green: 0.91, blue: 0.82, alpha: 1))
        pdf.fill(box)
        // Mer, côte, phare.
        pdf.setFillColor(CGColor(red: 0.62, green: 0.76, blue: 0.84, alpha: 1))
        pdf.fill(CGRect(x: 0, y: 0, width: 420, height: 110))
        pdf.setStrokeColor(CGColor(red: 0.35, green: 0.27, blue: 0.2, alpha: 1))
        pdf.setLineWidth(2)
        pdf.move(to: CGPoint(x: 0, y: 110))
        pdf.addCurve(to: CGPoint(x: 420, y: 140), control1: CGPoint(x: 140, y: 170), control2: CGPoint(x: 280, y: 60))
        pdf.strokePath()
        pdf.setFillColor(CGColor(red: 0.7, green: 0.2, blue: 0.15, alpha: 1))
        pdf.fillEllipse(in: CGRect(x: 330, y: 150, width: 14, height: 14))
        pdf.fill(CGRect(x: 90, y: 160, width: 30, height: 20))
        pdf.endPDFPage()
        pdf.closePDF()
        return data as Data
    }
}
