import SwiftUI

/// Valores de animación de Dot en un instante dado. Pura y sin dependencias de vista.
struct MascotPose: Equatable {
    var offsetX: Double = 0      // en unidades de radio
    var offsetY: Double = 0      // en unidades de radio (negativo = arriba)
    var scaleX: Double = 1
    var scaleY: Double = 1
    var tilt: Double = 0         // radianes
    var lookX: Double = 0        // -1...1
    var lookY: Double = 0        // -1...1
    var eyeScale: Double = 1
    var blink: Double = 0        // 0 abierto ... 1 cerrado
    var smile: Double = 0        // 0...1
    var amber: Bool = false

    /// Parpadeo pseudoaleatorio: un parpadeo por ventana de ~3 s, en un punto variable de la ventana.
    static func blinkAmount(at t: Double) -> Double {
        let window = 3.0
        let slot = (t / window).rounded(.down)
        let x = sin(slot * 12.9898) * 43758.5453
        let r = x - x.rounded(.down)
        let start = slot * window + r * (window - 0.5)
        let duration = 0.16
        let dt = t - start
        guard dt >= 0, dt <= duration else { return 0 }
        return sin(Double.pi * dt / duration)
    }

    static func make(mood: MascotMood, at t: Double) -> MascotPose {
        var p = MascotPose()
        let breath = sin(t * 2.0 * Double.pi / 3.5)
        p.scaleX = 1 - 0.025 * breath
        p.scaleY = 1 + 0.035 * breath
        p.blink = blinkAmount(at: t)

        switch mood {
        case .idle:
            break
        case .working:
            p.lookX = sin(t * 2.2)
            let pulse = sin(t * 5.0)
            p.scaleX += 0.02 * pulse
            p.scaleY += 0.02 * pulse
        case .alert:
            p.amber = true
            p.eyeScale = 1.15
            p.offsetY = -abs(sin(t * 7.0)) * 0.35
            p.offsetX = sin(t * 38.0) * 0.07
            p.tilt = sin(t * 19.0) * 0.12
            p.blink *= 0.3
        case .happy:
            let hop = abs(sin(t * 6.0))
            p.offsetY = -hop * 0.45
            p.scaleY += 0.06 * (1 - hop)
            p.smile = 1
            p.blink = max(p.blink, 0.45)
        case .dancing:
            let beat = t * 2.0 * Double.pi * 2.0 // ~120 bpm
            let bounce = abs(sin(beat / 2))
            p.offsetY = -bounce * 0.3
            p.offsetX = sin(beat / 2) * 0.15
            p.tilt = sin(beat / 2) * 0.2
            p.scaleY += 0.08 * (1 - bounce)
            p.smile = 0.7
            p.lookX = sin(beat / 4) * 0.6
        case .curious:
            p.eyeScale = 1.25
            p.lookY = 0.85
            p.lookX = sin(t * 1.3) * 0.25
            p.offsetY = 0.05
            p.tilt = sin(t * 1.3) * 0.05
            p.blink *= 0.5
        }
        return p
    }
}

/// Dot: un punto redondo con ojos grandes, dibujado solo con Canvas.
struct MascotView: View {
    var mood: MascotMood
    var size: CGFloat = 24

    @State private var isVisible = true

    private static let bodyColor = Color(red: 0.36, green: 0.62, blue: 1.0)
    private static let amberColor = Color(red: 1.0, green: 0.74, blue: 0.2)

    var body: some View {
        content
            .frame(width: size, height: size)
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .accessibilityElement()
            .accessibilityLabel("Dot")
    }

    @ViewBuilder
    private var content: some View {
        if !isVisible {
            // Fuera de pantalla: línea de tiempo en pausa, sin trabajo.
            TimelineView(.animation(minimumInterval: 1.0, paused: true)) { timeline in
                canvas(at: timeline.date)
            }
        } else if mood == .idle {
            TimelineView(.periodic(from: Date(), by: 0.1)) { timeline in
                canvas(at: timeline.date)
            }
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                canvas(at: timeline.date)
            }
        }
    }

    private func canvas(at date: Date) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        let pose = MascotPose.make(mood: mood, at: t)
        return Canvas { context, canvasSize in
            Self.draw(pose: pose, in: &context, canvasSize: canvasSize)
        }
    }

    private static func draw(pose: MascotPose, in context: inout GraphicsContext, canvasSize: CGSize) {
        let side = min(canvasSize.width, canvasSize.height)
        let r = side * 0.34
        let center = CGPoint(x: canvasSize.width / 2 + CGFloat(pose.offsetX) * r,
                             y: canvasSize.height / 2 + CGFloat(pose.offsetY) * r)

        var ctx = context
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: .radians(pose.tilt))

        // Cuerpo
        let bodyW = r * 2 * CGFloat(pose.scaleX)
        let bodyH = r * 2 * CGFloat(pose.scaleY)
        let bodyRect = CGRect(x: -bodyW / 2, y: -bodyH / 2, width: bodyW, height: bodyH)
        let base = pose.amber ? amberColor : bodyColor
        ctx.fill(Path(ellipseIn: bodyRect), with: .color(base))
        // Brillo suave arriba
        let shine = CGRect(x: -bodyW * 0.28, y: -bodyH * 0.40, width: bodyW * 0.3, height: bodyH * 0.16)
        ctx.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.28)))

        // Ojos
        let eyeW = r * 0.62 * CGFloat(pose.eyeScale)
        let eyeH = eyeW * 1.15 * CGFloat(max(0.08, 1 - pose.blink))
        let eyeY = -r * 0.1
        let gap = r * 0.36
        let pupilR = eyeW * 0.26
        let maxShiftX = (eyeW / 2 - pupilR) * 0.9
        let maxShiftY = max(0, (eyeH / 2 - pupilR)) * 0.9

        for sign in [-1.0, 1.0] {
            let cx = CGFloat(sign) * gap
            let eyeRect = CGRect(x: cx - eyeW / 2, y: eyeY - eyeH / 2, width: eyeW, height: eyeH)
            ctx.fill(Path(ellipseIn: eyeRect), with: .color(.white))
            if pose.blink < 0.7 {
                let px = cx + CGFloat(pose.lookX) * maxShiftX
                let py = eyeY + CGFloat(pose.lookY) * maxShiftY
                let pupil = CGRect(x: px - pupilR, y: py - pupilR, width: pupilR * 2, height: pupilR * 2)
                ctx.fill(Path(ellipseIn: pupil), with: .color(Color(red: 0.08, green: 0.1, blue: 0.16)))
            }
        }

        // Sonrisa
        if pose.smile > 0.01 {
            var smile = Path()
            let w = r * 0.5 * CGFloat(pose.smile)
            let y = r * 0.5
            smile.move(to: CGPoint(x: -w, y: y))
            smile.addQuadCurve(to: CGPoint(x: w, y: y),
                               control: CGPoint(x: 0, y: y + r * 0.3 * CGFloat(pose.smile)))
            ctx.stroke(smile,
                       with: .color(Color(red: 0.08, green: 0.1, blue: 0.16)),
                       style: StrokeStyle(lineWidth: max(1, r * 0.1), lineCap: .round))
        }
    }
}
