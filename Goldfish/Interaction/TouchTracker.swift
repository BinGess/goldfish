import CoreGraphics
import Foundation

/// Tracks single-touch position, velocity, and idle time.
final class TouchTracker {

    /// Whether a finger is currently on screen.
    private(set) var isActive: Bool = false

    /// Current touch position (nil if no touch).
    private(set) var position: CGPoint?

    /// Smoothed touch velocity (points/second).
    private(set) var velocity: CGVector = .zero

    /// Speed of the touch (magnitude of velocity).
    var speed: CGFloat {
        sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
    }

    /// Last known touch position (persists after touch ends for glide).
    private(set) var lastPosition: CGPoint?

    /// Time since last touch ended (seconds).
    private(set) var idleTime: TimeInterval = 0

    private var previousPosition: CGPoint?
    private var velocitySmoothing: CGFloat = 0.3 // EMA factor

    // MARK: - Touch Events

    func touchBegan(at point: CGPoint) {
        isActive = true
        position = point
        previousPosition = point
        lastPosition = point
        velocity = .zero
        idleTime = 0
    }

    func touchMoved(to point: CGPoint) {
        position = point
        lastPosition = point
    }

    func touchEnded() {
        isActive = false
        position = nil
        previousPosition = nil
    }

    // MARK: - Per-Frame Update

    func update(dt: TimeInterval) {
        if isActive, let pos = position {
            // Calculate instantaneous velocity
            if let prev = previousPosition, dt > 0 {
                let rawVx = (pos.x - prev.x) / CGFloat(dt)
                let rawVy = (pos.y - prev.y) / CGFloat(dt)

                // Exponential moving average for smoothing
                let alpha = velocitySmoothing
                velocity.dx = velocity.dx * (1 - alpha) + rawVx * alpha
                velocity.dy = velocity.dy * (1 - alpha) + rawVy * alpha
            }
            previousPosition = pos
            idleTime = 0
        } else {
            // Decay velocity when not touching
            velocity.dx *= 0.9
            velocity.dy *= 0.9
            if speed < 1 {
                velocity = .zero
            }
            idleTime += dt
        }
    }
}
