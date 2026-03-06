import SpriteKit

/// Generates a procedural fish texture for prototyping.
/// Creates a goldfish-like shape with body, fins, and tail.
enum FishTextureGenerator {

    /// Generate a goldfish body texture facing right.
    /// - Parameters:
    ///   - size: Texture size in points.
    ///   - scene: SKScene needed for texture rendering.
    /// - Returns: An SKTexture of the fish body.
    static func generateBodyTexture(size: CGSize = CGSize(width: 256, height: 128)) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let w = size.width
            let h = size.height

            // --- Fish body (elliptical, facing right) ---
            // Main body gradient: orange to golden
            let bodyPath = UIBezierPath()
            // Egg-shaped: wider in front, narrower at back
            bodyPath.move(to: CGPoint(x: w * 0.15, y: h * 0.5))

            // Top curve (back of head to tail)
            bodyPath.addCurve(
                to: CGPoint(x: w * 0.90, y: h * 0.5),
                controlPoint1: CGPoint(x: w * 0.15, y: h * 0.10),
                controlPoint2: CGPoint(x: w * 0.70, y: h * 0.15)
            )

            // Bottom curve (tail to back of head)
            bodyPath.addCurve(
                to: CGPoint(x: w * 0.15, y: h * 0.5),
                controlPoint1: CGPoint(x: w * 0.70, y: h * 0.85),
                controlPoint2: CGPoint(x: w * 0.15, y: h * 0.90)
            )
            bodyPath.close()

            // Body gradient fill
            cg.saveGState()
            bodyPath.addClip()
            let colors = [
                UIColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 1.0).cgColor,
                UIColor(red: 1.0, green: 0.35, blue: 0.05, alpha: 1.0).cgColor,
                UIColor(red: 0.9, green: 0.25, blue: 0.05, alpha: 0.9).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: colors as CFArray,
                                       locations: [0, 0.5, 1.0])!
            cg.drawLinearGradient(gradient,
                                  start: CGPoint(x: w * 0.3, y: 0),
                                  end: CGPoint(x: w * 0.3, y: h),
                                  options: [])
            cg.restoreGState()

            // --- Tail fin (fan shape) ---
            let tailPath = UIBezierPath()
            tailPath.move(to: CGPoint(x: w * 0.82, y: h * 0.5))
            tailPath.addCurve(
                to: CGPoint(x: w * 0.99, y: h * 0.10),
                controlPoint1: CGPoint(x: w * 0.88, y: h * 0.35),
                controlPoint2: CGPoint(x: w * 0.95, y: h * 0.15)
            )
            tailPath.addCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.5),
                controlPoint1: CGPoint(x: w * 0.96, y: h * 0.30),
                controlPoint2: CGPoint(x: w * 0.92, y: h * 0.45)
            )
            tailPath.addCurve(
                to: CGPoint(x: w * 0.99, y: h * 0.90),
                controlPoint1: CGPoint(x: w * 0.92, y: h * 0.55),
                controlPoint2: CGPoint(x: w * 0.96, y: h * 0.70)
            )
            tailPath.addCurve(
                to: CGPoint(x: w * 0.82, y: h * 0.5),
                controlPoint1: CGPoint(x: w * 0.95, y: h * 0.85),
                controlPoint2: CGPoint(x: w * 0.88, y: h * 0.65)
            )
            tailPath.close()

            UIColor(red: 1.0, green: 0.45, blue: 0.05, alpha: 0.85).setFill()
            tailPath.fill()

            // --- Dorsal fin (top) ---
            let dorsalPath = UIBezierPath()
            dorsalPath.move(to: CGPoint(x: w * 0.30, y: h * 0.22))
            dorsalPath.addCurve(
                to: CGPoint(x: w * 0.55, y: h * 0.05),
                controlPoint1: CGPoint(x: w * 0.35, y: h * 0.12),
                controlPoint2: CGPoint(x: w * 0.45, y: h * 0.05)
            )
            dorsalPath.addCurve(
                to: CGPoint(x: w * 0.65, y: h * 0.20),
                controlPoint1: CGPoint(x: w * 0.60, y: h * 0.05),
                controlPoint2: CGPoint(x: w * 0.63, y: h * 0.12)
            )
            dorsalPath.close()
            UIColor(red: 1.0, green: 0.50, blue: 0.08, alpha: 0.7).setFill()
            dorsalPath.fill()

            // --- Pectoral fins (sides) ---
            let pectoralPath = UIBezierPath()
            pectoralPath.move(to: CGPoint(x: w * 0.30, y: h * 0.55))
            pectoralPath.addCurve(
                to: CGPoint(x: w * 0.20, y: h * 0.80),
                controlPoint1: CGPoint(x: w * 0.25, y: h * 0.65),
                controlPoint2: CGPoint(x: w * 0.20, y: h * 0.75)
            )
            pectoralPath.addCurve(
                to: CGPoint(x: w * 0.38, y: h * 0.60),
                controlPoint1: CGPoint(x: w * 0.25, y: h * 0.80),
                controlPoint2: CGPoint(x: w * 0.35, y: h * 0.70)
            )
            pectoralPath.close()
            UIColor(red: 1.0, green: 0.50, blue: 0.08, alpha: 0.6).setFill()
            pectoralPath.fill()

            // --- Eye ---
            let eyeCenter = CGPoint(x: w * 0.22, y: h * 0.42)
            let eyeRadius: CGFloat = w * 0.035

            // Eye white
            let eyePath = UIBezierPath(arcCenter: eyeCenter, radius: eyeRadius,
                                        startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor.white.setFill()
            eyePath.fill()

            // Pupil
            let pupilPath = UIBezierPath(arcCenter: CGPoint(x: eyeCenter.x + 1, y: eyeCenter.y),
                                          radius: eyeRadius * 0.55,
                                          startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor(white: 0.1, alpha: 1).setFill()
            pupilPath.fill()

            // Eye highlight
            let highlightPath = UIBezierPath(arcCenter: CGPoint(x: eyeCenter.x - 1, y: eyeCenter.y - 1),
                                              radius: eyeRadius * 0.25,
                                              startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor(white: 1, alpha: 0.9).setFill()
            highlightPath.fill()

            // --- Body highlight (specular) ---
            cg.saveGState()
            let highlightGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(white: 1, alpha: 0.3).cgColor,
                    UIColor(white: 1, alpha: 0).cgColor
                ] as CFArray,
                locations: [0, 1]
            )!
            cg.drawRadialGradient(
                highlightGradient,
                startCenter: CGPoint(x: w * 0.30, y: h * 0.35),
                startRadius: 0,
                endCenter: CGPoint(x: w * 0.30, y: h * 0.35),
                endRadius: w * 0.15,
                options: []
            )
            cg.restoreGState()

            // --- Scale pattern (subtle) ---
            cg.saveGState()
            bodyPath.addClip()
            UIColor(white: 1, alpha: 0.05).setStroke()
            for row in stride(from: h * 0.2, through: h * 0.8, by: 8) {
                for col in stride(from: w * 0.15, through: w * 0.75, by: 8) {
                    let offset: CGFloat = Int(row / 8) % 2 == 0 ? 4 : 0
                    let scalePath = UIBezierPath(
                        arcCenter: CGPoint(x: col + offset, y: row),
                        radius: 3.5,
                        startAngle: .pi * 0.8,
                        endAngle: .pi * 2.2,
                        clockwise: true
                    )
                    scalePath.lineWidth = 0.5
                    scalePath.stroke()
                }
            }
            cg.restoreGState()
        }

        return SKTexture(image: image)
    }
}
