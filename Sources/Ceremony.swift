import AppKit
import SwiftUI

// MARK: - Matemática de animación

@inline(__always) func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
@inline(__always) func seg(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp01((t - a) / (b - a)) }
@inline(__always) func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 4) }
@inline(__always) func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
@inline(__always) func mix(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }
@inline(__always) func mixP(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint { CGPoint(x: mix(a.x, b.x, t), y: mix(a.y, b.y, t)) }

func cubic(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: Double) -> CGPoint {
    let u = CGFloat(1 - t), tt = CGFloat(t)
    let a = u * u * u, b = 3 * u * u * tt, c = 3 * u * tt * tt, d = tt * tt * tt
    return CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x, y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
}

func cubicAngle(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: Double) -> Double {
    let u = CGFloat(1 - t), tt = CGFloat(t)
    let dx = 3 * u * u * (p1.x - p0.x) + 6 * u * tt * (p2.x - p1.x) + 3 * tt * tt * (p3.x - p2.x)
    let dy = 3 * u * u * (p1.y - p0.y) + 6 * u * tt * (p2.y - p1.y) + 3 * tt * tt * (p3.y - p2.y)
    return Double(atan2(dy, dx))
}

/// Números pseudoaleatorios deterministas (la misma escena en cada fotograma).
struct Rand {
    var state: UInt64
    init(_ seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
}

struct RGB {
    var r: Double, g: Double, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    init(hex: UInt32) { r = Double((hex >> 16) & 0xFF) / 255; g = Double((hex >> 8) & 0xFF) / 255; b = Double(hex & 0xFF) / 255 }
    func mixed(_ o: RGB, _ t: Double) -> RGB { RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t) }
    func color(_ a: Double = 1) -> Color { Color(red: r, green: g, blue: b).opacity(a) }
}

// MARK: - Avión de papel

enum PlanePainter {
    static let wingTop = RGB(hex: 0xFFFFFF)
    static let wingLow = RGB(hex: 0xDDE4EC)
    static let keel = RGB(hex: 0xB4C0CD)
    static let water = RGB(hex: 0x6FA6B5)

    /// Avión que apunta hacia +x, centrado en `p`. `underwater` lo tiñe del color del agua.
    static func draw(_ ctx: GraphicsContext, at p: CGPoint, angle: Double, length L: CGFloat,
                     alpha: Double = 1, underwater: Double = 0, hue: Double? = nil, shadow: Bool = true) {
        var c = ctx
        c.opacity = alpha
        if shadow {
            c.addFilter(.shadow(color: .black.opacity(0.16 * (1 - underwater)), radius: 9, x: 0, y: 7))
        }
        c.drawLayer { l in
            l.translateBy(x: p.x, y: p.y)
            l.rotate(by: .radians(angle))
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * L, y: y * L) }
            let N = pt(0.5, 0), A = pt(-0.5, -0.30), B = pt(-0.40, 0.20), C = pt(-0.26, 0.03), K = pt(-0.16, 0.14)

            var tint = water
            if let hue {
                let ns = NSColor(hue: hue, saturation: 0.35, brightness: 0.95, alpha: 1)
                tint = RGB(Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent))
            }
            let u = underwater * 0.55
            let top = wingTop.mixed(tint, u * (hue == nil ? 1 : 0.7))
            let low = wingLow.mixed(tint, u)
            let kc = keel.mixed(tint, u)

            var keelP = Path(); keelP.move(to: N); keelP.addLine(to: K); keelP.addLine(to: C); keelP.closeSubpath()
            var lowP = Path(); lowP.move(to: N); lowP.addLine(to: C); lowP.addLine(to: B); lowP.closeSubpath()
            var topP = Path(); topP.move(to: N); topP.addLine(to: A); topP.addLine(to: C); topP.closeSubpath()

            l.fill(keelP, with: .color(kc.color()))
            l.fill(lowP, with: .color(low.color()))
            l.fill(topP, with: .linearGradient(Gradient(colors: [top.color(), top.mixed(low, 0.35).color()]),
                                               startPoint: N, endPoint: A))
            let edge = Color.black.opacity(0.10)
            l.stroke(topP, with: .color(edge), lineWidth: 0.7)
            l.stroke(lowP, with: .color(edge), lineWidth: 0.7)
            var fold = Path(); fold.move(to: N); fold.addLine(to: C)
            l.stroke(fold, with: .color(Color.black.opacity(0.14)), lineWidth: 0.9)
        }
    }
}

// MARK: - El mar (compartido entre la animación y la vista del fondo)

struct SeaPainter {
    let W: CGFloat
    let H: CGFloat
    let t: Double
    let dark: Bool

    var surfaceY: CGFloat { H * 0.66 }
    var sandBase: CGFloat { H * 1.84 }
    var bottom: CGFloat { H * 2.4 }
    /// Desplazamiento de cámara en el que se ve el fondo completo.
    var seabedCamera: CGFloat { H * 1.06 }

    func sandY(_ x: CGFloat) -> CGFloat { sandBase + 10 * sin(x * 0.006 + 1.3) + 6 * sin(x * 0.017 + 0.4) }

    func waveY(_ x: CGFloat, phase: Double = 0, amp: CGFloat = 1) -> CGFloat {
        let a = sin(Double(x) * 0.013 + t * 1.3 + phase) * 5
        let b = sin(Double(x) * 0.031 - t * 0.8 + phase * 1.7) * 3
        return surfaceY + CGFloat(a + b) * amp
    }

    func drawSky(_ ctx: GraphicsContext) {
        let top = dark ? RGB(hex: 0x0B1526) : RGB(hex: 0xC9DDEE)
        let mid = dark ? RGB(hex: 0x1B2740) : RGB(hex: 0xE6E6E4)
        let hor = dark ? RGB(hex: 0x33405C) : RGB(hex: 0xF6E2CE)
        let rect = CGRect(x: 0, y: -H, width: W, height: surfaceY + H + 20)
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(stops: [.init(color: top.color(), location: 0),
                             .init(color: top.color(), location: 0.35),
                             .init(color: mid.color(), location: 0.75),
                             .init(color: hor.color(), location: 1)]),
            startPoint: CGPoint(x: 0, y: -H), endPoint: CGPoint(x: 0, y: surfaceY)))
        // Resplandor del sol (o la luna) en el horizonte
        var g = ctx
        g.addFilter(.blur(radius: 40))
        let sun = CGRect(x: W * 0.68 - 90, y: surfaceY - 120, width: 180, height: 180)
        g.fill(Path(ellipseIn: sun), with: .color(dark ? Color.white.opacity(0.10) : Color(red: 1, green: 0.86, blue: 0.70).opacity(0.75)))
    }

    func drawWater(_ ctx: GraphicsContext) {
        let shallow = dark ? RGB(hex: 0x1C5568) : RGB(hex: 0x3F93AA)
        let middle = dark ? RGB(hex: 0x0B2E3E) : RGB(hex: 0x16566F)
        let deep = dark ? RGB(hex: 0x041520) : RGB(hex: 0x072B3B)

        // Ola de fondo
        var back = Path()
        back.move(to: CGPoint(x: 0, y: bottom))
        for x in stride(from: 0, through: W, by: 6) { back.addLine(to: CGPoint(x: x, y: waveY(x, phase: 2.1, amp: 0.8) - 5)) }
        back.addLine(to: CGPoint(x: W, y: bottom)); back.closeSubpath()
        ctx.fill(back, with: .color(shallow.mixed(RGB(1, 1, 1), 0.18).color()))

        var body = Path()
        body.move(to: CGPoint(x: 0, y: bottom))
        var crest = Path()
        for x in stride(from: 0, through: W, by: 6) {
            let p = CGPoint(x: x, y: waveY(x))
            body.addLine(to: p)
            if x == 0 { crest.move(to: p) } else { crest.addLine(to: p) }
        }
        body.addLine(to: CGPoint(x: W, y: bottom)); body.closeSubpath()
        ctx.fill(body, with: .linearGradient(
            Gradient(stops: [.init(color: shallow.color(), location: 0),
                             .init(color: middle.color(), location: 0.35),
                             .init(color: deep.color(), location: 1)]),
            startPoint: CGPoint(x: 0, y: surfaceY), endPoint: CGPoint(x: 0, y: sandBase + H * 0.2)))
        ctx.stroke(crest, with: .color(.white.opacity(dark ? 0.18 : 0.45)), lineWidth: 1.5)
    }

    func drawRays(_ ctx: GraphicsContext) {
        var c = ctx
        c.addFilter(.blur(radius: 14))
        for i in 0..<5 {
            let fi = Double(i)
            let x0 = W * CGFloat(0.12 + fi * 0.2) + CGFloat(sin(t * 0.35 + fi * 1.9) * 30)
            let w0: CGFloat = 26 + CGFloat(fi.truncatingRemainder(dividingBy: 2)) * 22
            var p = Path()
            p.move(to: CGPoint(x: x0, y: surfaceY + 4))
            p.addLine(to: CGPoint(x: x0 + w0, y: surfaceY + 4))
            p.addLine(to: CGPoint(x: x0 + w0 * 3.2 + 120, y: surfaceY + H * 0.95))
            p.addLine(to: CGPoint(x: x0 + 120, y: surfaceY + H * 0.95))
            p.closeSubpath()
            let a = (dark ? 0.035 : 0.07) * (0.7 + 0.3 * sin(t * 0.8 + fi))
            c.fill(p, with: .linearGradient(Gradient(colors: [.white.opacity(a), .white.opacity(0)]),
                                            startPoint: CGPoint(x: x0, y: surfaceY), endPoint: CGPoint(x: x0, y: surfaceY + H * 0.95)))
        }
    }

    func drawKelp(_ ctx: GraphicsContext) {
        let spots: [(CGFloat, CGFloat, Double)] = [(0.04, 1.0, 0), (0.09, 0.7, 1.2), (0.86, 0.85, 2.3), (0.93, 1.15, 0.6), (0.97, 0.6, 1.9)]
        for (fx, hScale, ph) in spots {
            let x = W * fx
            let base = CGPoint(x: x, y: sandY(x) + 8)
            let height = H * 0.42 * hScale
            let sway = CGFloat(sin(t * 0.7 + ph) * 18)
            var p = Path()
            p.move(to: base)
            p.addCurve(to: CGPoint(x: x + sway, y: base.y - height),
                       control1: CGPoint(x: x - 20, y: base.y - height * 0.35),
                       control2: CGPoint(x: x + 22 + sway * 0.5, y: base.y - height * 0.7))
            let col = dark ? Color(red: 0.10, green: 0.25, blue: 0.22) : Color(red: 0.18, green: 0.40, blue: 0.33)
            ctx.stroke(p, with: .color(col.opacity(0.75)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
    }

    func drawSand(_ ctx: GraphicsContext) {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: bottom))
        for x in stride(from: 0, through: W, by: 6) { p.addLine(to: CGPoint(x: x, y: sandY(x))) }
        p.addLine(to: CGPoint(x: W, y: bottom)); p.closeSubpath()
        let top = dark ? RGB(hex: 0x3A4640) : RGB(hex: 0x9C9F86)
        let low = dark ? RGB(hex: 0x1B2320) : RGB(hex: 0x5D6150)
        ctx.fill(p, with: .linearGradient(Gradient(colors: [top.color(), low.color()]),
                                          startPoint: CGPoint(x: 0, y: sandBase - 16), endPoint: CGPoint(x: 0, y: sandBase + H * 0.35)))
        // Piedrecitas
        var r = Rand(7)
        for _ in 0..<26 {
            let x = CGFloat(r.next()) * W
            let y = sandY(x) + CGFloat(r.range(8, 60))
            let s = CGFloat(r.range(3, 9))
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s * 1.6, height: s)),
                     with: .color(.black.opacity(dark ? 0.18 : 0.10)))
        }
    }

    func restPoint(_ s: SunkenLetter) -> CGPoint {
        let x = CGFloat(s.x) * W
        return CGPoint(x: x, y: sandY(x) - 4)
    }

    func drawTokens(_ ctx: GraphicsContext, _ tokens: [SunkenLetter], sway: Bool) {
        for (i, s) in tokens.enumerated() {
            let p = restPoint(s)
            let wob = sway ? sin(t * 0.6 + Double(i) * 1.3) * 1.6 : 0
            PlanePainter.draw(ctx, at: p, angle: (s.rotation + wob) * .pi / 180, length: 130 * CGFloat(s.scale),
                              alpha: 0.92, underwater: 1, hue: s.hue, shadow: false)
        }
    }

    func drawFog(_ ctx: GraphicsContext) {
        let fog = dark ? RGB(hex: 0x03111A) : RGB(hex: 0x0A3446)
        let rect = CGRect(x: 0, y: surfaceY, width: W, height: bottom - surfaceY)
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [fog.color(0), fog.color(0.28), fog.color(0.18)]),
            startPoint: CGPoint(x: 0, y: surfaceY), endPoint: CGPoint(x: 0, y: bottom)))
    }

    func drawSnow(_ ctx: GraphicsContext, top: CGFloat, height: CGFloat) {
        var r = Rand(42)
        for _ in 0..<46 {
            let speed = r.range(6, 16)
            let x0 = r.next() * Double(W)
            let y0 = r.next() * Double(height)
            let size = CGFloat(r.range(1, 2.6))
            let y = (y0 + t * speed).truncatingRemainder(dividingBy: Double(height))
            let x = x0 + sin(t * 0.4 + y0) * 10
            ctx.fill(Path(ellipseIn: CGRect(x: CGFloat(x), y: top + CGFloat(y), width: size, height: size)),
                     with: .color(.white.opacity(r.range(0.12, 0.32))))
        }
    }
}

// MARK: - La ceremonia de soltar

struct CeremonyView: View {
    let ceremony: Ceremony
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @Local private var appeared = false
    @Local private var showFarewell = false
    @Local private var showQuote = false
    @Local private var closed = false

    private var duration: Double {
        if reduceMotion { return 1.3 }
        switch ceremony.destination {
        case .plane: return 3.3
        case .sea: return 5.9
        case .trash: return 2.9
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(appeared ? 1 : 0)

            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(ceremony.start)
                Canvas { ctx, size in
                    let dark = scheme == .dark
                    if reduceMotion {
                        drawReduced(ctx, size, t, dark)
                    } else {
                        switch ceremony.destination {
                        case .plane: drawPlaneScene(ctx, size, t, dark)
                        case .sea: drawSeaScene(ctx, size, t, dark)
                        case .trash: drawTrashScene(ctx, size, t, dark)
                        }
                    }
                }
            }

            farewell
        }
        .contentShape(Rectangle())
        .onAppear(perform: start)
    }

    // MARK: Despedida

    private var farewell: some View {
        let (title, sub) = ceremony.destination.farewell
        let onWater = ceremony.destination == .sea && !reduceMotion
        return VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 32, weight: .semibold, design: .serif))
            Text(sub)
                .font(.system(size: 15))
                .opacity(0.75)
            if let q = ceremony.quote {
                QuoteBlurb(quote: q, onWater: onWater)
                    .padding(.top, 22)
                    .opacity(showQuote ? 1 : 0)
                    .offset(y: showQuote ? 0 : 8)
                    .blur(radius: showQuote ? 0 : 4)
            }
            Button(L("Listo")) { close() }
                .buttonStyle(.glass)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 18)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(onWater ? Color.white : Palette.ink)
        .shadow(color: onWater ? .black.opacity(0.3) : .clear, radius: 10, y: 2)
        .opacity(showFarewell ? 1 : 0)
        .offset(y: showFarewell ? 0 : 10)
        .blur(radius: showFarewell ? 0 : 6)
        .allowsHitTesting(showFarewell)
        .offset(y: ceremony.destination == .sea ? -40 : 0)
    }

    private func start() {
        withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        if reduceMotion {
            SoundFX.play(ceremony.destination == .trash ? "empty trash" : "whoosh", after: 0.2, volume: 0.6)
        } else {
            switch ceremony.destination {
            case .plane:
                SoundFX.play("whoosh", after: 0.95)
            case .sea:
                SoundFX.play("whoosh", after: 0.95, volume: 0.55)
                SoundFX.play("splash", after: 1.98)
            case .trash:
                SoundFX.play("crumple", after: 0.5)
                SoundFX.play("empty trash", after: 1.92)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeOut(duration: 0.6)) { showFarewell = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.7) {
            withAnimation(.easeOut(duration: 0.8)) { showQuote = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + (ceremony.quote == nil ? 6 : 30)) { close() }
    }

    private func close() {
        guard !closed else { return }
        closed = true
        onDone()
    }

    // MARK: Papel → forma

    private func paperScale(_ size: CGSize) -> CGFloat {
        let ps = ceremony.paperSize
        guard ps.width > 0, ps.height > 0 else { return 1 }
        return min(min(size.width * 0.46, 520) / ps.width, size.height * 0.62 / ps.height)
    }

    /// Dibuja la carta encogiéndose y doblándose. `fold` 0…1 controla el aplastado final.
    private func drawPaper(_ ctx: GraphicsContext, center: CGPoint, scale: CGFloat, squashY: CGFloat = 1,
                           squashX: CGFloat = 1, rotation: Double, alpha: Double, blur: CGFloat) {
        guard alpha > 0.001 else { return }
        var c = ctx
        c.opacity = alpha
        if blur > 0.1 { c.addFilter(.blur(radius: blur)) }
        c.addFilter(.shadow(color: .black.opacity(0.14), radius: 24, x: 0, y: 14))
        let img = c.resolve(ceremony.paper)
        c.drawLayer { l in
            l.translateBy(x: center.x, y: center.y)
            l.rotate(by: .degrees(rotation))
            l.scaleBy(x: scale * squashX, y: scale * squashY)
            l.draw(img, at: .zero, anchor: .center)
        }
    }

    /// Fase común: la carta se encoge y se convierte en avión (0…1 s).
    private func foldIntoPlane(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double, center: CGPoint) -> (alpha: Double, scale: Double) {
        let s0 = paperScale(size)
        let shrink = easeInOut(seg(t, 0.05, 0.75))
        let fold = easeInOut(seg(t, 0.5, 0.95))
        drawPaper(ctx, center: center,
                  scale: mix(s0, s0 * 0.3, shrink),
                  squashY: mix(1, 0.2, fold),
                  squashX: mix(1, 0.75, fold),
                  rotation: -6 * shrink,
                  alpha: 1 - fold,
                  blur: CGFloat(fold * 9))
        let appear = easeOut(seg(t, 0.6, 1.0))
        return (appear, 0.72 + 0.28 * appear)
    }

    // MARK: Escena: avión

    private func drawPlaneScene(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double, _ dark: Bool) {
        let W = size.width, H = size.height
        let bgIn = easeOut(seg(t, 0, 0.45))
        let top = dark ? RGB(hex: 0x0E1A2C) : RGB(hex: 0xD6E6F5)
        let low = dark ? RGB(hex: 0x1A2233) : RGB(hex: 0xF5EFE7)
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [top.color(0.92 * bgIn), low.color(0.92 * bgIn)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))

        // Nubes
        var cl = ctx
        cl.addFilter(.blur(radius: 28))
        let clouds: [(CGFloat, CGFloat, CGFloat, Double)] = [(0.18, 0.22, 260, 9), (0.72, 0.16, 320, 14), (0.55, 0.72, 280, 11), (0.9, 0.55, 220, 7)]
        for (fx, fy, w, speed) in clouds {
            let x = W * fx - CGFloat(t * speed)
            cl.fill(Path(ellipseIn: CGRect(x: x - w / 2, y: H * fy - w * 0.18, width: w, height: w * 0.36)),
                    with: .color(.white.opacity((dark ? 0.06 : 0.6) * bgIn)))
        }

        let center = CGPoint(x: W / 2, y: H * 0.48)
        let (appear, planeScale) = foldIntoPlane(ctx, size, t, center: center)
        guard appear > 0 else { return }

        // Vuelo: un pequeño descenso y despega hacia arriba a la derecha
        let u = seg(t, 1.0, 3.1)
        let e = pow(u, 1.65)
        let p0 = center
        let p1 = CGPoint(x: center.x + 120, y: center.y + 70)
        let p2 = CGPoint(x: W * 0.74, y: H * 0.40)
        let p3 = CGPoint(x: W + 180, y: -160)
        let pos = u > 0 ? cubic(p0, p1, p2, p3, e) : CGPoint(x: center.x, y: center.y + CGFloat(sin(t * 6) * 2))
        let pathAngle = cubicAngle(p0, p1, p2, p3, max(e, 0.001))
        let angle = pathAngle * easeOut(seg(u, 0, 0.18)) + sin(t * 9) * 0.04 * (1 - u)

        // Estela discontinua
        if e > 0.01 {
            var trail = Path()
            let start = max(0, e - 0.32)
            let steps = 40
            for i in 0...steps {
                let k = start + (e - start) * Double(i) / Double(steps)
                let q = cubic(p0, p1, p2, p3, k)
                if i == 0 { trail.move(to: q) } else { trail.addLine(to: q) }
            }
            let fade = 1 - seg(u, 0.75, 1)
            let tailStart = cubic(p0, p1, p2, p3, start)
            ctx.stroke(trail, with: .linearGradient(
                Gradient(colors: [Destination.plane.tint.opacity(0), Destination.plane.tint.opacity(0.45 * fade)]),
                startPoint: tailStart, endPoint: pos),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 8]))
        }

        PlanePainter.draw(ctx, at: pos, angle: angle, length: 130 * CGFloat(planeScale) * mix(1, 0.5, e), alpha: appear)
    }

    // MARK: Escena: mar

    private func drawSeaScene(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double, _ dark: Bool) {
        let W = size.width, H = size.height
        let sea = SeaPainter(W: W, H: H, t: t, dark: dark)
        let bgIn = easeOut(seg(t, 0, 0.5))
        var world = ctx
        world.opacity = bgIn


        let center = CGPoint(x: W / 2, y: H * 0.40)
        // Trayectoria de planeo hasta el agua
        let glideStart = 1.0, impact = 2.05, rest = 5.35
        let g0 = center
        let g1 = CGPoint(x: center.x + 130, y: center.y - 50)
        let g2 = CGPoint(x: center.x + 230, y: sea.surfaceY - 70)
        let g3 = CGPoint(x: center.x + 170, y: sea.surfaceY + 8)
        let restP = ceremony.newSunken.map { sea.restPoint($0) } ?? CGPoint(x: W / 2, y: sea.sandY(W / 2) - 4)
        let restAngle = (ceremony.newSunken?.rotation ?? 0) * .pi / 180
        let restLen = 130 * CGFloat(ceremony.newSunken?.scale ?? 0.5)
        let entryAngle = cubicAngle(g0, g1, g2, g3, 1)

        func planeState(_ time: Double) -> (CGPoint, Double, CGFloat) {
            if time < glideStart { return (center, 0, 130) }
            if time < impact {
                let u = seg(time, glideStart, impact)
                let e = pow(u, 1.5)
                let a = cubicAngle(g0, g1, g2, g3, max(e, 0.001)) * easeOut(seg(u, 0, 0.25))
                return (cubic(g0, g1, g2, g3, e), a, 130 * mix(1, 0.85, u))
            }
            let v = seg(time, impact, rest)
            let ev = 0.5 * easeOut(v) + 0.5 * easeInOut(v)
            var p = mixP(g3, restP, ev)
            p.x += CGFloat(sin(v * .pi * 3) * 30 * (1 - v))
            let a = entryAngle + (restAngle - entryAngle) * easeOut(v) + sin(v * .pi * 4) * 0.28 * (1 - v)
            return (p, a, mix(130 * 0.85, restLen, easeOut(v)))
        }

        let (pos, ang, len) = planeState(t)
        // La cámara sigue al avión mientras se hunde, hasta ver el fondo
        let follow = min(sea.seabedCamera, max(0, pos.y - H * 0.5))
        let cam = follow * CGFloat(easeInOut(seg(t, impact - 0.2, impact + 0.9)))
        world.translateBy(x: 0, y: -cam)
        sea.drawSky(world)

        let (appear, planeScale) = foldIntoPlane(world, size, t, center: center)

        // Avión sobre el agua
        if t < impact && appear > 0 {
            PlanePainter.draw(world, at: pos, angle: ang, length: len * CGFloat(planeScale), alpha: appear)
        }

        sea.drawWater(world)
        sea.drawRays(world)
        sea.drawKelp(world)
        sea.drawSand(world)
        sea.drawTokens(world, ceremony.seabed, sway: true)

        // Burbujas
        if t > impact {
            var r = Rand(11)
            for i in 0..<28 {
                let birth = impact + Double(i) * 0.1 + r.range(0, 0.08)
                let speed = r.range(70, 120), rad = CGFloat(r.range(1.6, 4.6)), ph = r.range(0, 6)
                guard t > birth, birth < rest - 0.4 else { continue }
                let age = t - birth
                let (bp, _, _) = planeState(birth)
                let y = bp.y - CGFloat(age * speed)
                guard y > sea.surfaceY + 6, age < 3.2 else { continue }
                let x = bp.x + CGFloat(sin(age * 3 + ph) * 7)
                let a = 0.7 * (1 - age / 3.2)
                let rect = CGRect(x: x - rad, y: y - rad, width: rad * 2, height: rad * 2)
                world.fill(Path(ellipseIn: rect), with: .color(.white.opacity(a * 0.18)))
                world.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(a)), lineWidth: 0.8)
            }
        }

        // Avión hundiéndose
        if t >= impact {
            let depth = Double((pos.y - sea.surfaceY) / (sea.sandBase - sea.surfaceY))
            PlanePainter.draw(world, at: pos, angle: ang, length: len, alpha: 1,
                              underwater: clamp01(0.3 + depth), hue: ceremony.newSunken?.hue, shadow: false)
        }

        // Nube de arena al posarse
        if t > rest {
            let k = seg(t, rest, rest + 1.0)
            var r = Rand(5)
            for _ in 0..<14 {
                let dir = r.range(-1, 1), lift = r.range(0.2, 1)
                let x = restP.x + CGFloat(dir * 60 * easeOut(k))
                let y = restP.y + 4 - CGFloat(lift * 22 * easeOut(k))
                let s = CGFloat(r.range(3, 7)) * CGFloat(1 + k)
                world.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)),
                           with: .color(Color(red: 0.75, green: 0.75, blue: 0.62).opacity(0.35 * (1 - k))))
            }
        }

        sea.drawFog(world)
        sea.drawSnow(world, top: sea.surfaceY + 10, height: sea.bottom - sea.surfaceY)

        // Salpicadura
        if t > impact && t < impact + 1.8 {
            let k = t - impact
            for i in 0..<3 {
                let p = seg(k, Double(i) * 0.18, Double(i) * 0.18 + 1.5)
                guard p > 0 && p < 1 else { continue }
                let rx = mix(10, 170, easeOut(p))
                let rect = CGRect(x: g3.x - rx, y: sea.surfaceY - rx * 0.12, width: rx * 2, height: rx * 0.24)
                world.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.55 * (1 - p))), lineWidth: 1.4)
            }
            var r = Rand(3)
            for _ in 0..<24 {
                let vx = r.range(-170, 170), vy = r.range(-420, -170), s = CGFloat(r.range(2, 4.5))
                let x = g3.x + CGFloat(vx * k)
                let y = sea.surfaceY + CGFloat(vy * k + 0.5 * 1100 * k * k)
                guard y < sea.surfaceY + 2 else { continue }
                world.fill(Path(ellipseIn: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                           with: .color(.white.opacity(0.9 * (1 - k / 1.8))))
            }
        }
    }

    // MARK: Escena: papelera

    private func drawTrashScene(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double, _ dark: Bool) {
        let W = size.width, H = size.height
        let bgIn = easeOut(seg(t, 0, 0.4))
        let bg = dark ? RGB(hex: 0x141416) : RGB(hex: 0xEFEEEB)
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bg.color(0.9 * bgIn)))

        let center = CGPoint(x: W / 2, y: H * 0.40)
        let s0 = paperScale(size)

        // 1. Se encoge y se arruga
        let shrink = easeInOut(seg(t, 0.05, 0.6))
        let crumple = easeInOut(seg(t, 0.5, 1.1))
        let jitter = sin(t * 46) * 7 * crumple * (1 - crumple) * 4
        drawPaper(ctx, center: center,
                  scale: mix(mix(s0, s0 * 0.5, shrink), s0 * 0.16, crumple),
                  squashY: mix(1, 0.7, crumple), squashX: mix(1, 0.85, crumple),
                  rotation: -4 * shrink + jitter,
                  alpha: 1 - seg(t, 0.75, 1.1),
                  blur: CGFloat(crumple * 5))

        // 2. La papelera aparece
        let canIn = easeOut(seg(t, 0.25, 0.95))
        let canOut = easeInOut(seg(t, 2.45, 2.95))
        let rim = CGPoint(x: W / 2, y: mix(H + 60, H * 0.66, canIn) + CGFloat(24 * canOut))
        let canAlpha = canIn * (1 - canOut)
        let impact = 1.95
        var squash: CGFloat = 1
        if t > impact {
            let k = t - impact
            squash = 1 - CGFloat(0.075 * exp(-k * 7) * cos(k * 24))
        }

        // 3. La bola vuela a la papelera
        let ballIn = easeOut(seg(t, 0.75, 1.1))
        let u = seg(t, 1.2, impact)
        let eu = 0.15 * u + 0.85 * u * u
        var ball = CGPoint(x: center.x + CGFloat(sin(u * .pi) * 70),
                           y: mix(center.y, rim.y + 6, eu) - CGFloat(4 * 140 * u * (1 - u)))
        if t > impact { ball.y += CGFloat(min(1, (t - impact) / 0.18) * 70) }
        let ballR: CGFloat = 40 * CGFloat(0.75 + 0.25 * ballIn) * mix(1, 0.72, u)
        let spin = u * 9.5 + crumple * 0.6
        let ballBehind = t > impact - 0.06

        if canAlpha > 0 {
            drawCanBack(ctx, rim: rim, alpha: canAlpha, squash: squash, dark: dark)
        }
        if ballIn > 0 && t < impact + 0.2 && ballBehind {
            drawBall(ctx, at: ball, radius: ballR, rotation: spin, alpha: ballIn)
        }
        if canAlpha > 0 {
            drawCanFront(ctx, rim: rim, alpha: canAlpha, squash: squash, dark: dark)
        }
        if ballIn > 0 && !ballBehind {
            drawBall(ctx, at: ball, radius: ballR, rotation: spin, alpha: ballIn)
        }
    }

    private let canTop: CGFloat = 136, canBottom: CGFloat = 106, canHeight: CGFloat = 154, rimRY: CGFloat = 14

    private func drawCanBack(_ ctx: GraphicsContext, rim: CGPoint, alpha: Double, squash: CGFloat, dark: Bool) {
        var c = ctx
        c.opacity = alpha
        // Sombra en el suelo
        var sh = c
        sh.addFilter(.blur(radius: 12))
        let base = rim.y + canHeight * squash
        sh.fill(Path(ellipseIn: CGRect(x: rim.x - canBottom * 0.62, y: base - 8, width: canBottom * 1.24, height: 18)),
                with: .color(.black.opacity(dark ? 0.5 : 0.18)))
        // Interior
        let inner = CGRect(x: rim.x - canTop / 2 * (2 - squash), y: rim.y - rimRY, width: canTop * (2 - squash), height: rimRY * 2)
        c.fill(Path(ellipseIn: inner), with: .linearGradient(
            Gradient(colors: [Color(white: dark ? 0.08 : 0.30), Color(white: dark ? 0.18 : 0.55)]),
            startPoint: CGPoint(x: 0, y: inner.minY), endPoint: CGPoint(x: 0, y: inner.maxY)))
    }

    private func drawCanFront(_ ctx: GraphicsContext, rim: CGPoint, alpha: Double, squash: CGFloat, dark: Bool) {
        var c = ctx
        c.opacity = alpha
        let wT = canTop * (2 - squash), wB = canBottom * (2 - squash), h = canHeight * squash
        let left = rim.x - wT / 2, right = rim.x + wT / 2
        let bl = rim.x - wB / 2, br = rim.x + wB / 2
        let base = rim.y + h

        var body = Path()
        body.move(to: CGPoint(x: left, y: rim.y))
        body.addLine(to: CGPoint(x: bl, y: base))
        body.addQuadCurve(to: CGPoint(x: br, y: base), control: CGPoint(x: rim.x, y: base + 16))
        body.addLine(to: CGPoint(x: right, y: rim.y))
        body.addQuadCurve(to: CGPoint(x: left, y: rim.y), control: CGPoint(x: rim.x, y: rim.y + rimRY * 2))
        body.closeSubpath()

        let metal: [Color] = dark
            ? [Color(white: 0.30), Color(white: 0.52), Color(white: 0.38), Color(white: 0.24)]
            : [Color(white: 0.72), Color(white: 0.96), Color(white: 0.84), Color(white: 0.64)]
        c.fill(body, with: .linearGradient(Gradient(colors: metal),
                                           startPoint: CGPoint(x: left, y: 0), endPoint: CGPoint(x: right, y: 0)))

        // Ranuras verticales
        var ribs = c
        ribs.clip(to: body)
        for i in 1..<10 {
            let f = CGFloat(i) / 10
            let xt = left + wT * f, xb = bl + wB * f
            let curveY = rim.y + rimRY * 2 * (1 - pow(2 * f - 1, 2)) * 0.5
            var p = Path()
            p.move(to: CGPoint(x: xt, y: curveY + 10))
            p.addLine(to: CGPoint(x: xb, y: base - 8))
            ribs.stroke(p, with: .color(.black.opacity(dark ? 0.25 : 0.10)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            var hl = Path()
            hl.move(to: CGPoint(x: xt + 2.5, y: curveY + 10))
            hl.addLine(to: CGPoint(x: xb + 2, y: base - 8))
            ribs.stroke(hl, with: .color(.white.opacity(dark ? 0.08 : 0.5)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }

        // Borde
        let rimRect = CGRect(x: left, y: rim.y - rimRY, width: wT, height: rimRY * 2)
        c.stroke(Path(ellipseIn: rimRect), with: .color(Color(white: dark ? 0.6 : 0.97)), lineWidth: 3.5)
        c.stroke(Path(ellipseIn: rimRect.insetBy(dx: -1.8, dy: -1.8)), with: .color(.black.opacity(0.12)), lineWidth: 0.8)
    }

    private func drawBall(_ ctx: GraphicsContext, at p: CGPoint, radius r: CGFloat, rotation: Double, alpha: Double) {
        var c = ctx
        c.opacity = alpha
        c.addFilter(.shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 6))
        c.drawLayer { l in
            l.translateBy(x: p.x, y: p.y)
            l.rotate(by: .radians(rotation))
            var rnd = Rand(99)
            let n = 15
            var pts: [CGPoint] = []
            for i in 0..<n {
                let a = Double(i) / Double(n) * 2 * .pi + rnd.range(-0.12, 0.12)
                let rr = r * CGFloat(rnd.range(0.82, 1.08))
                pts.append(CGPoint(x: cos(a) * rr, y: sin(a) * rr))
            }
            var shape = Path()
            shape.addLines(pts)
            shape.closeSubpath()
            l.fill(shape, with: .radialGradient(
                Gradient(colors: [Color(white: 1), Color(red: 0.93, green: 0.92, blue: 0.89), Color(red: 0.80, green: 0.79, blue: 0.75)]),
                center: CGPoint(x: -r * 0.3, y: -r * 0.35), startRadius: 0, endRadius: r * 1.5))
            var creases = Path()
            for _ in 0..<9 {
                let a = pts[Int(rnd.next() * Double(n)) % n]
                let mid = CGPoint(x: CGFloat(rnd.range(-0.4, 0.4)) * r, y: CGFloat(rnd.range(-0.4, 0.4)) * r)
                let b = CGPoint(x: CGFloat(rnd.range(-0.6, 0.6)) * r, y: CGFloat(rnd.range(-0.6, 0.6)) * r)
                creases.move(to: CGPoint(x: a.x * 0.92, y: a.y * 0.92))
                creases.addLine(to: mid)
                creases.addLine(to: b)
            }
            l.stroke(creases, with: .color(.black.opacity(0.13)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
            l.stroke(shape, with: .color(.black.opacity(0.10)), lineWidth: 0.8)
        }
    }

    // MARK: Movimiento reducido

    private func drawReduced(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double, _ dark: Bool) {
        let bg = dark ? RGB(hex: 0x141416) : RGB(hex: 0xEFEEEB)
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bg.color(0.9 * easeOut(seg(t, 0, 0.3)))))
        let k = seg(t, 0.2, 1.2)
        drawPaper(ctx, center: CGPoint(x: size.width / 2, y: size.height * 0.45), scale: paperScale(size) * 0.7,
                  rotation: 0, alpha: 1 - k, blur: CGFloat(k * 14))
    }
}

// MARK: - El fondo del mar

struct SeabedView: View {
    @EnvironmentObject var store: LetterStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
                Canvas { ctx, size in
                    let sea = SeaPainter(W: size.width, H: size.height, t: t, dark: scheme == .dark)
                    var world = ctx
                    world.translateBy(x: 0, y: -sea.seabedCamera)
                    sea.drawWater(world)
                    sea.drawRays(world)
                    sea.drawKelp(world)
                    sea.drawSand(world)
                    sea.drawTokens(world, store.seabed, sway: !reduceMotion)
                    sea.drawFog(world)
                    sea.drawSnow(world, top: sea.seabedCamera, height: size.height)
                }
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 6) {
                Text(L("El fondo del mar"))
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                Text(subtitle)
                    .font(.system(size: 14))
                    .opacity(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
            .padding(.horizontal, 40)
            .padding(.top, 28)
            .frame(maxWidth: 520, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var subtitle: String {
        switch store.seabed.count {
        case 0: return L("Aún no hay nada aquí. Lo que envíes al mar vendrá a descansar a este lugar.")
        case 1: return L("Una carta descansa aquí. No se puede rescatar.")
        default: return LF("%d cartas descansan aquí. No se pueden rescatar.", store.seabed.count)
        }
    }
}

// MARK: - Frase al final

struct QuoteBlurb: View {
    let quote: Quote
    let onWater: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(quote.text)
                .font(.system(size: 17, design: .serif).italic())
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("\u{2014} \(quote.author) \u{00B7} \(quote.role)")
                .font(.system(size: 12, weight: .medium))
                .opacity(0.7)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
        .frame(maxWidth: 480)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(onWater ? Color.white.opacity(0.10) : Color.primary.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(onWater ? Color.white.opacity(0.18) : Palette.hairline, lineWidth: 0.5)
        }
    }
}

// MARK: - Ajustes

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            SwiftUI.Section {
                Picker(L("Idioma"), selection: $model.language) {
                    ForEach(Lang.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(L("El dictado también usa este idioma."))
                    .foregroundStyle(.secondary)
            }
            SwiftUI.Section {
                Toggle(L("Mostrar una frase al soltar"), isOn: $model.showQuotes)
            } footer: {
                Text(L("Al soltar una carta verás una frase breve de psicología según lo que sentías."))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .id(model.language)
    }
}

/// Ventana de ajustes propia (sin la escena Settings, que depende de macros de SwiftUI).
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()
    weak var model: AppModel?
    private var window: NSWindow?

    func refreshTitle() { window?.title = L("Ajustes") }

    func show() {
        guard let model else { return }
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(model: model))
            let w = NSWindow(contentViewController: host)
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        refreshTitle()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
