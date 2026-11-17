import AppKit
import SwiftUI

@main
struct SueltaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Suelta", id: "main") {
            RootView()
                .environmentObject(model)
                .environmentObject(model.store)
                .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1080, height: 740)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(L("Ajustes") + "…") { openSettingsWindow() }
                    .keyboardShortcut(",")
            }
            CommandGroup(replacing: .newItem) {
                Button(L("Nueva carta")) { model.newLetter() }
                    .keyboardShortcut("n")
            }
            CommandMenu(L("Carta")) {
                Button(L("Soltar…")) { model.beginSend() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.current.isEmpty)
                Button(model.dictation.isRunning ? L("Dejar de dictar") : L("Dictar")) { model.dictation.toggle() }
                    .keyboardShortcut("d")
                Divider()
                Button(L("Sin enviar")) { model.section = .drafts }
                    .keyboardShortcut("2")
                Button(L("El fondo del mar")) { model.section = .sea }
                    .keyboardShortcut("3")
            }
        }
    }
}

@MainActor
func openSettingsWindow() {
    SettingsWindow.shared.show()
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

enum Section: Hashable { case write, drafts, sea }

struct Ceremony: Identifiable {
    let id = UUID()
    let destination: Destination
    let quote: Quote?
    let paper: Image
    let paperSize: CGSize
    let seabed: [SunkenLetter]
    let newSunken: SunkenLetter?
    let start = Date()
}

@MainActor
final class AppModel: ObservableObject {
    let store = LetterStore()
    let dictation = Dictation()
    let recorder = VoiceRecorder()

    @Published var section: Section = .write {
        didSet { if section != oldValue { flush() } }
    }
    @Published var current = Letter() {
        didSet { if current != oldValue { scheduleSave() } }
    }
    @Published var showSend = false
    @Published var language: Lang = Lang.current {
        didSet {
            Lang.current = language
            UserDefaults.standard.set(language.rawValue, forKey: Lang.defaultsKey)
            // Los menús del sistema (Salir, Ocultar…) cambian en el próximo arranque.
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
            SettingsWindow.shared.refreshTitle()
        }
    }
    @Published var showQuotes: Bool = UserDefaults.standard.object(forKey: "showQuotes") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showQuotes, forKey: "showQuotes") }
    }
    @Published var ceremony: Ceremony?

    private var pendingSave: DispatchWorkItem?

    init() {
        SettingsWindow.shared.model = self
        dictation.onCommit = { [weak self] text in self?.appendDictated(text) }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopAudio()
                self?.flush()
            }
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let snapshot = current
        let work = DispatchWorkItem { [weak self] in self?.store.save(snapshot) }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func flush() {
        pendingSave?.cancel()
        store.save(current)
    }

    func appendDictated(_ text: String) {
        var t = current.text
        if !t.isEmpty && !t.hasSuffix(" ") && !t.hasSuffix("\n") { t += " " }
        current.text = t + text
    }

    func newLetter() {
        stopAudio()
        flush()
        current = Letter()
        section = .write
    }

    func open(_ letter: Letter) {
        stopAudio()
        flush()
        current = letter
        section = .write
    }

    func beginSend() {
        guard !current.isEmpty else { return }
        stopAudio()
        section = .write
        showSend = true
    }

    func stopAudio() {
        if dictation.isRunning { dictation.stop() }
        if recorder.isRecording { finishRecording() }
        if recorder.isPlaying { recorder.stopPlayback() }
    }

    // Nota de voz
    func toggleRecording() {
        if recorder.isRecording { finishRecording(); return }
        if dictation.isRunning { dictation.stop() }
        recorder.start(in: store.audioDir) { _ in }
    }

    private func finishRecording() {
        guard let (file, duration) = recorder.stop() else { return }
        if duration < 0.6 { store.shred(store.audioURL(file)); return }
        if let old = current.audioFile { store.shred(store.audioURL(old)) }
        current.audioFile = file
        current.audioDuration = duration
    }

    func deleteVoiceNote() {
        recorder.stopPlayback()
        if let f = current.audioFile { store.shred(store.audioURL(f)) }
        current.audioFile = nil
        current.audioDuration = 0
    }

    // Soltar
    func release(to destination: Destination, recipient: String) {
        pendingSave?.cancel()
        stopAudio()
        let letter = current
        let paperView = LetterPaper(letter: letter, recipient: recipient)
        let renderer = ImageRenderer(content: paperView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let ns = renderer.nsImage ?? NSImage(size: NSSize(width: 520, height: 400))
        let previous = store.seabed
        let sunken = store.release(letter, to: destination)
        current = Letter()
        pendingSave?.cancel()
        ceremony = Ceremony(destination: destination,
                            quote: showQuotes ? Quotes.pick(for: letter.feelings) : nil,
                            paper: Image(nsImage: ns),
                            paperSize: ns.size,
                            seabed: previous,
                            newSunken: sunken)
    }

    func endCeremony() {
        let wasSea = ceremony?.destination == .sea
        withAnimation(.easeOut(duration: 0.35)) { ceremony = nil }
        section = wasSea ? .sea : .write
    }
}
