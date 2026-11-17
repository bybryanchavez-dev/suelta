import Foundation
import SwiftUI

// MARK: - Sentimientos

struct Feeling: Identifiable, Hashable {
    let id: String
    let nameES: String
    let color: Color
    let hue: Double
    var name: String { L(nameES) }

    init(_ id: String, _ name: String, hue: Double, sat: Double = 0.55, bri: Double = 0.85) {
        self.id = id
        self.nameES = name
        self.hue = hue
        self.color = Color(hue: hue, saturation: sat, brightness: bri)
    }

    static let all: [Feeling] = [
        Feeling("estres", "Estrés", hue: 0.07),
        Feeling("enojo", "Enojo", hue: 0.00, sat: 0.62),
        Feeling("ansiedad", "Ansiedad", hue: 0.76),
        Feeling("tristeza", "Tristeza", hue: 0.60),
        Feeling("miedo", "Miedo", hue: 0.66, sat: 0.30, bri: 0.62),
        Feeling("culpa", "Culpa", hue: 0.10, sat: 0.50, bri: 0.62),
        Feeling("nostalgia", "Nostalgia", hue: 0.88, sat: 0.35),
        Feeling("confusion", "Confusión", hue: 0.50, sat: 0.30, bri: 0.66),
        Feeling("cansancio", "Cansancio", hue: 0.58, sat: 0.08, bri: 0.62),
        Feeling("alegria", "Alegría", hue: 0.13, sat: 0.70, bri: 0.95),
        Feeling("gratitud", "Gratitud", hue: 0.34, sat: 0.50, bri: 0.72),
        Feeling("amor", "Amor", hue: 0.95, sat: 0.50, bri: 0.92),
        Feeling("alivio", "Alivio", hue: 0.45, sat: 0.45, bri: 0.80),
        Feeling("esperanza", "Esperanza", hue: 0.55, sat: 0.50, bri: 0.92),
    ]

    static func find(_ id: String) -> Feeling? { all.first { $0.id == id } }
}

// MARK: - Destinatarios sugeridos

enum Recipients {
    static var suggestions: [String] { suggestionsES.map { L($0) } }
    static let suggestionsES = [
        "Para mí", "Mi yo del pasado", "Mi ex", "Mi familia", "Mamá", "Papá",
        "Mi hermana", "Mi hermano", "Mi pareja", "Un amigo", "Dios", "Mi fe",
        "Mi psicólogo", "Alguien que ya no está", "Mi jefe", "El universo",
    ]
}

// MARK: - Carta

struct Letter: Codable, Identifiable, Equatable {
    var id = UUID()
    var created = Date()
    var updated = Date()
    var text = ""
    var feelings: [String] = []
    var audioFile: String?
    var audioDuration: Double = 0

    var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isEmpty: Bool { trimmed.isEmpty && audioFile == nil }
    var wordCount: Int { trimmed.split { $0.isWhitespace || $0.isNewline }.count }
    var firstHue: Double? { feelings.compactMap { Feeling.find($0)?.hue }.first }
}

/// Lo único que queda de una carta enviada al mar: su forma y dónde reposa. Nada de su contenido.
struct SunkenLetter: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var x: Double          // 0...1 a lo ancho del fondo
    var rotation: Double   // grados
    var scale: Double
    var hue: Double?

    static func random(hue: Double?) -> SunkenLetter {
        SunkenLetter(x: Double.random(in: 0.08...0.92),
                     rotation: Double.random(in: -28...28),
                     scale: Double.random(in: 0.5...0.7),
                     hue: hue)
    }
}

// MARK: - Destinos

enum Destination: String, CaseIterable, Identifiable {
    case plane, sea, trash
    var id: String { rawValue }

    var title: String {
        switch self {
        case .plane: return L("Que vuele")
        case .sea: return L("Al fondo del mar")
        case .trash: return L("A la papelera")
        }
    }

    var subtitle: String {
        switch self {
        case .plane: return L("Un avión de papel se la lleva lejos.")
        case .sea: return L("Se hunde y descansa con las demás. No se puede rescatar.")
        case .trash: return L("Se arruga y desaparece para siempre.")
        }
    }

    var symbol: String {
        switch self {
        case .plane: return "paperplane.fill"
        case .sea: return "water.waves"
        case .trash: return "trash.fill"
        }
    }

    var tint: Color {
        switch self {
        case .plane: return Color(red: 0.25, green: 0.56, blue: 0.95)
        case .sea: return Color(red: 0.10, green: 0.50, blue: 0.60)
        case .trash: return Color(red: 0.42, green: 0.43, blue: 0.47)
        }
    }

    var farewell: (String, String) {
        switch self {
        case .plane: return (L("Ya se fue."), L("Lo que escribiste vuela lejos de ti."))
        case .sea: return (L("Descansa en el fondo del mar."), L("Está ahí, pero ya no es tuyo para cargarlo."))
        case .trash: return (L("Ya no existe."), L("No queda ninguna copia."))
        }
    }
}

// MARK: - Almacén local (solo en este Mac)

@MainActor
final class LetterStore: ObservableObject {
    @Published private(set) var drafts: [Letter] = []
    @Published private(set) var seabed: [SunkenLetter] = []

    let dir: URL
    let audioDir: URL
    private var draftsURL: URL { dir.appendingPathComponent("cartas.json") }
    private var seabedURL: URL { dir.appendingPathComponent("fondo.json") }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("Suelta", isDirectory: true)
        audioDir = dir.appendingPathComponent("voz", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        load()
    }

    func audioURL(_ name: String) -> URL { audioDir.appendingPathComponent(name) }

    private func load() {
        let dec = JSONDecoder()
        if let d = try? Data(contentsOf: draftsURL), let v = try? dec.decode([Letter].self, from: d) {
            drafts = v.sorted { $0.updated > $1.updated }
        }
        if let d = try? Data(contentsOf: seabedURL), let v = try? dec.decode([SunkenLetter].self, from: d) {
            seabed = v
        }
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func save(_ letter: Letter) {
        var l = letter
        if l.isEmpty {
            if drafts.contains(where: { $0.id == l.id }) { discard(l.id, deleteAudio: false) }
            return
        }
        l.updated = Date()
        if let i = drafts.firstIndex(where: { $0.id == l.id }) {
            drafts[i] = l
        } else {
            drafts.insert(l, at: 0)
        }
        drafts.sort { $0.updated > $1.updated }
        write(drafts, to: draftsURL)
    }

    func discard(_ id: UUID, deleteAudio: Bool = true) {
        if deleteAudio, let l = drafts.first(where: { $0.id == id }), let a = l.audioFile {
            shred(audioURL(a))
        }
        drafts.removeAll { $0.id == id }
        write(drafts, to: draftsURL)
    }

    /// Borra la carta del disco. Si va al mar, deja solo su forma en el fondo.
    func release(_ letter: Letter, to destination: Destination) -> SunkenLetter? {
        if let a = letter.audioFile { shred(audioURL(a)) }
        drafts.removeAll { $0.id == letter.id }
        write(drafts, to: draftsURL)
        guard destination == .sea else { return nil }
        let s = SunkenLetter.random(hue: letter.firstHue)
        seabed.append(s)
        write(seabed, to: seabedURL)
        return s
    }

    /// Sobrescribe el archivo antes de borrarlo.
    func shred(_ url: URL) {
        if let h = try? FileHandle(forWritingTo: url) {
            let size = (try? h.seekToEnd()) ?? 0
            try? h.seek(toOffset: 0)
            if size > 0 { try? h.write(contentsOf: Data(count: Int(size))) }
            try? h.close()
        }
        try? FileManager.default.removeItem(at: url)
    }
}
