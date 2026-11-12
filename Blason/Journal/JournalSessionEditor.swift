import SwiftUI
import PhotosUI
import SwiftData
import SheetKit

/// Rédaction d'une session, comme dans Notes : un petit en-tête (numéro, date, titre, date en jeu,
/// détails repliables) qui défile avec le récit, sur toute la place (SPEC §5.17). La boîte à outils
/// flotte en bas, en verre : elle met en forme, cite les fiches du carnet (PNJ, lieux…), joint
/// documents, croquis et zones manuscrites.
struct JournalSessionEditor: View {
    @Bindable var session: JournalSession
    let journal: Journal
    let onDelete: () -> Void

    @State private var controller: JournalEditorController
    @State private var initialText: JournalText
    @State private var lastSaved: JournalText
    @State private var saveTask: Task<Void, Never>?
    @State private var showsDetails = false
    @State private var citing = false
    @State private var promptingSketch = false
    @State private var drawing: DrawingRequest?
    /// Croquis à dessiner une fois la feuille du titre fermée.
    @State private var pendingSketch: DrawingRequest?
    @State private var viewing: JournalDocument?
    @State private var importingFiles = false
    @State private var choosingPhotos = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var confirmingDelete = false
    @AppStorage("journalScribble") private var allowsScribble = true
    @Environment(\.modelContext) private var context
    @Environment(\.journalNavigator) private var navigator
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(session: JournalSession, journal: Journal, onDelete: @escaping () -> Void) {
        self.session = session
        self.journal = journal
        self.onDelete = onDelete
        let controller = JournalEditorController()
        controller.content = { [journal] uid in
            guard let document = journal.document(uid: uid) else { return nil }
            return JournalAttachmentContent(image: document.previewImage(side: 1200), kind: document.kind,
                                            title: document.displayTitle)
        }
        _controller = State(initialValue: controller)
        let text = session.text
        _initialText = State(initialValue: text)
        _lastSaved = State(initialValue: text.normalized())
    }

    var body: some View {
        JournalTextView(controller: controller, initialText: initialText, allowsScribble: allowsScribble,
                        header: AnyView(header))
        .background(Color.secondaryGroupedBackground)
        // Au-dessus du récit (qui garde une marge en bas pour qu'on puisse y écrire), et du clavier.
        .overlay(alignment: .bottom) { toolbox }
        .background { shortcuts }
        .onAppear(perform: connect)
        .onDisappear {
            saveNow()
            journal.removeUnusedAttachments(in: context)
        }
        .sheet(isPresented: $promptingSketch, onDismiss: {
            drawing = pendingSketch
            pendingSketch = nil
        }) {
            SketchPrompt { title, isListed in
                pendingSketch = DrawingRequest(kind: .sketch, title: title, isListed: isListed)
            }
        }
        .drawingEditor(item: $drawing, onSave: saveDrawing)
        .documentViewer(item: $viewing)
        .fileImporter(isPresented: $importingFiles, allowedContentTypes: ImportedDocument.allowedTypes,
                      allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            attach(urls.compactMap(ImportedDocument.init(url:)))
        }
        .photosPicker(isPresented: $choosingPhotos, selection: $photos, matching: .images)
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var documents: [ImportedDocument] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        documents.append(ImportedDocument(title: String(localized: "Photo"), type: .image, data: data))
                    }
                }
                photos = []
                attach(documents)
            }
        }
        .confirmationDialog("Supprimer la session \(session.number) ?", isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                saveTask?.cancel()
                onDelete()
            }
        } message: {
            Text("Les fiches du carnet et les documents classés restent dans le journal.")
        }
        #if DEBUG
        .task {
            // Captures : -demoDetails YES déplie les détails ; -demoCite YES ouvre le choix d'une fiche.
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: "demoDetails") { showsDetails = true }
            // -demoSketch YES : éditeur de croquis ouvert ; -demoHandwriting YES : zone manuscrite.
            if defaults.bool(forKey: "demoSketch") {
                drawing = DrawingRequest(kind: .sketch, title: "Plan de l'auberge", isListed: true)
            }
            if defaults.bool(forKey: "demoHandwriting") {
                drawing = DrawingRequest(kind: .handwriting, title: "", isListed: false)
            }
            if defaults.bool(forKey: "demoCite") {
                try? await Task.sleep(for: .seconds(1))
                citing = true
            }
        }
        #endif
    }

    // MARK: En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(session.numberTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                DatePicker("Date", selection: $session.date, displayedComponents: .date)
                    .labelsHidden()
                    .fixedSize()
                Spacer(minLength: 8)
                Button {
                    withAnimation(.snappy) { showsDetails.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text("Détails")
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(showsDetails ? 180 : 0))
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .accessibilityValue(showsDetails ? Text("Affichés") : Text("Masqués"))
            }
            TextField("Titre", text: $session.title, prompt: Text("Titre de la session"))
                .font(.title.weight(.bold))
                .textFieldStyle(.plain)
                .onSubmit { controller.host?.journalFocus() }
            TextField("Date en jeu", text: $session.gameDate, prompt: Text("Date en jeu"))
                .font(.subheadline.italic())
                .foregroundStyle(.secondary)
                .textFieldStyle(.plain)
            if showsDetails {
                details
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailField("Résumé") {
                TextField("Résumé", text: $session.summary, prompt: Text("En une ou deux phrases"), axis: .vertical)
                    .lineLimit(1...4)
            }
            detailField("Gains") {
                TextField("Gains", text: $session.gains, prompt: Text("Expérience, objets, argent… (à reporter sur la fiche)"),
                          axis: .vertical)
                    .lineLimit(1...4)
            }
            Stepper(value: $session.number, in: 0...9999) {
                Text("Numéro \(session.number)")
                    .font(.subheadline)
            }
            .fixedSize()
        }
        .textFieldStyle(.plain)
        .padding(12)
        .background(Color.tertiaryFill, in: RoundedRectangle(cornerRadius: 10))
        .padding(.top, 4)
    }

    private func detailField(_ title: LocalizedStringKey, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            field()
        }
    }

    // MARK: Boîte à outils

    @ViewBuilder
    private var formatControls: some View {
        styleMenu
        Button {
            controller.toggleList(.checklist)
        } label: {
            Label("Liste de tâches", systemImage: "checklist")
        }
        Button {
            citing = true
        } label: {
            Label("Citer une fiche", systemImage: "person.crop.circle.badge.plus")
        }
        // Ancrée au bouton : la bulle s'affiche quelle que soit la largeur de la session.
        .popover(isPresented: $citing) {
            ReferencePicker(journal: journal, initialQuery: controller.format.selectedText) { entry in
                controller.insertReference(to: entry)
            }
        }
        attachMenu
        moreMenu
    }

    /// Capsule de verre flottante, centrée en bas, au-dessus du clavier.
    private var toolbox: some View {
        HStack(spacing: sizeClass == .compact ? 20 : 26) {
            formatControls
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.bottom, 12)
    }

    private var styleMenu: some View {
        Menu {
            Picker("Style", selection: Binding(get: { controller.format.style }, set: { controller.setStyle($0) })) {
                ForEach(JournalText.Style.allCases, id: \.self) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.inline)
            Section {
                traitToggle("Gras", systemImage: "bold", trait: .bold, isOn: controller.format.bold)
                traitToggle("Italique", systemImage: "italic", trait: .italic, isOn: controller.format.italic)
                traitToggle("Souligné", systemImage: "underline", trait: .underline, isOn: controller.format.underline)
                traitToggle("Barré", systemImage: "strikethrough", trait: .strikethrough,
                            isOn: controller.format.strikethrough)
            }
            Section {
                Toggle(isOn: Binding(get: { controller.format.list == .bullet },
                                     set: { _ in controller.toggleList(.bullet) })) {
                    Label("Liste à puces", systemImage: "list.bullet")
                }
                Toggle(isOn: Binding(get: { controller.format.list == .checklist },
                                     set: { _ in controller.toggleList(.checklist) })) {
                    Label("Liste de tâches", systemImage: "checklist")
                }
            }
        } label: {
            Label("Mise en forme", systemImage: "textformat")
        }
    }

    private func traitToggle(_ title: LocalizedStringKey, systemImage: String, trait: JournalEditorController.Trait,
                             isOn: Bool) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: { _ in controller.toggle(trait) })) {
            Label(title, systemImage: systemImage)
        }
    }

    private var attachMenu: some View {
        Menu {
            Button("Croquis…", systemImage: "scribble") { promptingSketch = true }
            Button("Écriture manuscrite", systemImage: "pencil.and.scribble") {
                drawing = DrawingRequest(kind: .handwriting, title: "", isListed: false)
            }
            Divider()
            Button("Document depuis Fichiers…", systemImage: "folder") { importingFiles = true }
            Button("Photo…", systemImage: "photo.on.rectangle") { choosingPhotos = true }
        } label: {
            Label("Joindre", systemImage: "paperclip")
        }
    }

    private var moreMenu: some View {
        Menu {
            #if os(iOS)
            Toggle(isOn: $allowsScribble) {
                Label("Écriture au crayon en texte", systemImage: "applepencil.and.scribble")
            }
            Divider()
            #endif
            Button("Supprimer la session", systemImage: "trash", role: .destructive) {
                confirmingDelete = true
            }
        } label: {
            Label("Plus", systemImage: "ellipsis.circle")
        }
    }

    /// ⌘B, ⌘I, ⌘U, ⇧⌘L (liste de tâches), ⇧⌘K (citer).
    private var shortcuts: some View {
        Group {
            Button("Gras") { controller.toggle(.bold) }.keyboardShortcut("b")
            Button("Italique") { controller.toggle(.italic) }.keyboardShortcut("i")
            Button("Souligné") { controller.toggle(.underline) }.keyboardShortcut("u")
            Button("Liste de tâches") { controller.toggleList(.checklist) }.keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Citer") { citing = true }.keyboardShortcut("k", modifiers: [.command, .shift])
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private func connect() {
        controller.onChange = { scheduleSave() }
        controller.onOpen = { item in open(item) }
    }

    private func open(_ item: JournalTextItem) {
        switch item {
        case .reference(let uid):
            if let entry = journal.entry(uid: uid) { navigator?.open(.entry(entry)) }
        case .attachment(let uid):
            guard let document = journal.document(uid: uid) else { return }
            if document.isDrawing {
                drawing = DrawingRequest(kind: document.kind, title: document.title, isListed: document.isListed,
                                         document: document)
            } else {
                viewing = document
            }
        case .checkbox:
            break
        }
    }

    private func saveDrawing(_ request: DrawingRequest, _ result: DrawingResult) {
        if let document = request.document {
            document.data = result.data
            document.previewData = result.preview
            if request.kind == .sketch { document.title = result.title }
            controller.refreshAttachment(document.uid)
        } else {
            let document = journal.addDrawing(request.kind, title: result.title, data: result.data,
                                              preview: result.preview, isListed: request.isListed,
                                              session: session, in: context)
            controller.insertAttachment(document.uid)
        }
        saveNow()
    }

    private func attach(_ documents: [ImportedDocument]) {
        for imported in documents {
            let document = journal.addDocument(title: imported.title, contentType: imported.type, data: imported.data,
                                               session: session, in: context)
            controller.insertAttachment(document.uid)
        }
        saveNow()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    /// Enregistre le récit dans la session (hors de l'annulation de la fiche : le récit a la sienne).
    private func saveNow() {
        saveTask?.cancel()
        guard controller.host != nil, !session.isDeleted, session.modelContext != nil else { return }
        let text = controller.text
        guard text != lastSaved else { return }
        lastSaved = text
        let undo = context.undoManager
        undo?.disableUndoRegistration()
        session.apply(text)
        context.processPendingChanges()
        undo?.enableUndoRegistration()
    }
}

extension JournalText.Style {
    var title: LocalizedStringKey {
        switch self {
        case .title: "Titre"
        case .heading: "En-tête"
        case .subheading: "Sous-en-tête"
        case .body: "Corps"
        case .monospaced: "Monospace"
        }
    }
}

// MARK: - Citer une fiche

/// Choix de la fiche à citer : recherche dans le carnet, ou création d'une fiche au nom tapé.
struct ReferencePicker: View {
    let journal: Journal
    let onPick: (CodexEntry) -> Void

    @State private var query: String
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    init(journal: Journal, initialQuery: String, onPick: @escaping (CodexEntry) -> Void) {
        self.journal = journal
        self.onPick = onPick
        let trimmed = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        _query = State(initialValue: trimmed.contains("\n") ? "" : trimmed)
    }

    var body: some View {
        NavigationStack {
            List {
                if !trimmed.isEmpty {
                    Section("Nouvelle fiche") {
                        ForEach(CodexKind.allCases, id: \.self) { kind in
                            Button {
                                pick(journal.addEntry(named: trimmed, kind: kind, in: context))
                            } label: {
                                Label {
                                    Text("\(Text(kind.title).foregroundStyle(.secondary))  \(trimmed)")
                                } icon: {
                                    Image(systemName: kind.symbol)
                                }
                            }
                        }
                    }
                }
                ForEach(CodexKind.allCases, id: \.self) { kind in
                    let entries = matches(kind)
                    if !entries.isEmpty {
                        Section {
                            ForEach(entries) { entry in
                                Button {
                                    pick(entry)
                                } label: {
                                    CodexEntryRow(entry: entry)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Label(kind.pluralTitle, systemImage: kind.symbol)
                        }
                    }
                }
            }
            .overlay {
                if trimmed.isEmpty, (journal.entries ?? []).isEmpty {
                    ContentUnavailableView("Carnet vide", systemImage: "person.crop.rectangle.stack",
                                           description: Text("Tapez un nom pour créer une fiche (PNJ, lieu, indice…)."))
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                JournalSearchField(text: $query, prompt: "Nom d'une fiche", focus: $focused)
                    .onSubmit {
                        if let first = CodexKind.allCases.lazy.flatMap(matches).first { pick(first) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
            .navigationTitle("Citer une fiche")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        // Petite hauteur minimale : en paysage, le clavier réduit la bulle ; la liste défile.
        .frame(minWidth: 360, idealWidth: 380, minHeight: 240, idealHeight: 480)
    }

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func matches(_ kind: CodexKind) -> [CodexEntry] {
        let entries = journal.entries(of: kind)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { $0.name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    private func pick(_ entry: CodexEntry) {
        onPick(entry)
        dismiss()
    }
}

// MARK: - Nouveau croquis

/// Titre du croquis et classement dans les documents (oui par défaut), avant de dessiner.
struct SketchPrompt: View {
    let onCreate: (String, Bool) -> Void

    @State private var title = ""
    @State private var isListed = true
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Titre", text: $title, prompt: Text("Plan de l'auberge, carte du port…"))
                    .focused($focused)
                    .onSubmit(create)
                Toggle("Classer dans les documents", isOn: $isListed)
            }
            .formStyle(.grouped)
            .navigationTitle("Nouveau croquis")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dessiner", action: create)
                }
            }
        }
        .presentationDetents([.height(260)])
        .frame(minWidth: 380, minHeight: 200)
        .onAppear { focused = true }
    }

    private func create() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        onCreate(trimmed.isEmpty ? String(localized: "Croquis") : trimmed, isListed)
        dismiss()
    }
}

extension View {
    /// Éditeur de dessin : plein écran sur iPhone et iPad, grande feuille sur Mac.
    func drawingEditor(item: Binding<DrawingRequest?>,
                       onSave: @escaping (DrawingRequest, DrawingResult) -> Void) -> some View {
        #if os(iOS)
        fullScreenCover(item: item) { request in
            DrawingEditor(request: request) { onSave(request, $0) }
        }
        #else
        sheet(item: item) { request in
            DrawingEditor(request: request) { onSave(request, $0) }
        }
        #endif
    }
}
