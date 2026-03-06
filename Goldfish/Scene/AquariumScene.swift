import SpriteKit

/// Main SpriteKit scene: owns the game loop, goldfish entity, and debug overlay.
/// Implements a fixed-timestep accumulator for stable Verlet physics.
final class AquariumScene: SKScene {

    // MARK: - Subsystems

    private var fish: GoldfishEntity!
    private var touchTracker = TouchTracker()
    private var debugOverlay: DebugOverlay!
    private var performanceMonitor = PerformanceMonitor()

    // MARK: - Physics Accumulator

    private var physicsAccumulator: TimeInterval = 0
    private let fixedDt = FishConfig.physicsTickRate // 1/120s

    // MARK: - State Label

    private var stateLabel: SKLabelNode!

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = SKColor(red: 0.05, green: 0.15, blue: 0.3, alpha: 1.0)

        // Initialize fish at screen center
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        fish = GoldfishEntity(position: center)
        fish.bounds = CGRect(origin: .zero, size: size)
        fish.screenWidth = size.width

        // Setup fish visual rendering
        fish.setupRendering(in: self)

        // Debug overlay (on top of fish)
        debugOverlay = DebugOverlay()
        addChild(debugOverlay.node)

        // State label
        stateLabel = SKLabelNode(fontNamed: "Menlo")
        stateLabel.fontSize = 14
        stateLabel.fontColor = .white
        stateLabel.horizontalAlignmentMode = .left
        stateLabel.verticalAlignmentMode = .top
        stateLabel.position = CGPoint(x: 10, y: size.height - 10)
        stateLabel.zPosition = 1001
        addChild(stateLabel)

        Time.reset()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        fish?.bounds = CGRect(origin: .zero, size: size)
        fish?.screenWidth = size.width
        stateLabel?.position = CGPoint(x: 10, y: size.height - 10)
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        let dt = Time.update(currentTime)
        guard dt > 0 else { return }

        performanceMonitor.recordFrame(deltaTime: dt)

        // Update touch tracker
        touchTracker.update(dt: dt)

        // Fixed timestep physics
        physicsAccumulator += dt
        var ticks = 0
        let maxTicks = 4
        while physicsAccumulator >= fixedDt && ticks < maxTicks {
            fish.update(dt: fixedDt, touchTracker: touchTracker)
            physicsAccumulator -= fixedDt
            ticks += 1
        }
        if physicsAccumulator > fixedDt {
            physicsAccumulator = 0
        }

        // Render debug overlay
        debugOverlay.update(
            spinePositions: fish.spinePositions,
            headAngle: fish.headAngle,
            targetPosition: touchTracker.position ?? touchTracker.lastPosition
        )

        // Update state label
        let state = fish.stateManager.currentState.rawValue.uppercased()
        let fps = String(format: "%.0f", performanceMonitor.averageFPS)
        let spd = String(format: "%.0f", fish.steeringAgent.speed)
        stateLabel.text = "State: \(state)  Speed: \(spd)  FPS: \(fps)"
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        touchTracker.touchBegan(at: touch.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        touchTracker.touchMoved(to: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchTracker.touchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchTracker.touchEnded()
    }
}
