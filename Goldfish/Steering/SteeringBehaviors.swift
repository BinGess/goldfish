import CoreGraphics
import Foundation

/// Wander state persisted across frames.
struct WanderState {
    var wanderAngle: CGFloat = CGFloat.random(in: 0...(2 * .pi))
    var targetTimer: TimeInterval = 0
    var currentTarget: CGPoint? = nil
}

/// Static steering behavior calculators.
/// Each returns a force vector to be combined by BehaviorCombiner.
enum SteeringBehaviors {

    // MARK: - Seek

    /// Steer toward a target at max speed.
    static func seek(agent: SteeringAgent, target: CGPoint) -> CGVector {
        let dx = target.x - agent.position.x
        let dy = target.y - agent.position.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0.01 else { return .zero }

        let desiredVx = (dx / dist) * agent.maxSpeed
        let desiredVy = (dy / dist) * agent.maxSpeed
        return CGVector(dx: desiredVx - agent.velocity.dx,
                        dy: desiredVy - agent.velocity.dy)
    }

    // MARK: - Flee

    /// Steer away from a threat at max speed.
    static func flee(agent: SteeringAgent, threat: CGPoint) -> CGVector {
        let dx = agent.position.x - threat.x
        let dy = agent.position.y - threat.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0.01 else { return .zero }

        let desiredVx = (dx / dist) * agent.maxSpeed
        let desiredVy = (dy / dist) * agent.maxSpeed
        return CGVector(dx: desiredVx - agent.velocity.dx,
                        dy: desiredVy - agent.velocity.dy)
    }

    // MARK: - Arrive

    /// Steer toward target, decelerating within slowingRadius.
    static func arrive(agent: SteeringAgent, target: CGPoint, slowingRadius: CGFloat) -> CGVector {
        let dx = target.x - agent.position.x
        let dy = target.y - agent.position.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0.01 else { return .zero }

        let speed: CGFloat
        if dist < slowingRadius {
            speed = agent.maxSpeed * (dist / slowingRadius)
        } else {
            speed = agent.maxSpeed
        }
        let desiredVx = (dx / dist) * speed
        let desiredVy = (dy / dist) * speed
        return CGVector(dx: desiredVx - agent.velocity.dx,
                        dy: desiredVy - agent.velocity.dy)
    }

    // MARK: - Wander

    /// Smooth random wander using a sphere-constrained random walk.
    static func wander(agent: SteeringAgent, state: inout WanderState) -> CGVector {
        let wanderDistance = FishConfig.wanderDistance
        let wanderRadius = FishConfig.wanderRadius
        let wanderJitter = FishConfig.wanderJitter

        // Project a circle ahead of the agent
        let heading = agent.headingVector
        let circleCenter = CGVector(dx: heading.dx * wanderDistance,
                                     dy: heading.dy * wanderDistance)

        // Random jitter to the wander angle
        state.wanderAngle += CGFloat.random(in: -wanderJitter...wanderJitter)

        let displacement = CGVector(dx: cos(state.wanderAngle) * wanderRadius,
                                     dy: sin(state.wanderAngle) * wanderRadius)

        let targetX = agent.position.x + circleCenter.dx + displacement.dx
        let targetY = agent.position.y + circleCenter.dy + displacement.dy

        let target = CGPoint(x: targetX, y: targetY)
        return seek(agent: agent, target: target)
    }

    // MARK: - Wall Avoidance

    /// Soft repulsion from screen edges.
    static func wallAvoidance(agent: SteeringAgent, bounds: CGRect, margin: CGFloat) -> CGVector {
        var force = CGVector.zero
        let maxF = agent.maxForce * FishConfig.wallForceMultiplier

        let left = agent.position.x - bounds.minX
        let right = bounds.maxX - agent.position.x
        let bottom = agent.position.y - bounds.minY
        let top = bounds.maxY - agent.position.y

        if left < margin && left > 0 {
            force.dx += (1.0 - left / margin) * maxF
        }
        if right < margin && right > 0 {
            force.dx -= (1.0 - right / margin) * maxF
        }
        if bottom < margin && bottom > 0 {
            force.dy += (1.0 - bottom / margin) * maxF
        }
        if top < margin && top > 0 {
            force.dy -= (1.0 - top / margin) * maxF
        }

        return force
    }

    // MARK: - Orbit

    /// Circle around a point at given radius.
    static func orbit(agent: SteeringAgent, center: CGPoint, radius: CGFloat, clockwise: Bool) -> CGVector {
        let dx = agent.position.x - center.x
        let dy = agent.position.y - center.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0.01 else { return seek(agent: agent, target: CGPoint(x: center.x + radius, y: center.y)) }

        // Tangent direction
        let direction: CGFloat = clockwise ? -1 : 1
        let tangentX = -dy * direction / dist
        let tangentY = dx * direction / dist

        // Radial correction to maintain orbit radius
        let radialError = dist - radius
        let correctionStrength: CGFloat = 2.0
        let radialX = -(dx / dist) * radialError * correctionStrength
        let radialY = -(dy / dist) * radialError * correctionStrength

        let orbitSpeed = agent.maxSpeed * 0.4
        let desiredVx = tangentX * orbitSpeed + radialX
        let desiredVy = tangentY * orbitSpeed + radialY

        return CGVector(dx: desiredVx - agent.velocity.dx,
                        dy: desiredVy - agent.velocity.dy)
    }
}
