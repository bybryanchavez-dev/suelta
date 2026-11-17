import Foundation

/// Frase breve de psicología que aparece al terminar de soltar una carta.
/// Todas vienen de libros, charlas o artículos de sus autores; están incluidas en la app
/// para que funcione sin internet y sin enviar nada fuera del Mac.
struct Quote: Equatable {
    let en: String
    let es: String
    let author: String
    let roleEN: String
    let roleES: String

    var text: String { Lang.current == .es ? es : en }
    var role: String { Lang.current == .es ? roleES : roleEN }
}

enum Quotes {
    // Autores
    private static func rogers(_ en: String, _ es: String) -> Quote { Quote(en: en, es: es, author: "Carl Rogers", roleEN: "psychologist", roleES: "psicólogo") }
    private static func brown(_ en: String, _ es: String) -> Quote { Quote(en: en, es: es, author: "Brené Brown", roleEN: "researcher and social worker", roleES: "investigadora y trabajadora social") }
    private static func david(_ en: String, _ es: String) -> Quote { Quote(en: en, es: es, author: "Susan David", roleEN: "psychologist", roleES: "psicóloga") }
    private static func kierkegaard(_ en: String, _ es: String) -> Quote { Quote(en: en, es: es, author: "Søren Kierkegaard", roleEN: "philosopher", roleES: "filósofo") }
    private static func fromm(_ en: String, _ es: String) -> Quote { Quote(en: en, es: es, author: "Erich Fromm", roleEN: "psychoanalyst", roleES: "psicoanalista") }
    private static func neff(_ en: String, _ es: String) -> Quote { Quote(en: en, es: es, author: "Kristin Neff", roleEN: "psychologist", roleES: "psicóloga") }

    static let acceptance = rogers("The curious paradox is that when I accept myself just as I am, then I can change.",
                                   "La curiosa paradoja es que cuando me acepto tal como soy, entonces puedo cambiar.")
    static let goodLife = rogers("The good life is a process, not a state of being.",
                                 "La buena vida es un proceso, no un estado del ser.")
    static let nameIt = Quote(en: "Name it to tame it.", es: "Nómbralo para domarlo.",
                              author: "Daniel J. Siegel", roleEN: "psychiatrist", roleES: "psiquiatra")
    static let mentionable = Quote(en: "Anything that's human is mentionable, and anything that is mentionable can be more manageable.",
                                   es: "Todo lo humano se puede nombrar, y lo que se puede nombrar se vuelve más manejable.",
                                   author: "Fred Rogers", roleEN: "children's educator", roleES: "educador infantil")
    static let frankl = Quote(en: "When we are no longer able to change a situation, we are challenged to change ourselves.",
                              es: "Cuando ya no podemos cambiar una situación, tenemos el desafío de cambiarnos a nosotros mismos.",
                              author: "Viktor Frankl", roleEN: "psychiatrist", roleES: "psiquiatra")
    static let brach = Quote(en: "The boundary to what we can accept is the boundary to our freedom.",
                             es: "El límite de lo que podemos aceptar es el límite de nuestra libertad.",
                             author: "Tara Brach", roleEN: "psychologist", roleES: "psicóloga")
    static let data = david("Emotions are data, not directives.", "Las emociones son información, no órdenes.")
    static let discomfort = david("Discomfort is the price of admission to a meaningful life.",
                                  "La incomodidad es el precio de entrada a una vida con sentido.")
    static let waves = Quote(en: "You can't stop the waves, but you can learn to surf.",
                             es: "No puedes detener las olas, pero puedes aprender a surfear.",
                             author: "Jon Kabat-Zinn", roleEN: "mindfulness researcher", roleES: "investigador de mindfulness")
    static let lerner = Quote(en: "Anger is a signal, and one worth listening to.",
                              es: "La ira es una señal, y vale la pena escucharla.",
                              author: "Harriet Lerner", roleEN: "psychologist", roleES: "psicóloga")
    static let rosenberg = Quote(en: "Every criticism, judgment, diagnosis, and expression of anger is the tragic expression of an unmet need.",
                                 es: "Toda crítica, juicio, diagnóstico y expresión de ira es la expresión trágica de una necesidad no satisfecha.",
                                 author: "Marshall Rosenberg", roleEN: "psychologist", roleES: "psicólogo")
    static let dizziness = kierkegaard("Anxiety is the dizziness of freedom.", "La angustia es el vértigo de la libertad.")
    static let backwards = kierkegaard("Life can only be understood backwards; but it must be lived forwards.",
                                       "La vida solo puede entenderse hacia atrás, pero debe vivirse hacia delante.")
    static let grief = Quote(en: "You will not \u{201C}get over\u{201D} the loss of a loved one; you will learn to live with it.",
                             es: "No vas a \u{201C}superar\u{201D} la pérdida de un ser querido; vas a aprender a vivir con ella.",
                             author: "Elisabeth Kübler-Ross & David Kessler", roleEN: "psychiatrist and grief expert", roleES: "psiquiatra y experto en duelo")
    static let parkes = Quote(en: "The pain of grief is just as much a part of life as the joy of love.",
                              es: "El dolor del duelo es tan parte de la vida como la alegría del amor.",
                              author: "Colin Murray Parkes", roleEN: "psychiatrist", roleES: "psiquiatra")
    static let jeffers = Quote(en: "Feel the fear and do it anyway.", es: "Siente el miedo y hazlo de todos modos.",
                               author: "Susan Jeffers", roleEN: "psychologist", roleES: "psicóloga")
    static let vulnerability = brown("Vulnerability is the birthplace of innovation, creativity and change.",
                                     "La vulnerabilidad es la cuna de la innovación, la creatividad y el cambio.")
    static let shame = brown("Shame is \u{201C}I am bad.\u{201D} Guilt is \u{201C}I did something bad.\u{201D}",
                             "La vergüenza dice \u{201C}soy malo\u{201D}. La culpa dice \u{201C}hice algo malo\u{201D}.")
    static let joy = brown("Joy is the most vulnerable emotion we experience.",
                           "La alegría es la emoción más vulnerable que experimentamos.")
    static let rest = brown("Let go of exhaustion as a status symbol and productivity as self-worth.",
                            "Suelta el agotamiento como símbolo de estatus y la productividad como medida de tu valor.")
    static let beatYourself = neff("Please do not beat yourself up for beating yourself up.",
                                   "Por favor, no te castigues por castigarte.")
    static let goodFriend = neff("At the most basic level, self-compassion simply requires being a good friend to ourselves.",
                                 "En lo más básico, la autocompasión solo requiere ser un buen amigo de uno mismo.")
    static let eger = Quote(en: "Suffering is universal. But victimhood is optional.",
                            es: "El sufrimiento es universal. Pero ser víctima es opcional.",
                            author: "Edith Eger", roleEN: "psychologist and Holocaust survivor", roleES: "psicóloga y sobreviviente del Holocausto")
    static let emmons = Quote(en: "Gratitude is an affirmation of goodness.", es: "La gratitud es una afirmación de lo bueno.",
                              author: "Robert Emmons", roleEN: "psychologist", roleES: "psicólogo")
    static let activity = fromm("Love is an activity, not a passive affect.", "El amor es una actividad, no un afecto pasivo.")
    static let mature = fromm("Immature love says: \u{201C}I love you because I need you.\u{201D} Mature love says: \u{201C}I need you because I love you.\u{201D}",
                              "El amor inmaduro dice: \u{201C}te amo porque te necesito\u{201D}. El amor maduro dice: \u{201C}te necesito porque te amo\u{201D}.")

    static let general: [Quote] = [acceptance, nameIt, mentionable, frankl, brach, data]

    static let byFeeling: [String: [Quote]] = [
        "estres": [waves, discomfort, nameIt],
        "enojo": [lerner, rosenberg, data],
        "ansiedad": [dizziness, waves, nameIt],
        "tristeza": [grief, parkes, discomfort],
        "miedo": [jeffers, vulnerability],
        "culpa": [shame, beatYourself, acceptance],
        "nostalgia": [backwards, parkes],
        "confusion": [goodLife, nameIt, backwards],
        "cansancio": [rest, goodFriend],
        "alegria": [joy, goodLife],
        "gratitud": [emmons, joy],
        "amor": [activity, mature, parkes],
        "alivio": [acceptance, brach],
        "esperanza": [eger, frankl],
    ]

    /// Elige una frase según lo que sentía la persona; si no marcó nada, una general.
    static func pick(for feelings: [String]) -> Quote {
        let pool = feelings.flatMap { byFeeling[$0] ?? [] }
        return (pool.isEmpty ? general : pool).randomElement() ?? acceptance
    }
}
