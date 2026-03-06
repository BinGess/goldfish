import CoreGraphics
import Foundation
import SpriteKit

/// Orchestrates all goldfish subsystems: steering, physics, oscillation, state, rendering.
final class GoldfishEntity {

    // MARK: - Subsystems

    let steeringAgent: SteeringAgent
    let spineChain: SpineChain
    let motionDriver: FishMotionDriver
    let stateManager: FishStateManager
    private var wanderState = WanderState()

    /// Visual rendering (nil until setupRendering is called).
    private(set) var spriteAssembler: FishSpriteAssembler?

    // MARK: - Configuration

    /// Aquarium bounds for wall avoidance and boundary clamping.
    var bounds: CGRect = .zero {
        didSet { spineChain.bounds = bounds }
    }

    /// Screen width (used for speed normalization in interaction).
    var screenWidth: CGFloat = 390

    // MARK: - Init

    init(position: CGPoint) {
        steeringAgent = SteeringAgent(position: position)
        spineChain = SpineChain(headPosition: position)
        motionDriver = FishMotionDriver()
        stateManager = FishStateManager()

        // Give initial velocity so wander has a heading
        steeringAgent.velocity = CGVector(dx: 30, dy: 10)
    }

    /// Setup visual rendering. Call after init, adds fish sprite to the scene.
    func setupRendering(in scene: SKScene) {
        let texture = FishTextureGenerator.generateBodyTexture(
            size: CGSize(width: 512, height: 256)
        )
        let assembler = FishSpriteAssembler(
            texture: texture,
            bodyLength: 240,
            bodyWidth: 90
        )
        scene.addChild(assembler.rootNode)
        self.spriteAssembler = assembler
    }

    // MARK: - Positions for Rendering

    var spinePositions: [CGPoint] { spineChain.positions }
    var headAngle: CGFloat { spineChain.headAngle }
    var headPosition: CGPoint { spineChain.head.position }

    // MARK: - Update

    /// Main update called from the scene's fixed timestep loop.
    func update(dt: TimeInterval, touchTracker: TouchTracker) {
        // 1. Update state machine
        stateManager.update(
            touchActive: touchTracker.isActive,
            touchSpeed: touchTracker.speed,
            dt: dt
        )

        // 2. Compute steering force based on current state
        let steeringForce = computeSteeringForce(touchTracker: touchTracker)

        // 3. Apply speed limits based on state
        applyStateSpeedLimits()

        // 4. Update steering agent (velocity + position)
        steeringAgent.update(steeringForce: steeringForce, dt: dt)

        // 5. Clamp agent position to bounds
        clampAgentToBounds()

        // 6. Sync spine head to agent position
        spineChain.setHeadPosition(steeringAgent.position)

        // 7. Apply oscillation forces
        applyOscillation(dt: dt)

        // 8. Simulate spine physics
        spineChain.simulate(dt: dt)

        // 9. Update visual rendering (after physics, outside fixed timestep)
        spriteAssembler?.update(
            spinePositions: spineChain.positions,
            spineAngles: spineChain.angles
        )
    }

    // MARK: - Steering Force Computation

    private func computeSteeringForce(touchTracker: TouchTracker) -> CGVector {
        var forces: [WeightedForce] = []

        // Wall avoidance always active (high priority)
        let wallForce = SteeringBehaviors.wallAvoidance(
            agent: steeringAgent,
            bounds: bounds,
            margin: FishConfig.wallMargin
        )
        forces.append(WeightedForce(force: wallForce, weight: 2.0))

        switch stateManager.currentState {
        case .idle:
            let wanderForce = SteeringBehaviors.wander(
                agent: steeringAgent,
                state: &wanderState
            )
            forces.append(WeightedForce(force: wanderForce, weight: 1.0))

        case .curious:
            if let target = touchTracker.position ?? touchTracker.lastPosition {
                let dist = distanceTo(target)
                if dist > FishConfig.curiousOrbitRadius * 0.8 {
                    // Approach slowly
                    let arriveForce = SteeringBehaviors.arrive(
                        agent: steeringAgent,
                        target: target,
                        slowingRadius: FishConfig.curiousOrbitRadius
                    )
                    forces.append(WeightedForce(force: arriveForce, weight: 1.2))
                } else {
                    // Orbit around touch point
                    let orbitForce = SteeringBehaviors.orbit(
                        agent: steeringAgent,
                        center: target,
                        radius: 30,
                        clockwise: stateManager.orbitClockwise
                    )
                    forces.append(WeightedForce(force: orbitForce, weight: 1.2))
                }
            } else {
                // Fallback to wander
                let wanderForce = SteeringBehaviors.wander(agent: steeringAgent, state: &wanderState)
                forces.append(WeightedForce(force: wanderForce, weight: 1.0))
            }

        case .chase:
            if let target = touchTracker.position ?? touchTracker.lastPosition {
                let seekForce = SteeringBehaviors.seek(agent: steeringAgent, target: target)
                forces.append(WeightedForce(force: seekForce, weight: 1.5))
            }

        case .flee:
            if let threat = touchTracker.position ?? touchTracker.lastPosition {
                let fleeForce = SteeringBehaviors.flee(agent: steeringAgent, threat: threat)
                forces.append(WeightedForce(force: fleeForce, weight: 2.0))
            }

        case .lazy:
            // Slow, lazy wander
            let wanderForce = SteeringBehaviors.wander(agent: steeringAgent, state: &wanderState)
            forces.append(WeightedForce(force: wanderForce, weight: 0.5))
        }

        return BehaviorCombiner.combine(forces: forces, maxForce: steeringAgent.maxForce)
    }

    // MARK: - State-Dependent Speed Limits

    private func applyStateSpeedLimits() {
        switch stateManager.currentState {
        case .idle:
            steeringAgent.maxSpeed = FishConfig.maxSpeed * 0.5
            motionDriver.frequencyMultiplier = 1.0
            motionDriver.amplitudeMultiplier = 1.0

        case .curious:
            steeringAgent.maxSpeed = screenWidth * FishConfig.curiousSpeedFraction
            motionDriver.frequencyMultiplier = 0.7
            motionDriver.amplitudeMultiplier = 0.8

        case .chase:
            steeringAgent.maxSpeed = screenWidth * FishConfig.chaseSpeedFraction
            motionDriver.frequencyMultiplier = 1.3
            motionDriver.amplitudeMultiplier = 1.2

        case .flee:
            steeringAgent.maxSpeed = screenWidth * FishConfig.fleeSpeedFraction
            motionDriver.frequencyMultiplier = 1.8
            motionDriver.amplitudeMultiplier = 1.5

        case .lazy:
            steeringAgent.maxSpeed = FishConfig.maxSpeed * FishConfig.lazySpeedMultiplier * 0.4
            motionDriver.frequencyMultiplier = FishConfig.lazyFrequencyMultiplier
            motionDriver.amplitudeMultiplier = 0.6
        }
    }

    // MARK: - Oscillation

    private func applyOscillation(dt: TimeInterval) {
        motionDriver.drive(
            spine: spineChain,
            speed: steeringAgent.speed,
            maxSpeed: steeringAgent.maxSpeed,
            dt: dt
        )
    }

    // MARK: - Helpers

    private func clampAgentToBounds() {
        guard bounds != .zero else { return }
        let margin: CGFloat = 20
        steeringAgent.position.x = max(bounds.minX + margin,
                                        min(bounds.maxX - margin, steeringAgent.position.x))
        steeringAgent.position.y = max(bounds.minY + margin,
                                        min(bounds.maxY - margin, steeringAgent.position.y))
    }

    private func distanceTo(_ point: CGPoint) -> CGFloat {
        let dx = steeringAgent.position.x - point.x
        let dy = steeringAgent.position.y - point.y
        return sqrt(dx * dx + dy * dy)
    }
}
