import CoreGraphics
import Foundation

/// All tunable parameters, centralized for easy adjustment.
enum FishConfig {

    // MARK: - Spine Chain

    /// Number of particles in the spine chain.
    static let spineParticleCount = 8
    /// Rest distance between adjacent spine particles (points).
    static let spineSegmentLength: CGFloat = 30
    /// Number of constraint solver iterations per physics tick.
    static let spineConstraintIterations = 4
    /// Verlet damping factor (0-1, lower = more energy loss).
    static let spineDamping: CGFloat = 0.98
    /// Water drag coefficient applied as velocity-proportional force.
    static let waterDragCoefficient: CGFloat = 0.03

    // MARK: - Oscillation

    /// Base tail-beat frequency (Hz) at rest.
    static let baseFrequency: CGFloat = 2.5
    /// Base lateral amplitude (points) of body oscillation.
    static let baseAmplitude: CGFloat = 15
    /// Amplitude gradient: 0 = uniform, 1 = tail-only. Controls how much more the tail sways vs head.
    static let amplitudeGradient: CGFloat = 0.3
    /// Multiplier for converting wave displacement to force.
    static let oscillationForceScale: CGFloat = 80

    // MARK: - Steering

    /// Maximum swimming speed (points/second).
    static let maxSpeed: CGFloat = 200
    /// Maximum steering force magnitude (points/second²).
    static let maxForce: CGFloat = 400
    /// Wander behavior: radius of the wander circle.
    static let wanderRadius: CGFloat = 50
    /// Wander behavior: distance of the wander circle ahead of agent.
    static let wanderDistance: CGFloat = 80
    /// Wander behavior: max random angle jitter per frame (radians).
    static let wanderJitter: CGFloat = 0.3
    /// Wall avoidance margin from screen edges (points).
    static let wallMargin: CGFloat = 140
    /// Wall avoidance maximum repulsion force multiplier.
    static let wallForceMultiplier: CGFloat = 1.5
    /// Maximum turn rate (radians per second). Limits how fast the fish can change heading.
    static let maxTurnRate: CGFloat = 3.0
    /// Maximum bend angle between consecutive spine segments (radians, ~29°).
    static let maxSpineBendAngle: CGFloat = 0.5

    // MARK: - Interaction

    /// Touch speed below this = curious/seek mode (points/second).
    static let curiousSpeedThreshold: CGFloat = 100
    /// Touch speed above this = flee mode (points/second).
    static let fleeSpeedThreshold: CGFloat = 400
    /// Seconds of no-touch before entering lazy mode.
    static let idleTimeout: TimeInterval = 30
    /// Orbit radius in curious/circling mode (points).
    static let curiousOrbitRadius: CGFloat = 120
    /// Speed in curious approach mode (fraction of screen width per second).
    static let curiousSpeedFraction: CGFloat = 0.05
    /// Speed in chase mode (fraction of screen width per second).
    static let chaseSpeedFraction: CGFloat = 0.15
    /// Speed in flee mode (fraction of screen width per second).
    static let fleeSpeedFraction: CGFloat = 0.20
    /// Duration of flee burst before recovering (seconds).
    static let fleeDuration: TimeInterval = 2.0
    /// Duration to continue toward last touch point after release (seconds).
    static let postTouchGlideDuration: TimeInterval = 1.0

    // MARK: - Warp Grid

    /// Columns in the body warp grid.
    static let bodyWarpColumns = 3
    /// Rows in the body warp grid.
    static let bodyWarpRows = 5

    // MARK: - Physics Timing

    /// Fixed physics timestep (seconds). 120Hz = 2 ticks per 60fps frame.
    static let physicsTickRate: TimeInterval = 1.0 / 120.0
    /// Maximum particle velocity (points/second) to prevent explosion.
    static let maxParticleSpeed: CGFloat = 500

    // MARK: - Wall Feelers

    /// Look-ahead time for feeler-based wall detection (seconds).
    /// Fish "sees" this far ahead and starts curving before proximity repulsion kicks in.
    static let wallFeelerTime: CGFloat = 0.85
    /// Side feeler angle offset from heading (radians, ≈33°).
    static let wallFeelerAngle: CGFloat = .pi / 5.5
    /// Feeler trigger zone as a fraction of wallMargin.
    static let wallFeelerMarginFraction: CGFloat = 0.55

    // MARK: - Turn Feel

    /// Turn speed reduction factor [0,1]. Higher = more speed loss during sharp turns.
    /// Was hardcoded 0.3; increased to 0.55 for more realistic deceleration.
    static let maxTurnSpeedReduction: CGFloat = 0.55
    /// Lateral force applied to mid-body spine particles during turns (pts/s², pre-multiplied by dt).
    /// Creates active C-shape body flexing into the turn direction.
    static let turnBodyFlexForce: CGFloat = 600

    // MARK: - Performance

    /// FPS threshold to trigger degradation.
    static let degradationThresholdFPS: Float = 50
    /// FPS threshold to restore quality (with hysteresis).
    static let restorationThresholdFPS: Float = 55

    // MARK: - Autonomous Behavior

    /// Min interval for random target generation (seconds).
    static let wanderTargetIntervalMin: TimeInterval = 3
    /// Max interval for random target generation (seconds).
    static let wanderTargetIntervalMax: TimeInterval = 8
    /// Lazy mode speed multiplier.
    static let lazySpeedMultiplier: CGFloat = 0.5
    /// Lazy mode frequency multiplier.
    static let lazyFrequencyMultiplier: CGFloat = 0.8
}

/// Runtime tuning values controlled by the on-screen motion panel.
struct MotionTuningValues {
    var enabled: Bool
    /// Shared smoothing factor used by steering and state transitions.
    var speedSmoothing: CGFloat
    /// Global multiplier for tail/body oscillation amplitude.
    var tailAmplitudeScale: CGFloat
    /// Scales curious/chase/flee state thresholds together.
    var stateThresholdScale: CGFloat

    static let `default` = MotionTuningValues(
        enabled: true,
        speedSmoothing: 0.30,
        tailAmplitudeScale: 1.0,
        stateThresholdScale: 1.0
    )
}
