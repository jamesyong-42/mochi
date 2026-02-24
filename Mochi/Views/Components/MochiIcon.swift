import SwiftUI

struct MochiIcon: View {
    var size: CGFloat = 48

    private let strokeColor = Color(hex: "475569")

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 100

            // Body - flat mochi/daifuku shape (exact SVG path)
            // M 14,65 C 14,25 86,25 86,65 C 86,88 14,88 14,65 Z
            let bodyPath = Path { p in
                p.move(to: CGPoint(x: 14 * s, y: 65 * s))
                p.addCurve(
                    to: CGPoint(x: 86 * s, y: 65 * s),
                    control1: CGPoint(x: 14 * s, y: 25 * s),
                    control2: CGPoint(x: 86 * s, y: 25 * s)
                )
                p.addCurve(
                    to: CGPoint(x: 14 * s, y: 65 * s),
                    control1: CGPoint(x: 86 * s, y: 88 * s),
                    control2: CGPoint(x: 14 * s, y: 88 * s)
                )
                p.closeSubpath()
            }
            context.fill(bodyPath, with: .color(.white))
            var strokeStyle = StrokeStyle(lineWidth: 5 * s, lineCap: .round, lineJoin: .round)
            context.stroke(bodyPath, with: .color(strokeColor), style: strokeStyle)

            // Left eye - circle at (36, 58) r=3.5
            let leftEye = Path(ellipseIn: CGRect(
                x: (36 - 3.5) * s, y: (58 - 3.5) * s,
                width: 7 * s, height: 7 * s
            ))
            context.fill(leftEye, with: .color(strokeColor))

            // Right eye - circle at (64, 58) r=3.5
            let rightEye = Path(ellipseIn: CGRect(
                x: (64 - 3.5) * s, y: (58 - 3.5) * s,
                width: 7 * s, height: 7 * s
            ))
            context.fill(rightEye, with: .color(strokeColor))

            // Mouth - M 47,59 Q 50,63 53,59
            let mouthPath = Path { p in
                p.move(to: CGPoint(x: 47 * s, y: 59 * s))
                p.addQuadCurve(
                    to: CGPoint(x: 53 * s, y: 59 * s),
                    control: CGPoint(x: 50 * s, y: 63 * s)
                )
            }
            strokeStyle = StrokeStyle(lineWidth: 2.5 * s, lineCap: .round)
            context.stroke(mouthPath, with: .color(strokeColor), style: strokeStyle)
        }
        .frame(width: size, height: size)
    }
}
