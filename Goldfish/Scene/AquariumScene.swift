import SpriteKit

/// Main SpriteKit scene: owns the game loop, goldfish entity, background, and debug overlay.
/// Implements a fixed-timestep accumulator for stable Verlet physics.
final class AquariumScene: SKScene {

    // MARK: - Subsystems

    private var fish: GoldfishEntity?
    private var touchTracker = TouchTracker()
    private var debugOverlay: DebugOverlay?
    private var backgroundLayer: BackgroundLayer?
    private var performanceMonitor = PerformanceMonitor()
    private var motionTuning: MotionTuningValues = .default

    // MARK: - Physics Accumulator

    private var physicsAccumulator: TimeInterval = 0
    private let fixedDt = FishConfig.physicsTickRate // 1/120s

    // MARK: - Debug

    private var stateLabel: SKLabelNode?
    private var debugVisible = false
    private var sceneInitialized = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = SKColor(red: 0.02, green: 0.08, blue: 0.22, alpha: 1.0)
        setupSceneContentIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)

        if sceneInitialized, oldSize != size {
            backgroundLayer?.node.removeFromParent()
            let newBackground = BackgroundLayer(size: size)
            backgroundLayer = newBackground
            addChild(newBackground.node)
        }

        setupSceneContentIfNeeded()
        fish?.bounds = CGRect(origin: .zero, size: size)
        fish?.screenWidth = size.width
        stateLabel?.position = CGPoint(x: 10, y: size.height - 60)
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        setupSceneContentIfNeeded()
        guard let fish else { return }

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
            debugOverlay?.update(
                spinePositions: fish.spinePositions,
                headAngle: fish.headAngle,
                targetPosition: touchTracker.position ?? touchTracker.lastPosition
            )
            debugOverlay?.updateFeelers(
                agentPosition: fish.headPosition,
                velocity: fish.steeringAgent.velocity,
                speed: fish.steeringAgent.speed,
                bounds: fish.bounds
            )

            let state = fish.stateManager.currentState.rawValue.uppercased()
            let fps   = String(format: "%.0f", performanceMonitor.averageFPS)
            let spd   = String(format: "%.0f", fish.steeringAgent.speed)
            let angV  = String(format: "%.1f", fish.steeringAgent.angularVelocity)
            stateLabel?.text = "[\(state)]  v=\(spd)  ω=\(angV)rad/s  \(fps)fps"
        }
    }

    /// Called by the host SwiftUI panel to update runtime motion tuning.
    func setMotionTuning(_ tuning: MotionTuningValues) {
        motionTuning = tuning
        fish?.applyMotionTuning(tuning)
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
        debugOverlay?.isVisible = debugVisible
        stateLabel?.isHidden = !debugVisible
    }

    private func setupSceneContentIfNeeded() {
        guard !sceneInitialized else { return }
        guard size.width > 1, size.height > 1 else { return }

        let background = BackgroundLayer(size: size)
        backgroundLayer = background
        addChild(background.node)

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let fish = GoldfishEntity(position: center)
        fish.bounds = CGRect(origin: .zero, size: size)
        fish.screenWidth = size.width
        fish.applyMotionTuning(motionTuning)
        fish.setupRendering(in: self)
        self.fish = fish

        let overlay = DebugOverlay()
        overlay.isVisible = debugVisible
        debugOverlay = overlay
        addChild(overlay.node)

        let label = SKLabelNode(fontNamed: "Menlo")
        label.fontSize = 12
        label.fontColor = SKColor(white: 1, alpha: 0.7)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: 10, y: size.height - 60)
        label.zPosition = 1001
        label.isHidden = !debugVisible
        stateLabel = label
        addChild(label)

        physicsAccumulator = 0
        Time.reset()
        sceneInitialized = true
    }
}
