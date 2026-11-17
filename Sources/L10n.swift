import Foundation

// MARK: - Idioma de la app (español / inglés)

enum Lang: String, CaseIterable, Identifiable {
    case es, en
    var id: String { rawValue }

    static let defaultsKey = "appLanguage"

    /// Idioma activo. Lo fija el instalador o los Ajustes; si no, sigue al sistema.
    static var current: Lang = {
        if let raw = UserDefaults.standard.string(forKey: defaultsKey), let l = Lang(rawValue: raw) { return l }
        let sys = Locale.preferredLanguages.first ?? "es"
        return sys.hasPrefix("es") ? .es : .en
    }()

    var displayName: String {
        switch self {
        case .es: return "Español"
        case .en: return "English"
        }
    }

    var locale: Locale {
        switch self {
        case .es: return Locale(identifier: "es_ES")
        case .en: return Locale(identifier: "en_US")
        }
    }

    /// Idioma para el dictado: respeta la variante regional del sistema si coincide.
    var speechLocale: Locale {
        let preferred = Locale.preferredLanguages.first { $0.hasPrefix(rawValue) }
        return Locale(identifier: preferred ?? (self == .es ? "es-ES" : "en-US"))
    }
}

/// Traduce un texto escrito en español al idioma activo.
func L(_ es: String) -> String {
    guard Lang.current == .en else { return es }
    return english[es] ?? es
}

func LF(_ es: String, _ args: CVarArg...) -> String {
    String(format: L(es), arguments: args)
}

func wordsLabel(_ n: Int) -> String {
    switch Lang.current {
    case .es: return n == 1 ? "1 palabra" : "\(n) palabras"
    case .en: return n == 1 ? "1 word" : "\(n) words"
    }
}

private let english: [String: String] = [
    // Navegación
    "Escribir": "Write",
    "Sin enviar": "Unsent",
    "El fondo del mar": "The Seabed",
    "Todo se queda en este Mac. Lo que sueltas se borra.": "Everything stays on this Mac. What you let go is erased.",
    "Nueva carta": "New letter",
    "Nueva carta (⌘N)": "New letter (⌘N)",
    "Carta": "Letter",
    "Soltar…": "Let go…",
    "Dictar": "Dictate",
    "Dejar de dictar": "Stop dictating",
    "Parar": "Stop",
    "Ajustes": "Settings",

    // Escribir
    "¿Qué llevas dentro?": "What are you carrying?",
    "Escribe sin filtro. Nadie más va a leer esto.": "Write without a filter. No one else will read this.",
    "Te escucho…": "Listening…",
    "Nota de voz": "Voice note",
    "Borrar la nota de voz": "Delete the voice note",
    "Habla y se escribe (⌘D)": "Speak and it's written (⌘D)",
    "Graba un audio en lugar de escribir": "Record audio instead of writing",
    "Enviar": "Send",
    "Enviar…": "Send…",
    "Elegir para quién es y soltarla (⌘↩)": "Choose who it's for and let it go (⌘↩)",

    // Sin enviar
    "Nada pendiente": "Nothing pending",
    "Las cartas que empieces y no sueltes esperan aquí, para que puedas volver a leerlas.":
        "Letters you start and don't let go wait here, so you can read them again.",
    "Escribir una carta": "Write a letter",
    "Vuelve a leerlas. Cuando estés listo, suéltalas.": "Read them again. When you're ready, let them go.",
    "Ahora mismo": "Just now",
    "Abrir": "Open",
    "Borrar sin enviar": "Delete without sending",

    // Enviar
    "¿Para quién es?": "Who is it for?",
    "Escríbelo como te salga. Nadie lo va a recibir.": "Write it however it comes out. No one will receive it.",
    "Para…": "To…",
    "Para: %@": "To: %@",
    "Cancelar": "Cancel",
    "Siguiente": "Next",
    "Atrás": "Back",
    "¿Cómo quieres soltarla?": "How do you want to let it go?",
    "Se borra de este Mac. No queda ninguna copia.": "It's erased from this Mac. No copy remains.",
    "Se borra de este Mac. Solo queda su silueta en el fondo, sin palabras.":
        "It's erased from this Mac. Only its silhouette remains on the seabed, with no words.",
    "Mantén pulsado para soltar": "Press and hold to let go",
    "Soltar la carta": "Let the letter go",

    // Destinos
    "Que vuele": "Let it fly",
    "Al fondo del mar": "To the bottom of the sea",
    "A la papelera": "To the trash",
    "Un avión de papel se la lleva lejos.": "A paper plane carries it far away.",
    "Se hunde y descansa con las demás. No se puede rescatar.": "It sinks and rests with the others. It can't be recovered.",
    "Se arruga y desaparece para siempre.": "It's crumpled up and gone for good.",
    "Ya se fue.": "It's gone.",
    "Lo que escribiste vuela lejos de ti.": "What you wrote is flying far away from you.",
    "Descansa en el fondo del mar.": "It rests at the bottom of the sea.",
    "Está ahí, pero ya no es tuyo para cargarlo.": "It's there, but it's no longer yours to carry.",
    "Ya no existe.": "It no longer exists.",
    "No queda ninguna copia.": "No copy remains.",
    "Listo": "Done",

    // Fondo del mar
    "Aún no hay nada aquí. Lo que envíes al mar vendrá a descansar a este lugar.":
        "Nothing here yet. What you send to the sea will come to rest in this place.",
    "Una carta descansa aquí. No se puede rescatar.": "One letter rests here. It can't be recovered.",
    "%d cartas descansan aquí. No se pueden rescatar.": "%d letters rest here. They can't be recovered.",

    // Ajustes
    "Idioma": "Language",
    "Mostrar una frase al soltar": "Show a quote after letting go",
    "Al soltar una carta verás una frase breve de psicología según lo que sentías.":
        "After letting a letter go you'll see a short psychology quote based on what you were feeling.",
    "El dictado también usa este idioma.": "Dictation also uses this language.",

    // Avisos de audio
    "Activa el reconocimiento de voz para Suelta en Ajustes del Sistema › Privacidad y seguridad.":
        "Turn on Speech Recognition for Suelta in System Settings › Privacy & Security.",
    "Activa el micrófono para Suelta en Ajustes del Sistema › Privacidad y seguridad.":
        "Turn on the Microphone for Suelta in System Settings › Privacy & Security.",
    "El dictado no está disponible ahora mismo.": "Dictation isn't available right now.",
    "No pude usar el micrófono.": "I couldn't use the microphone.",
    "No pude empezar a grabar.": "I couldn't start recording.",

    // Sentimientos
    "Estrés": "Stress", "Enojo": "Anger", "Ansiedad": "Anxiety", "Tristeza": "Sadness",
    "Miedo": "Fear", "Culpa": "Guilt", "Nostalgia": "Nostalgia", "Confusión": "Confusion",
    "Cansancio": "Exhaustion", "Alegría": "Joy", "Gratitud": "Gratitude", "Amor": "Love",
    "Alivio": "Relief", "Esperanza": "Hope",

    // Destinatarios
    "Para mí": "Myself", "Mi yo del pasado": "My past self", "Mi ex": "My ex",
    "Mi familia": "My family", "Mamá": "Mom", "Papá": "Dad", "Mi hermana": "My sister",
    "Mi hermano": "My brother", "Mi pareja": "My partner", "Un amigo": "A friend",
    "Dios": "God", "Mi fe": "My faith", "Mi psicólogo": "My therapist",
    "Alguien que ya no está": "Someone who's gone", "Mi jefe": "My boss", "El universo": "The universe",
]
