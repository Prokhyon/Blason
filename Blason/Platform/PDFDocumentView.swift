import SwiftUI
import PDFKit

// Consultation des documents du journal avec PDFKit (iOS et macOS) : un PDF paginé, ou une image
// présentée comme une page, ce qui donne le zoom et le défilement du système dans les deux cas.

/// Document PDFKit d'un PDF ou d'une image.
enum PDFContent {
    static func document(data: Data, isPDF: Bool) -> PDFDocument? {
        if isPDF { return PDFDocument(data: data) }
        guard let image = PlatformImage(data: data), let page = PDFPage(image: image) else { return nil }
        let document = PDFDocument()
        document.insert(page, at: 0)
        return document
    }

    /// Vignette de la première page (ou de l'image).
    static func thumbnail(data: Data, isPDF: Bool, side: CGFloat) -> PlatformImage? {
        if !isPDF { return PlatformImage(data: data) }
        guard let page = PDFDocument(data: data)?.page(at: 0) else { return nil }
        return page.thumbnail(of: CGSize(width: side, height: side), for: .mediaBox)
    }

    static func pageCount(data: Data, isPDF: Bool) -> Int {
        isPDF ? PDFDocument(data: data)?.pageCount ?? 0 : 1
    }
}

#if canImport(UIKit)
struct PDFDocumentView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        configure(view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { configure(view) }
    }

    private func configure(_ view: PDFView) {
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .secondarySystemBackground
    }
}
#else
struct PDFDocumentView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        configure(view)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document { configure(view) }
    }

    private func configure(_ view: PDFView) {
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
    }
}
#endif
