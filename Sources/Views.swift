import AppKit
import SwiftUI

// MARK: - Paleta

enum Palette {
    static func dynamic(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
    static let canvas = dynamic(NSColor(red: 0.955, green: 0.945, blue: 0.925, alpha: 1),
                                NSColor(red: 0.105, green: 0.105, blue: 0.115, alpha: 1))
    static let paper = dynamic(NSColor(red: 1.0, green: 0.997, blue: 0.988, alpha: 1),
                               NSColor(red: 0.165, green: 0.165, blue: 0.175, alpha: 1))
    static let ink = dynamic(NSColor(white: 0.13, alpha: 1), NSColor(white: 0.92, alpha: 1))
    static let hairline = dynamic(NSColor(white: 0, alpha: 0.07), NSColor(white: 1, alpha: 0.08))
}


func longDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Lang.current.locale
    f.dateFormat = Lang.current == .es ? "EEEE, d 'de' MMMM" : "EEEE, MMMM d"
    let s = f.string(from: d)
    return s.prefix(1).uppercased() + s.dropFirst()
}

func relativeDate(_ d: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.locale = Lang.current.locale
    f.unitsStyle = .full
    f.dateTimeStyle = .named
    let now = Date()
    if now.timeIntervalSince(d) < 60 { return L("Ahora mismo") }
    return f.localizedString(for: min(d, now), relativeTo: now)
}

// MARK: - Raíz

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: LetterStore

    var body: some View {
        ZStack {
            NavigationSplitView {
                Sidebar()
                    .navigationSplitViewColumnWidth(min: 190, ideal: 212, max: 260)
            } detail: {
                Group {
                    switch model.section {
                    case .write: ComposeView(dictation: model.dictation, recorder: model.recorder)
                    case .drafts: DraftsView()
                    case .sea: SeabedView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            }
            .toolbar(model.ceremony == nil ? .visible : .hidden, for: .windowToolbar)

            if let c = model.ceremony {
                CeremonyView(ceremony: c) { model.endCeremony() }
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $model.showSend) {
            SendSheet().environmentObject(model)
        }
        .id(model.language)
    }
}

// MARK: - Barra lateral

struct Sidebar: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: LetterStore

    var body: some View {
        let selection = Binding<Section?>(get: { model.section }, set: { if let s = $0 { model.section = s } })
        List(selection: selection) {
            Label(L("Escribir"), systemImage: "square.and.pencil")
                .tag(Section.write)
            Label(L("Sin enviar"), systemImage: "tray")
                .badge(store.drafts.count)
                .tag(Section.drafts)
            Label(L("El fondo del mar"), systemImage: "water.waves")
                .badge(store.seabed.count)
                .tag(Section.sea)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.top, 2)
                Text(L("Todo se queda en este Mac. Lo que sueltas se borra."))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Escribir

struct ComposeView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var dictation: Dictation
    @ObservedObject var recorder: VoiceRecorder
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(longDate(model.current.created))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(L("¿Qué llevas dentro?"))
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.ink)
            }
            .padding(.bottom, 16)

            FeelingPicker(selection: $model.current.feelings)
                .padding(.bottom, 18)

            paper
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, 40)
        .padding(.top, 24)
        .padding(.bottom, 92)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.canvas.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let m = dictation.message ?? recorder.message {
                    Text(m)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .glassEffect(.regular, in: .capsule)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                }
                ComposeBar(dictation: dictation, recorder: recorder)
            }
            .padding(.bottom, 20)
            .animation(.easeOut(duration: 0.2), value: dictation.message ?? recorder.message)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.newLetter() } label: {
                    Label(L("Nueva carta"), systemImage: "square.and.pencil")
                }
                .help(L("Nueva carta (⌘N)"))
            }
        }
        .onAppear { editorFocused = true }
        .onChange(of: model.current.id) { editorFocused = true }
    }

    private var paper: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.current.audioFile != nil {
                VoiceNoteChip(recorder: recorder)
            }
            ZStack(alignment: .topLeading) {
                if model.current.text.isEmpty && !dictation.isRunning {
                    Text(L("Escribe sin filtro. Nadie más va a leer esto."))
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $model.current.text)
                    .font(.system(size: 18, design: .serif))
                    .lineSpacing(7)
                    .foregroundStyle(Palette.ink)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .focused($editorFocused)
            }
            if dictation.isRunning || !dictation.partial.isEmpty {
                DictationLive(dictation: dictation)
                    .transition(.opacity.combined(with: .offset(y: 4)))
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.paper)
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.07), radius: 28, y: 14)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 0.5)
        }
        .animation(.easeOut(duration: 0.2), value: dictation.isRunning)
        .animation(.easeOut(duration: 0.2), value: model.current.audioFile)
    }
}

struct FeelingPicker: View {
    @Binding var selection: [String]

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(Feeling.all) { f in
                let on = selection.contains(f.id)
                Button {
                    if on { selection.removeAll { $0 == f.id } } else { selection.append(f.id) }
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(f.color).frame(width: 7, height: 7)
                        Text(f.name)
                            .font(.system(size: 12.5, weight: on ? .semibold : .regular))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .foregroundStyle(on ? Palette.ink : .secondary)
                    .background(Capsule().fill(on ? f.color.opacity(0.20) : Color.primary.opacity(0.045)))
                    .overlay(Capsule().strokeBorder(on ? f.color.opacity(0.55) : .clear, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .animation(.easeOut(duration: 0.15), value: on)
            }
        }
    }
}

struct DictationLive: View {
    @ObservedObject var dictation: Dictation

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(0.8 + CGFloat(dictation.level) * 0.7)
                .animation(.easeOut(duration: 0.1), value: dictation.level)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
            Text(dictation.partial.isEmpty ? L("Te escucho…") : dictation.partial)
                .font(.system(size: 16, design: .serif).italic())
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 1) }
    }
}

struct VoiceNoteChip: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var recorder: VoiceRecorder
    private let bars: [CGFloat] = (0..<34).map { i in 0.25 + 0.75 * abs(sin(Double(i) * 1.7) * cos(Double(i) * 0.6)) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if let f = model.current.audioFile { recorder.togglePlay(model.store.audioURL(f)) }
            } label: {
                Image(systemName: recorder.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Destination.plane.tint))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressableStyle())

            HStack(alignment: .center, spacing: 2.5) {
                ForEach(bars.indices, id: \.self) { i in
                    Capsule()
                        .fill(Color.primary.opacity(0.35))
                        .frame(width: 2.5, height: 4 + 16 * bars[i] * (recorder.isPlaying ? CGFloat(0.5 + recorder.level) : 1))
                }
            }
            .frame(height: 24)
            .animation(.easeOut(duration: 0.1), value: recorder.level)

            Text(recorder.isPlaying ? formatDuration(recorder.elapsed) : formatDuration(model.current.audioDuration))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button { model.deleteVoiceNote() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(PressableStyle())
            .help(L("Borrar la nota de voz"))
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: 380)
        .background(Capsule().fill(Color.primary.opacity(0.045)))
    }
}

struct ComposeBar: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var dictation: Dictation
    @ObservedObject var recorder: VoiceRecorder

    var body: some View {
        HStack(spacing: 4) {
            BarButton(symbol: dictation.isRunning ? "mic.fill" : "mic",
                      title: dictation.isRunning ? L("Parar") : L("Dictar"),
                      tint: .red, active: dictation.isRunning) {
                if recorder.isRecording { model.toggleRecording() }
                dictation.toggle()
            }
            .help(L("Habla y se escribe (⌘D)"))

            BarButton(symbol: recorder.isRecording ? "stop.fill" : "waveform",
                      title: recorder.isRecording ? formatDuration(recorder.elapsed) : L("Nota de voz"),
                      tint: .red, active: recorder.isRecording) {
                model.toggleRecording()
            }
            .help(L("Graba un audio en lugar de escribir"))

            Rectangle().fill(Palette.hairline).frame(width: 1, height: 18).padding(.horizontal, 6)

            Text(wordLabel)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 70)
                .contentTransition(.numericText())

            Button { model.beginSend() } label: {
                Label(L("Enviar"), systemImage: "paperplane.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(model.current.isEmpty)
            .help(L("Elegir para quién es y soltarla (⌘↩)"))
        }
        .padding(.leading, 6)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }

    private var wordLabel: String {
        let n = model.current.wordCount
        return wordsLabel(n)
    }
}

struct BarButton: View {
    let symbol: String
    let title: String
    var tint: Color = .accentColor
    var active = false
    let action: () -> Void
    @Local private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(active ? tint : Palette.ink)
                    .symbolEffect(.pulse, isActive: active)
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(active ? tint : Palette.ink)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(active ? tint.opacity(0.13) : (hover ? Color.primary.opacity(0.07) : .clear)))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
        .animation(.easeOut(duration: 0.2), value: active)
    }
}

// MARK: - Sin enviar

struct DraftsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: LetterStore

    var body: some View {
        Group {
            if store.drafts.isEmpty {
                ContentUnavailableView {
                    Label(L("Nada pendiente"), systemImage: "tray")
                } description: {
                    Text(L("Las cartas que empieces y no sueltes esperan aquí, para que puedas volver a leerlas."))
                } actions: {
                    Button(L("Escribir una carta")) { model.newLetter() }
                        .buttonStyle(.glass)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Sin enviar"))
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                        Text(L("Vuelve a leerlas. Cuando estés listo, suéltalas."))
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 18)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 16)],
                                  alignment: .leading, spacing: 16) {
                            ForEach(store.drafts) { d in DraftCard(letter: d) }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 28)
                    .frame(maxWidth: 1100, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.canvas.ignoresSafeArea())
    }
}

struct DraftCard: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: LetterStore
    let letter: Letter
    @Local private var hover = false

    var body: some View {
        Button { model.open(letter) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(letter.feelings.prefix(5), id: \.self) { id in
                        if let f = Feeling.find(id) { Circle().fill(f.color).frame(width: 7, height: 7) }
                    }
                    Spacer()
                    Text(relativeDate(letter.updated))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Text(letter.trimmed.isEmpty ? "Nota de voz" : letter.trimmed)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(3)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Text(wordsLabel(letter.wordCount))
                    if letter.audioFile != nil {
                        Label(formatDuration(letter.audioDuration), systemImage: "waveform")
                    }
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(height: 190, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.paper)
                    .shadow(color: .black.opacity(hover ? 0.10 : 0.05), radius: hover ? 18 : 8, y: hover ? 8 : 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.5)
            }
            .offset(y: hover ? -2 : 0)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.2), value: hover)
        .contextMenu {
            Button(L("Abrir")) { model.open(letter) }
            Button(L("Enviar…")) { model.open(letter); model.beginSend() }
            Divider()
            Button(L("Borrar sin enviar"), role: .destructive) { store.discard(letter.id) }
        }
    }
}

// MARK: - Enviar

struct SendSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Local private var step = 0
    @Local private var recipient = ""
    @Local private var destination: Destination = .plane
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            if step == 0 {
                recipientStep
                    .transition(.blurReplace.combined(with: .offset(x: -16)))
            } else {
                destinationStep
                    .transition(.blurReplace.combined(with: .offset(x: 16)))
            }
        }
        .animation(.smooth(duration: 0.3), value: step)
        .padding(30)
        .frame(width: 600)
    }

    private var recipientStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("¿Para quién es?"))
                .font(.system(size: 26, weight: .semibold, design: .serif))
            Text(L("Escríbelo como te salga. Nadie lo va a recibir."))
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            TextField(L("Para…"), text: $recipient)
                .textFieldStyle(.plain)
                .font(.system(size: 22, design: .serif))
                .focused($fieldFocused)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
                .padding(.top, 20)
                .onSubmit { next() }

            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(Recipients.suggestions, id: \.self) { s in
                    let on = recipient == s
                    Button { recipient = s } label: {
                        Text(s)
                            .font(.system(size: 12.5, weight: on ? .semibold : .regular))
                            .padding(.horizontal, 11)
                            .frame(height: 27)
                            .foregroundStyle(on ? Color.white : Palette.ink)
                            .background(Capsule().fill(on ? Color.accentColor : Color.primary.opacity(0.055)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .animation(.easeOut(duration: 0.15), value: on)
                }
            }
            .padding(.top, 16)

            HStack {
                Button(L("Cancelar")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                Spacer()
                Button(L("Siguiente")) { next() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(cleanRecipient.isEmpty)
            }
            .padding(.top, 28)
        }
        .onAppear { fieldFocused = true }
    }

    private var destinationStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { step = 0 } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                    Text(LF("Para: %@", cleanRecipient))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            Text(L("¿Cómo quieres soltarla?"))
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .padding(.top, 10)

            HStack(spacing: 12) {
                ForEach(Destination.allCases) { d in
                    DestinationTile(destination: d, selected: d == destination) { destination = d }
                }
            }
            .padding(.top, 20)

            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 10, weight: .semibold))
                Text(destination == .sea
                     ? L("Se borra de este Mac. Solo queda su silueta en el fondo, sin palabras.")
                     : L("Se borra de este Mac. No queda ninguna copia."))
                    .contentTransition(.opacity)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .animation(.easeOut(duration: 0.2), value: destination)

            HStack {
                Button(L("Atrás")) { step = 0 }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                Spacer()
                HoldButton(title: L("Mantén pulsado para soltar"), tint: destination.tint) {
                    let d = destination
                    let r = cleanRecipient
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        model.release(to: d, recipient: r)
                    }
                }
            }
            .padding(.top, 26)
        }
    }

    private var cleanRecipient: String { recipient.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func next() {
        guard !cleanRecipient.isEmpty else { return }
        step = 1
    }
}

struct DestinationTile: View {
    let destination: Destination
    let selected: Bool
    let action: () -> Void
    @Local private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(selected ? .white : destination.tint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(selected ? destination.tint : destination.tint.opacity(0.14)))
                Text(destination.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(destination.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? destination.tint.opacity(0.09) : Color.primary.opacity(hover ? 0.06 : 0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? destination.tint : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.18), value: selected)
        .animation(.easeOut(duration: 0.15), value: hover)
    }
}

/// Botón que hay que mantener pulsado: soltar algo debe ser un gesto deliberado.
struct HoldButton: View {
    let title: String
    let tint: Color
    let action: () -> Void
    @Local private var pressing = false
    private let duration = 1.2

    var body: some View {
        ZStack {
            label(fg: tint, bg: tint.opacity(0.14))
            label(fg: .white, bg: tint)
                .mask(alignment: .leading) {
                    Rectangle().scaleEffect(x: pressing ? 1 : 0.001, anchor: .leading)
                }
        }
        .frame(width: 270, height: 40)
        .clipShape(Capsule())
        .scaleEffect(pressing ? 0.98 : 1)
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: duration, maximumDistance: 60) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            pressing = false
            action()
        } onPressingChanged: { p in
            withAnimation(p ? .linear(duration: duration) : .easeOut(duration: 0.2)) { pressing = p }
        }
        .accessibilityElement()
        .accessibilityLabel(L("Soltar la carta"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }

    private func label(fg: Color, bg: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.tap.fill").font(.system(size: 12, weight: .semibold))
            Text(title).font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(fg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bg)
    }
}

// MARK: - Papel para la animación (siempre claro, como una hoja de verdad)

struct LetterPaper: View {
    let letter: Letter
    let recipient: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text(LF("Para: %@", recipient))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(white: 0.38))
                Spacer()
                ForEach(letter.feelings.prefix(5), id: \.self) { id in
                    if let f = Feeling.find(id) { Circle().fill(f.color).frame(width: 7, height: 7) }
                }
            }
            Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1)
            if !letter.trimmed.isEmpty {
                Text(String(letter.trimmed.prefix(900)))
                    .font(.system(size: 15, design: .serif))
                    .lineSpacing(5)
                    .foregroundColor(Color(white: 0.16))
                    .lineLimit(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if letter.audioFile != nil {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                    Text(L("Nota de voz") + " · " + formatDuration(letter.audioDuration))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(white: 0.45))
            }
        }
        .padding(32)
        .frame(width: 520, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(red: 1, green: 0.995, blue: 0.982)))
    }
}

// MARK: - Utilidades de interfaz

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW {
                y += lineH + lineSpacing
                x = 0
                lineH = 0
            }
            x += s.width + spacing
            lineH = max(lineH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > bounds.width {
                y += lineH + lineSpacing
                x = 0
                lineH = 0
            }
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
    }
}

/// Estado local de una vista. Equivale a @State, pero sin depender del plugin de macros de SwiftUI,
/// que no viene con las Command Line Tools.
@propertyWrapper
struct Local<Value>: DynamicProperty {
    private var storage: SwiftUI.State<Value>
    init(wrappedValue: Value) { storage = SwiftUI.State(initialValue: wrappedValue) }
    var wrappedValue: Value {
        get { storage.wrappedValue }
        nonmutating set { storage.wrappedValue = newValue }
    }
    var projectedValue: Binding<Value> { storage.projectedValue }
}
