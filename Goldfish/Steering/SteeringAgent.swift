import CoreGraphics
import Foundation

/// Autonomous agent model with position, velocity, and force limits.
/// Produces a steering force each frame that drives the fish head.
final class SteeringAgent {
    /// Current position (synced with spine head).
    var position: CGPoint
    /// Current velocity vector.
    var velocity: CGVector = .zero
    /// Maximum swimming speed (points/second).
    var maxSpeed: CGFloat = FishConfig.maxSpeed
    /// Maximum steering force (points/second²).
    var maxForce: CGFloat = FishConfig.maxForce

    init(position: CGPoint) {
        self.position = position
    }

    /// Current speed (magnitude of velocity).
    var speed: CGFloat {
        sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
    }

    /// Heading angle in radians.
    var heading: CGFloat {
        atan2(velocity.dy, velocity.dx)
    }

    /// Normalized heading vector (or zero if stationary).
    var headingVector: CGVector {
        let s = speed
        guard s > 0.01 else { return .zero }
        return CGVector(dx: velocity.dx / s, dy: velocity.dy / s)
    }

    /// Apply a steering force, update velocity and position.
    func update(steeringForce: CGVector, dt: TimeInterval) {
        let dtf = CGFloat(dt)

        // Apply steering force (clamped)
        var force = steeringForce
        let fMag = sqrt(force.dx * force.dx + force.dy * force.dy)
        if fMag > maxForce {
            let scale = maxForce / fMag
            force.dx *= scale
            force.dy *= scale
        }

        // Update velocity
        velocity.dx += force.dx * dtf
        velocity.dy += force.dy * dtf

        // Clamp to max speed
        let s = speed
        if s > maxSpeed {
            let scale = maxSpeed / s
            velocity.dx *= scale
            velocity.dy *= scale
        }

        // Update position
        position.x += velocity.dx * dtf
        position.y += velocity.dy * dtf
    }
}
