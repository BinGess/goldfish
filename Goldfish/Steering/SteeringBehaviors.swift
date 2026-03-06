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

    /// Heading-aware wall avoidance with tangential redirect.
    /// Produces a smooth arcing turn when approaching walls instead of abrupt reversal.
    /// - Repulsion: cubic ease-in push away from wall, scaled by how directly the fish heads toward it.
    /// - Tangential: redirects the fish to curve along the wall in its current lateral direction.
    static func wallAvoidance(agent: SteeringAgent, bounds: CGRect, margin: CGFloat) -> CGVector {
        var force = CGVector.zero
        let maxF = agent.maxForce * FishConfig.wallForceMultiplier
        let speed = agent.speed
        let vel = agent.velocity

        let left = agent.position.x - bounds.minX
        let right = bounds.maxX - agent.position.x
        let bottom = agent.position.y - bounds.minY
        let top = bounds.maxY - agent.position.y

        func wallEffect(dist: CGFloat, velToward: CGFloat) -> (repulsion: CGFloat, tangential: CGFloat) {
            guard dist < margin && dist > 0 else { return (0, 0) }

            let t = 1.0 - dist / margin

            let headingFactor: CGFloat
            if velToward > 0 && speed > 1 {
                let approachRatio = min(velToward / speed, 1.0)
                headingFactor = 1.0 + approachRatio * 2.0
            } else {
                headingFactor = 0.3
            }

            let repulsion = t * t * t * maxF * headingFactor

            var tangential: CGFloat = 0
            if velToward > 0 && speed > 1 {
                let approachRatio = min(velToward / speed, 1.0)
                tangential = t * t * maxF * 0.6 * approachRatio
            }

            return (repulsion, tangential)
        }

        if left < margin {
            let (rep, tang) = wallEffect(dist: left, velToward: -vel.dx)
            force.dx += rep
            let tangentDir: CGFloat = vel.dy >= 0 ? 1 : -1
            force.dy += tang * tangentDir
        }

        if right < margin {
            let (rep, tang) = wallEffect(dist: right, velToward: vel.dx)
            force.dx -= rep
            let tangentDir: CGFloat = vel.dy >= 0 ? 1 : -1
            force.dy += tang * tangentDir
        }

        if bottom < margin {
            let (rep, tang) = wallEffect(dist: bottom, velToward: -vel.dy)
            force.dy += rep
            let tangentDir: CGFloat = vel.dx >= 0 ? 1 : -1
            force.dx += tang * tangentDir
        }

        if top < margin {
            let (rep, tang) = wallEffect(dist: top, velToward: vel.dy)
            force.dy -= rep
            let tangentDir: CGFloat = vel.dx >= 0 ? 1 : -1
            force.dx += tang * tangentDir
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
