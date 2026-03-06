import CoreGraphics
import Foundation

/// An 8-particle Verlet chain representing the fish's spine.
/// Particle[0] = head (pinned, driven by steering).
/// Particles[1..7] = body segments following via distance constraints.
final class SpineChain {

    private(set) var particles: [VerletParticle]
    private var constraints: [DistanceConstraint]

    /// Aquarium bounds for boundary containment.
    var bounds: CGRect = .zero

    init(headPosition: CGPoint) {
        let count = FishConfig.spineParticleCount
        let segLen = FishConfig.spineSegmentLength

        // Initialize particles in a straight line extending leftward from head
        var parts: [VerletParticle] = []
        for i in 0..<count {
            let x = headPosition.x - CGFloat(i) * segLen
            let y = headPosition.y
            let p = VerletParticle(position: CGPoint(x: x, y: y), pinned: i == 0)
            parts.append(p)
        }
        self.particles = parts

        // Create distance constraints between consecutive particles
        var cons: [DistanceConstraint] = []
        for i in 0..<(count - 1) {
            cons.append(DistanceConstraint(indexA: i, indexB: i + 1, restLength: segLen))
        }
        self.constraints = cons
    }

    /// The head particle (index 0), externally driven.
    var head: VerletParticle { particles[0] }

    /// The tail particle (last index).
    var tail: VerletParticle { particles[particles.count - 1] }

    /// Set head position directly (called by steering agent).
    func setHeadPosition(_ pos: CGPoint) {
        particles[0].position = pos
    }

    /// Positions of all particles, for rendering.
    var positions: [CGPoint] {
        particles.map { $0.position }
    }

    /// Heading angle of the head (radians), derived from head → next segment direction.
    var headAngle: CGFloat {
        let dx = particles[0].position.x - particles[1].position.x
        let dy = particles[0].position.y - particles[1].position.y
        return atan2(dy, dx)
    }

    /// Angle at each particle, derived from direction to next particle.
    var angles: [CGFloat] {
        var result: [CGFloat] = []
        for i in 0..<particles.count {
            if i < particles.count - 1 {
                let dx = particles[i].position.x - particles[i + 1].position.x
                let dy = particles[i].position.y - particles[i + 1].position.y
                result.append(atan2(dy, dx))
            } else {
                // Last particle: same angle as previous
                result.append(result.last ?? 0)
            }
        }
        return result
    }

    /// Run one physics tick.
    func simulate(dt: TimeInterval) {
        let damping = FishConfig.spineDamping
        let dragCoeff = FishConfig.waterDragCoefficient

        // 1. Apply water drag to non-pinned particles
        for particle in particles where !particle.pinned {
            let vel = particle.velocity
            particle.applyForce(CGVector(dx: -vel.dx * dragCoeff,
                                         dy: -vel.dy * dragCoeff))
        }

        // 2. Verlet integration
        for particle in particles {
            particle.integrate(dt: dt, damping: damping)
        }

        // 3. Constraint solving (multiple iterations for stability)
        let iterations = FishConfig.spineConstraintIterations
        for _ in 0..<iterations {
            for constraint in constraints {
                constraint.solve(particles: &particles)
            }

            // 3b. Angular constraint: limit bend angle between consecutive segments
            solveAngleConstraints()
        }

        // 4. Boundary containment — shift both position and previousPosition
        // by the same delta so Verlet velocity stays consistent (no artificial impulse).
        let margin: CGFloat = 25
        if bounds != .zero {
            for particle in particles where !particle.pinned {
                let oldX = particle.position.x
                let oldY = particle.position.y
                particle.position.x = max(bounds.minX + margin,
                                          min(bounds.maxX - margin, particle.position.x))
                particle.position.y = max(bounds.minY + margin,
                                          min(bounds.maxY - margin, particle.position.y))
                let dx = particle.position.x - oldX
                let dy = particle.position.y - oldY
                if dx != 0 || dy != 0 {
                    particle.previousPosition.x += dx
                    particle.previousPosition.y += dy
                }
            }
        }
    }

    /// Enforce maximum bend angle between consecutive spine segments.
    /// If the angle between segment[i-1→i] and segment[i→i+1] exceeds the limit,
    /// project particle[i+1] back to respect the max bend angle.
    private func solveAngleConstraints() {
        let maxAngle = FishConfig.maxSpineBendAngle

        for i in 1..<(particles.count - 1) {
            // Skip if the particle being moved is pinned
            guard !particles[i + 1].pinned else { continue }

            let prev = particles[i - 1].position
            let curr = particles[i].position
            let next = particles[i + 1].position

            // Direction of segment from prev→curr
            let d1x = curr.x - prev.x
            let d1y = curr.y - prev.y
            let len1 = sqrt(d1x * d1x + d1y * d1y)
            guard len1 > 0.001 else { continue }

            // Direction of segment from curr→next
            let d2x = next.x - curr.x
            let d2y = next.y - curr.y
            let len2 = sqrt(d2x * d2x + d2y * d2y)
            guard len2 > 0.001 else { continue }

            // Compute angle between the two segments using cross product and dot product
            let dot = (d1x * d2x + d1y * d2y) / (len1 * len2)
            let cross = (d1x * d2y - d1y * d2x) / (len1 * len2)
            let angle = atan2(cross, dot)

            // If the bend angle exceeds the limit, project 'next' back
            if abs(angle) > maxAngle {
                let clampedAngle = angle > 0 ? maxAngle : -maxAngle

                // Rotate the prev→curr direction by the clamped angle to get the allowed direction
                let baseAngle = atan2(d1y, d1x)
                let allowedAngle = baseAngle + clampedAngle

                // Place 'next' at the allowed position (maintaining current segment length).
                // Shift previousPosition by the same delta to avoid injecting velocity spikes.
                let oldNext = particles[i + 1].position
                let newNext = CGPoint(
                    x: curr.x + cos(allowedAngle) * len2,
                    y: curr.y + sin(allowedAngle) * len2
                )
                particles[i + 1].position = newNext
                let deltaX = newNext.x - oldNext.x
                let deltaY = newNext.y - oldNext.y
                particles[i + 1].previousPosition.x += deltaX
                particles[i + 1].previousPosition.y += deltaY
            }
        }
    }
}
