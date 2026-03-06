import CoreGraphics

/// Maintains a fixed distance between two Verlet particles.
/// Uses Jakobsen's projection method: each iteration pushes/pulls particles
/// toward the rest length.
struct DistanceConstraint {
    let indexA: Int
    let indexB: Int
    let restLength: CGFloat

    /// Solve the constraint for one iteration.
    /// Both particles are moved equally unless one is pinned.
    func solve(particles: inout [VerletParticle]) {
        let a = particles[indexA]
        let b = particles[indexB]

        let dx = b.position.x - a.position.x
        let dy = b.position.y - a.position.y
        let currentLength = sqrt(dx * dx + dy * dy)

        guard currentLength > 0.001 else { return }

        let diff = (currentLength - restLength) / currentLength
        let correctionX = dx * 0.5 * diff
        let correctionY = dy * 0.5 * diff

        if !a.pinned {
            a.position.x += correctionX
            a.position.y += correctionY
        }
        if !b.pinned {
            b.position.x -= correctionX
            b.position.y -= correctionY
        }
    }
}
