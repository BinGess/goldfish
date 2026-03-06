import CoreGraphics
import Foundation

/// A single particle in the Verlet integration system.
/// Position-based physics: velocity is implicit from (position - previousPosition).
final class VerletParticle {
    /// Current position.
    var position: CGPoint
    /// Position from the previous physics tick.
    var previousPosition: CGPoint
    /// Accumulated acceleration for this tick (reset after integration).
    var acceleration: CGVector = .zero
    /// If true, position is externally controlled (e.g., fish head).
    var pinned: Bool

    init(position: CGPoint, pinned: Bool = false) {
        self.position = position
        self.previousPosition = position
        self.pinned = pinned
    }

    /// Implicit velocity derived from position history.
    var velocity: CGVector {
        CGVector(dx: position.x - previousPosition.x,
                 dy: position.y - previousPosition.y)
    }

    /// Perform Verlet integration step.
    func integrate(dt: TimeInterval, damping: CGFloat) {
        guard !pinned else {
            acceleration = .zero
            return
        }
        let vel = velocity
        let dtSq = CGFloat(dt * dt)

        let newX = position.x + vel.dx * damping + acceleration.dx * dtSq
        let newY = position.y + vel.dy * damping + acceleration.dy * dtSq

        previousPosition = position
        position = CGPoint(x: newX, y: newY)

        // Clamp velocity to prevent explosion
        let newVel = self.velocity
        let speed = sqrt(newVel.dx * newVel.dx + newVel.dy * newVel.dy)
        let maxSpeed = FishConfig.maxParticleSpeed * CGFloat(dt)
        if speed > maxSpeed && speed > 0 {
            let scale = maxSpeed / speed
            // Adjust previousPosition to clamp velocity
            previousPosition = CGPoint(
                x: position.x - newVel.dx * scale,
                y: position.y - newVel.dy * scale
            )
        }

        acceleration = .zero
    }

    /// Apply a force (accumulated into acceleration).
    func applyForce(_ force: CGVector) {
        acceleration.dx += force.dx
        acceleration.dy += force.dy
    }
}
