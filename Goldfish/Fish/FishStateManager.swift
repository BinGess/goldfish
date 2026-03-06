import CoreGraphics
import Foundation

/// The behavioral state of the goldfish.
enum FishState: String {
    /// No touch: fish wanders autonomously.
    case idle
    /// Finger stationary or slow: fish approaches curiously, then circles.
    case curious
    /// Finger moving moderately: fish chases.
    case chase
    /// Finger moving fast: fish darts away.
    case flee
    /// No touch for 30+ seconds: fish drifts lazily.
    case lazy
}

/// Manages transitions between fish behavioral states.
final class FishStateManager {

    private(set) var currentState: FishState = .idle
    private var idleTimer: TimeInterval = 0
    private var fleeTimer: TimeInterval = 0
    private var postTouchTimer: TimeInterval = 0
    private var isPostTouchGlide = false

    /// Orbit direction for curious circling (randomized on enter).
    private(set) var orbitClockwise: Bool = Bool.random()

    /// Evaluate touch input and update state.
    /// - Parameters:
    ///   - touchActive: Whether a finger is currently on screen.
    ///   - touchSpeed: Speed of the touch point in points/second.
    ///   - dt: Frame delta time.
    func update(touchActive: Bool, touchSpeed: CGFloat, dt: TimeInterval) {
        if touchActive {
            idleTimer = 0
            isPostTouchGlide = false
            postTouchTimer = 0

            if currentState == .flee {
                // Stay in flee until timer expires
                fleeTimer -= dt
                if fleeTimer <= 0 {
                    transitionTo(.chase)
                }
                return
            }

            if touchSpeed > FishConfig.fleeSpeedThreshold {
                transitionTo(.flee)
                fleeTimer = FishConfig.fleeDuration
            } else if touchSpeed > FishConfig.curiousSpeedThreshold {
                transitionTo(.chase)
            } else {
                transitionTo(.curious)
            }
        } else {
            // No touch
            if isPostTouchGlide {
                postTouchTimer -= dt
                if postTouchTimer <= 0 {
                    isPostTouchGlide = false
                    transitionTo(.idle)
                }
                return
            }

            if currentState == .flee {
                fleeTimer -= dt
                if fleeTimer <= 0 {
                    startPostTouchGlide()
                }
                return
            }

            if currentState == .chase || currentState == .curious {
                startPostTouchGlide()
                return
            }

            // Idle / lazy logic
            idleTimer += dt
            if idleTimer >= FishConfig.idleTimeout {
                transitionTo(.lazy)
            } else if currentState != .idle && currentState != .lazy {
                transitionTo(.idle)
            }
        }
    }

    private func startPostTouchGlide() {
        isPostTouchGlide = true
        postTouchTimer = FishConfig.postTouchGlideDuration
    }

    private func transitionTo(_ newState: FishState) {
        guard newState != currentState else { return }
        let oldState = currentState
        currentState = newState

        // On-enter actions
        switch newState {
        case .curious:
            orbitClockwise = Bool.random()
        case .idle:
            idleTimer = 0
        default:
            break
        }

        _ = oldState // Suppress unused variable warning; available for logging
    }

    /// Reset to idle state.
    func reset() {
        currentState = .idle
        idleTimer = 0
        fleeTimer = 0
        postTouchTimer = 0
        isPostTouchGlide = false
    }
}
