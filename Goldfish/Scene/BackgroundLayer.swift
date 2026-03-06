import SpriteKit

/// Creates an immersive water-bottom background with gradient, caustics, and floating particles.
final class BackgroundLayer {

    let node: SKNode

    init(size: CGSize) {
        node = SKNode()
        node.name = "backgroundLayer"
        node.zPosition = -100

        // --- Water gradient background ---
        let gradientTexture = BackgroundLayer.createGradientTexture(size: size)
        let bg = SKSpriteNode(texture: gradientTexture, size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -10
        node.addChild(bg)

        // --- Subtle light caustics (animated) ---
        addCaustics(size: size)

        // --- Floating particles (dust/bubbles) ---
        addFloatingParticles(size: size)
    }

    // MARK: - Gradient Texture

    private static func createGradientTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 0.02, green: 0.08, blue: 0.22, alpha: 1).cgColor,  // Deep blue (bottom)
                UIColor(red: 0.04, green: 0.14, blue: 0.32, alpha: 1).cgColor,  // Mid blue
                UIColor(red: 0.06, green: 0.20, blue: 0.40, alpha: 1).cgColor,  // Lighter (top)
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.6, 1.0]
            )!
            // Draw bottom-to-top gradient
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height),  // Top in UIKit = bottom in SpriteKit
                end: CGPoint(x: 0, y: 0),
                options: []
            )
        }
        return SKTexture(image: image)
    }

    // MARK: - Caustics

    private func addCaustics(size: CGSize) {
        // Create several overlapping semi-transparent shapes that drift slowly
        for i in 0..<6 {
            let caustic = SKShapeNode(ellipseOf: CGSize(
                width: CGFloat.random(in: 80...200),
                height: CGFloat.random(in: 60...150)
            ))
            caustic.fillColor = SKColor(white: 1, alpha: CGFloat.random(in: 0.02...0.05))
            caustic.strokeColor = .clear
            caustic.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            caustic.zPosition = -5
            caustic.alpha = 0.5

            // Slow drifting animation
            let duration = TimeInterval.random(in: 8...15)
            let dx = CGFloat.random(in: -60...60)
            let dy = CGFloat.random(in: -40...40)
            let moveAction = SKAction.sequence([
                SKAction.moveBy(x: dx, y: dy, duration: duration),
                SKAction.moveBy(x: -dx, y: -dy, duration: duration)
            ])
            let fadeAction = SKAction.sequence([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.2...0.6), duration: duration * 0.7),
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.3...0.8), duration: duration * 0.3),
            ])
            caustic.run(SKAction.repeatForever(SKAction.group([moveAction, fadeAction])))

            node.addChild(caustic)
            _ = i // suppress unused warning
        }
    }

    // MARK: - Floating Particles

    private func addFloatingParticles(size: CGSize) {
        for _ in 0..<15 {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2))
            particle.fillColor = SKColor(white: 1, alpha: CGFloat.random(in: 0.1...0.3))
            particle.strokeColor = .clear
            particle.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            particle.zPosition = -1

            // Slow upward drift (like bubbles/dust)
            let driftDuration = TimeInterval.random(in: 10...25)
            let driftY = CGFloat.random(in: 50...150)
            let driftX = CGFloat.random(in: -30...30)

            let drift = SKAction.sequence([
                SKAction.moveBy(x: driftX, y: driftY, duration: driftDuration),
                SKAction.moveBy(x: -driftX, y: -driftY, duration: driftDuration)
            ])
            let fade = SKAction.sequence([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.05...0.15), duration: driftDuration * 0.5),
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.15...0.35), duration: driftDuration * 0.5),
            ])
            particle.run(SKAction.repeatForever(SKAction.group([drift, fade])))

            node.addChild(particle)
        }
    }
}
