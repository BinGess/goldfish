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
        }

        // 4. Boundary containment
        let margin: CGFloat = 10
        if bounds != .zero {
            for particle in particles where !particle.pinned {
                particle.position.x = max(bounds.minX + margin,
                                          min(bounds.maxX - margin, particle.position.x))
                particle.position.y = max(bounds.minY + margin,
                                          min(bounds.maxY - margin, particle.position.y))
            }
        }
    }
}
