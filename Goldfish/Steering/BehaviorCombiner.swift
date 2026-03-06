import CoreGraphics

/// Combines weighted steering forces and clamps the result.
struct WeightedForce {
    let force: CGVector
    let weight: CGFloat
}

enum BehaviorCombiner {

    /// Weighted sum of forces, clamped to maxForce.
    static func combine(forces: [WeightedForce], maxForce: CGFloat) -> CGVector {
        var total = CGVector.zero
        for wf in forces {
            total.dx += wf.force.dx * wf.weight
            total.dy += wf.force.dy * wf.weight
        }

        // Clamp to maxForce
        let mag = sqrt(total.dx * total.dx + total.dy * total.dy)
        if mag > maxForce && mag > 0 {
            let scale = maxForce / mag
            total.dx *= scale
            total.dy *= scale
        }

        return total
    }
}
