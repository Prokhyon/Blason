import SwiftUI
import PaperKit
import PencilKit
import SheetKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Croquis ou zone manuscrite à dessiner (PaperKit) : nouveau, ou existant à modifier.
struct DrawingRequest: Identifiable {
    let id = UUID()
    var kind: JournalDocument.Kind
    var title: String
    var isListed: Bool
    /// Document existant (modification) ; nil pour un nouveau dessin.
    var document: JournalDocument?
}

/// Dessin enregistré : données PaperKit et rendu PNG (recadré sur le contenu).
struct DrawingResult {
    var data: Data
    var preview: Data?
    var title: String
}

/// Éditeur de dessin : feuille PaperKit, outils du système (crayon, formes, texte), titre.
/// L'écriture d'une zone manuscrite reste de l'encre : rien n'est converti en texte.
struct DrawingEditor: View {
    let request: DrawingRequest
    let onSave: (DrawingResult) -> Void

    @State private var title: String
    @State private var model = DrawingModel()
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss

    init(request: DrawingRequest, onSave: @escaping (DrawingResult) -> Void) {
        self.request = request
        self.onSave = onSave
        _title = State(initialValue: request.title)
    }

    var body: some View {
        NavigationStack {
            PaperMarkupView(model: model, markup: initialMarkup)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(navigationTitle)
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { dismiss() }
                    }
                    if request.kind == .sketch {
                        ToolbarItem(placement: .principal) {
                            TextField("Titre", text: $title, prompt: Text("Titre du croquis"))
                                .multilineTextAlignment(.center)
                                .font(.headline)
                                .frame(maxWidth: 280)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("OK") { save() }
                            .disabled(saving)
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 820, minHeight: 620)
        #endif
        .interactiveDismissDisabled()
    }

    private var navigationTitle: String {
        switch request.kind {
        case .handwriting: String(localized: "Écriture manuscrite")
        default: title.isEmpty ? String(localized: "Croquis") : title
        }
    }

    /// Dessin existant, ou feuille vierge : paysage pour un croquis, bande large pour l'écriture.
    private var initialMarkup: PaperMarkup {
        if let data = request.document?.data, let markup = try? PaperMarkup(dataRepresentation: data) {
            return markup
        }
        let size = request.kind == .handwriting ? CGSize(width: 768, height: 1024) : CGSize(width: 1024, height: 768)
        return PaperMarkup(bounds: CGRect(origin: .zero, size: size))
    }

    private func save() {
        guard let markup = model.markup else { return dismiss() }
        saving = true
        Task {
            defer { saving = false }
            guard let data = try? await markup.dataRepresentation() else { return dismiss() }
            let preview = await DrawingRenderer.preview(of: markup, kind: request.kind)
            // Nouveau dessin laissé vide : rien à ajouter.
            if request.document == nil, preview == nil { return dismiss() }
            onSave(DrawingResult(data: data, preview: preview, title: title.trimmingCharacters(in: .whitespaces)))
            dismiss()
        }
    }
}

/// Lien avec le contrôleur PaperKit.
@MainActor @Observable
final class DrawingModel {
    @ObservationIgnored weak var controller: PaperMarkupViewController?

    var markup: PaperMarkup? { controller?.markup }
}

enum DrawingRenderer {
    /// Rendu PNG du contenu, avec une marge ; nil si le dessin est vide. L'écriture garde toute la
    /// largeur de la feuille (sa taille reste celle du texte voisin).
    static func preview(of markup: PaperMarkup, kind: JournalDocument.Kind) async -> Data? {
        let content = markup.contentsRenderFrame
        guard !content.isNull, !content.isEmpty, content.width > 1 || content.height > 1 else { return nil }
        let margin: CGFloat = 24
        var frame = content.insetBy(dx: -margin, dy: -margin).intersection(markup.bounds)
        if kind == .handwriting {
            frame.origin.x = markup.bounds.minX
            frame.size.width = markup.bounds.width
        } else if frame.width < 240 {
            frame = frame.insetBy(dx: -(240 - frame.width) / 2, dy: 0)
        }
        frame = frame.integral
        let scale: CGFloat = 2
        let width = Int(frame.width * scale), height = Int(frame.height * scale)
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // PaperKit dessine l'axe y vers le haut : on retourne le contexte, puis on recadre.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -frame.minX, y: -frame.minY)
        await markup.draw(in: context, frame: markup.bounds)
        guard let image = context.makeImage() else { return nil }
        return pngData(image)
    }

    private static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

#if canImport(UIKit)

private struct PaperMarkupView: UIViewControllerRepresentable {
    let model: DrawingModel
    let markup: PaperMarkup

    func makeUIViewController(context: Context) -> DrawingHostController {
        let paper = PaperMarkupViewController(markup: markup, supportedFeatureSet: .latest)
        paper.directTouchAutomaticallyDraws = true
        model.controller = paper
        return DrawingHostController(paper: paper)
    }

    func updateUIViewController(_ controller: DrawingHostController, context: Context) {}
}

/// Contient la feuille PaperKit et lui donne le focus une fois à l'écran : la palette d'outils
/// du système n'apparaît que pour le premier répondeur.
final class DrawingHostController: UIViewController {
    let paper: PaperMarkupViewController
    private let picker = PKToolPicker()

    init(paper: PaperMarkupViewController) {
        self.paper = paper
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(paper)
        paper.view.frame = view.bounds
        paper.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(paper.view)
        paper.didMove(toParent: self)
        picker.addObserver(paper)
        paper.pencilKitResponderState.activeToolPicker = picker
        paper.pencilKitResponderState.toolPickerVisibility = .visible
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        paper.becomeFirstResponder()
    }
}

#else

private struct PaperMarkupView: NSViewControllerRepresentable {
    let model: DrawingModel
    let markup: PaperMarkup

    func makeNSViewController(context: Context) -> NSViewController {
        let paper = PaperMarkupViewController(markup: markup, supportedFeatureSet: .latest)
        model.controller = paper
        let toolbar = MarkupToolbarViewController(supportedFeatureSet: .latest)
        toolbar.delegate = paper

        let container = NSViewController()
        container.view = NSView()
        container.addChild(toolbar)
        container.addChild(paper)
        let stack = NSStackView(views: [toolbar.view, paper.view])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.view.addSubview(stack)
        paper.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.view.bottomAnchor),
            paper.view.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        return container
    }

    func updateNSViewController(_ controller: NSViewController, context: Context) {}
}

#endif
