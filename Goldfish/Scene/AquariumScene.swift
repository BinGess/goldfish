import SpriteKit

/// Main SpriteKit scene: owns the game loop, goldfish entity, background, and debug overlay.
/// Implements a fixed-timestep accumulator for stable Verlet physics.
final class AquariumScene: SKScene {

    // MARK: - Subsystems

    private var fish: GoldfishEntity!
    private var touchTracker = TouchTracker()
    private var debugOverlay: DebugOverlay!
    private var backgroundLayer: BackgroundLayer!
    private var performanceMonitor = PerformanceMonitor()

    // MARK: - Physics Accumulator

    private var physicsAccumulator: TimeInterval = 0
    private let fixedDt = FishConfig.physicsTickRate // 1/120s

    // MARK: - Debug

    private var stateLabel: SKLabelNode!
    private var debugVisible = false
    private var lastTouchTime: TimeInterval = 0

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = SKColor(red: 0.02, green: 0.08, blue: 0.22, alpha: 1.0)

        // Water background
        backgroundLayer = BackgroundLayer(size: size)
        addChild(backgroundLayer.node)

        // Initialize fish at screen center
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        fish = GoldfishEntity(position: center)
        fish.bounds = CGRect(origin: .zero, size: size)
        fish.screenWidth = size.width

        // Setup fish visual rendering
        fish.setupRendering(in: self)

        // Debug overlay (on top of everything, hidden by default)
        debugOverlay = DebugOverlay()
        debugOverlay.isVisible = debugVisible
        addChild(debugOverlay.node)

        // State label (only visible in debug mode)
        stateLabel = SKLabelNode(fontNamed: "Menlo")
        stateLabel.fontSize = 12
        stateLabel.fontColor = SKColor(white: 1, alpha: 0.7)
        stateLabel.horizontalAlignmentMode = .left
        stateLabel.verticalAlignmentMode = .top
        stateLabel.position = CGPoint(x: 10, y: size.height - 60)
        stateLabel.zPosition = 1001
        stateLabel.isHidden = !debugVisible
        addChild(stateLabel)

        Time.reset()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        fish?.bounds = CGRect(origin: .zero, size: size)
        fish?.screenWidth = size.width
        stateLabel?.position = CGPoint(x: 10, y: size.height - 60)
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

        // Render debug overlay (only if visible)
        if debugVisible {
            debugOverlay.update(
                spinePositions: fish.spinePositions,
                headAngle: fish.headAngle,
                targetPosition: touchTracker.position ?? touchTracker.lastPosition
            )

            let state = fish.stateManager.currentState.rawValue.uppercased()
            let fps = String(format: "%.0f", performanceMonitor.averageFPS)
            let spd = String(format: "%.0f", fish.steeringAgent.speed)
            stateLabel.text = "[\(state)]  v=\(spd)  \(fps)fps  deg=\(performanceMonitor.degradationLevel)"
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let pos = touch.location(in: self)

        // Double-tap detection for debug toggle
        if touch.tapCount == 2 {
            toggleDebug()
            return
        }

        touchTracker.touchBegan(at: pos)
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

    // MARK: - Debug Toggle

    private func toggleDebug() {
        debugVisible.toggle()
        debugOverlay.isVisible = debugVisible
        stateLabel.isHidden = !debugVisible
    }
}
