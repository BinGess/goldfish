import SpriteKit

/// Visualizes the spine chain as connected circles and lines.
/// Toggle visibility for debugging physics behavior.
final class DebugOverlay {

    let node: SKNode
    private var particleNodes: [SKShapeNode] = []
    private var lineNode: SKShapeNode
    private var targetNode: SKShapeNode
    private var headingNode: SKShapeNode

    /// Whether the overlay is visible.
    var isVisible: Bool {
        get { node.isHidden == false }
        set { node.isHidden = !newValue }
    }

    init() {
        node = SKNode()
        node.name = "debugOverlay"
        node.zPosition = 1000 // Always on top

        // Line connecting all spine particles
        lineNode = SKShapeNode()
        lineNode.strokeColor = SKColor(white: 1.0, alpha: 0.4)
        lineNode.lineWidth = 1.5
        lineNode.lineCap = .round
        node.addChild(lineNode)

        // Target indicator
        targetNode = SKShapeNode(circleOfRadius: 8)
        targetNode.fillColor = SKColor(red: 1, green: 0.3, blue: 0.3, alpha: 0.5)
        targetNode.strokeColor = SKColor(red: 1, green: 0.3, blue: 0.3, alpha: 0.8)
        targetNode.lineWidth = 1
        targetNode.isHidden = true
        node.addChild(targetNode)

        // Heading direction indicator
        headingNode = SKShapeNode()
        headingNode.strokeColor = SKColor(red: 0.3, green: 1, blue: 0.3, alpha: 0.6)
        headingNode.lineWidth = 2
        node.addChild(headingNode)

        // Create particle circle nodes (will be positioned in update)
        for i in 0..<FishConfig.spineParticleCount {
            let radius: CGFloat = i == 0 ? 8 : (i < FishConfig.spineParticleCount - 2 ? 5 : 4)
            let circle = SKShapeNode(circleOfRadius: radius)
            if i == 0 {
                // Head: bright orange
                circle.fillColor = SKColor(red: 1, green: 0.6, blue: 0.1, alpha: 0.9)
                circle.strokeColor = SKColor.white
            } else if i >= FishConfig.spineParticleCount - 2 {
                // Tail particles: cyan
                circle.fillColor = SKColor(red: 0.1, green: 0.8, blue: 1, alpha: 0.7)
                circle.strokeColor = SKColor(red: 0.1, green: 0.8, blue: 1, alpha: 0.9)
            } else {
                // Body particles: light blue
                circle.fillColor = SKColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.6)
                circle.strokeColor = SKColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.8)
            }
            circle.lineWidth = 1.5
            node.addChild(circle)
            particleNodes.append(circle)
        }
    }

    /// Update the overlay with current spine state.
    func update(spinePositions: [CGPoint], headAngle: CGFloat, targetPosition: CGPoint?) {
        guard !node.isHidden else { return }

        // Update particle positions
        for (i, pos) in spinePositions.enumerated() where i < particleNodes.count {
            particleNodes[i].position = pos
        }

        // Update connecting line
        if spinePositions.count >= 2 {
            let path = CGMutablePath()
            path.move(to: spinePositions[0])
            for i in 1..<spinePositions.count {
                path.addLine(to: spinePositions[i])
            }
            lineNode.path = path
        }

        // Update heading indicator (line from head in heading direction)
        if let headPos = spinePositions.first {
            let length: CGFloat = 40
            let endX = headPos.x + cos(headAngle) * length
            let endY = headPos.y + sin(headAngle) * length
            let headingPath = CGMutablePath()
            headingPath.move(to: headPos)
            headingPath.addLine(to: CGPoint(x: endX, y: endY))
            headingNode.path = headingPath
        }

        // Update target indicator
        if let target = targetPosition {
            targetNode.position = target
            targetNode.isHidden = false
        } else {
            targetNode.isHidden = true
        }
    }
}
