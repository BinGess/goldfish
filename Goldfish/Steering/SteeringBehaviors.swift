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
        let heading: CGVector
        let hv = agent.headingVector
        if abs(hv.dx) < 0.001 && abs(hv.dy) < 0.001 {
            // Low-speed fallback avoids "stuck" heading singularity.
            heading = CGVector(dx: cos(state.wanderAngle), dy: sin(state.wanderAngle))
        } else {
            heading = hv
        }
        let circleCenter = CGVector(dx: heading.dx * wanderDistance,
                                     dy: heading.dy * wanderDistance)

        // Random jitter with heading memory to keep motion organic, not twitchy.
        state.wanderAngle += CGFloat.random(in: -wanderJitter...wanderJitter) * 0.65
        let headingAngle = atan2(heading.dy, heading.dx)
        var angleDiff = state.wanderAngle - headingAngle
        while angleDiff > .pi { angleDiff -= 2 * .pi }
        while angleDiff < -.pi { angleDiff += 2 * .pi }
        state.wanderAngle = headingAngle + angleDiff * 0.92

        let displacement = CGVector(dx: cos(state.wanderAngle) * wanderRadius,
                                     dy: sin(state.wanderAngle) * wanderRadius)

        let targetX = agent.position.x + circleCenter.dx + displacement.dx
        let targetY = agent.position.y + circleCenter.dy + displacement.dy

        let target = CGPoint(x: targetX, y: targetY)
        return seek(agent: agent, target: target)
    }

    // MARK: - Wall Avoidance

    /// Heading-aware wall avoidance: cubic ease-in repulsion scaled by approach angle.
    /// Fish heading toward a wall gets a stronger push; fish moving parallel or away gets a lighter push.
    /// This creates a smooth arc turn without destabilizing the agent when speed is near zero.
    static func wallAvoidance(agent: SteeringAgent, bounds: CGRect, margin: CGFloat) -> CGVector {
        var force = CGVector.zero
        let maxF = agent.maxForce * FishConfig.wallForceMultiplier
        let speed = agent.speed
        let vel = agent.velocity

        let left = agent.position.x - bounds.minX
        let right = bounds.maxX - agent.position.x
        let bottom = agent.position.y - bounds.minY
        let top = bounds.maxY - agent.position.y

        // Returns scaled repulsion force for a single wall.
        // velToward > 0 means the fish is moving toward that wall.
        func repulsion(dist: CGFloat, velToward: CGFloat) -> CGFloat {
            guard dist < margin && dist > 0 else { return 0 }
            let t = 1.0 - dist / margin
            let approachScale: CGFloat
            if speed > 1 && velToward > 0 {
                approachScale = 1.0 + min(velToward / speed, 1.0) * 1.5
            } else {
                approachScale = 0.5
            }
            return t * t * t * maxF * approachScale
        }

        force.dx += repulsion(dist: left,   velToward: -vel.dx)
        force.dx -= repulsion(dist: right,  velToward:  vel.dx)
        force.dy += repulsion(dist: bottom, velToward: -vel.dy)
        force.dy -= repulsion(dist: top,    velToward:  vel.dy)

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
