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

        typealias Run = JournalText.Run
        typealias Paragraph = JournalText.Paragraph
        func ref(_ entry: CodexEntry, _ text: String? = nil) -> Run { Run(text: text ?? entry.name, reference: entry.uid) }

        let first = journal.addSession(date: now.addingTimeInterval(-15 * day), in: context)
        first.title = "Arrivée à Port-Lune"
        first.gameDate = "3 Thermidor 1792"
        first.summary = "Leo débarque, rencontre Aldo et accepte de retrouver la Mouette grise."
        first.gains = "50 po d'avance. Lettre de recommandation d'Aldo."
        first.apply(JournalText(paragraphs: [
            Paragraph(runs: [Run(text: "Arrivée au port à la tombée du jour. "), ref(marchand),
                             Run(text: " nous attend sur le quai, nerveux.")]),
            Paragraph(runs: [Run(text: "La Mouette grise n'est pas rentrée depuis neuf jours ; "), ref(capitaine, "sa capitaine"),
                             Run(text: " non plus. Les hommes de la "), ref(guilde), Run(text: " ne disent rien.")]),
            Paragraph(style: .heading, runs: [Run(text: "Le marché")]),
            Paragraph(list: .bullet, runs: [Run(text: "50 po d'avance, 100 au retour")]),
            Paragraph(list: .bullet, runs: [Run(text: "Passage gratuit vers le sud")]),
        ]))

        let second = journal.addSession(date: now.addingTimeInterval(-8 * day), in: context)
        second.title = "La lettre scellée"
        second.gameDate = "5 Thermidor 1792"
        second.summary = "Fouille de la cabine du capitaine : une lettre au sceau étrange."
        second.gains = "Expérience : Fouiller, Discrétion."
        var secondText = JournalText(paragraphs: [
            Paragraph(runs: [Run(text: "La cabine de "), ref(capitaine), Run(text: " a été fouillée avant nous.")]),
            Paragraph(runs: [Run(text: "Dans le double fond du coffre : une lettre au "), ref(sceau, "sceau à l'étoile brisée"),
                             Run(text: ", qui donne rendez-vous "), Run(text: "« là où la lumière ne guide plus personne »", italic: true),
                             Run(text: ".")]),
            Paragraph(runs: [ref(phare), Run(text: " ?", bold: true)]),
            Paragraph(list: .checklist, checked: true, runs: [Run(text: "Fouiller la cabine")]),
            Paragraph(list: .checklist, checked: false, runs: [Run(text: "Interroger le gardien du port")]),
        ])
        if let map = demoMapPDF() {
            let document = journal.addDocument(title: "Carte de la baie", contentType: .pdf, data: map, entry: phare,
                                               in: context)
            secondText.paragraphs.append(Paragraph(runs: [.attachment(document.uid)]))
        }
        second.apply(secondText)

        let third = journal.addSession(date: now.addingTimeInterval(-1 * day), in: context)
        third.title = "Nuit au phare"
        third.gameDate = "6 Thermidor 1792"
        third.summary = "Le phare est occupé. Combat dans l'escalier, fuite par la grève."
        third.gains = "Expérience : Épée courte, Esquive. Une clé de bronze."
        third.apply(JournalText(paragraphs: [
            Paragraph(runs: [Run(text: "Des silhouettes en robe grise dans "), ref(phare, "le phare"),
                             Run(text: ". Le même "), ref(sceau, "sceau"), Run(text: " sur la porte.")]),
            Paragraph(runs: [Run(text: "Leo est blessé (PV −4).", bold: true)]),
        ]))
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
