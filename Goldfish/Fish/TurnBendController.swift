import CoreGraphics
import Foundation

enum TurnStability {
    static func clampToBounds(
        position: CGPoint,
        velocity: CGVector,
        bounds: CGRect,
        margin: CGFloat
    ) -> (position: CGPoint, velocity: CGVector) {
        guard bounds != .zero else { return (position, velocity) }

        var clampedPosition = position
        var clampedVelocity = velocity

        if clampedPosition.x < bounds.minX + margin {
            clampedPosition.x = bounds.minX + margin
            if clampedVelocity.dx < 0 { clampedVelocity.dx = 0 }
        }
        if clampedPosition.x > bounds.maxX - margin {
            clampedPosition.x = bounds.maxX - margin
            if clampedVelocity.dx > 0 { clampedVelocity.dx = 0 }
        }
        if clampedPosition.y < bounds.minY + margin {
            clampedPosition.y = bounds.minY + margin
            if clampedVelocity.dy < 0 { clampedVelocity.dy = 0 }
        }
        if clampedPosition.y > bounds.maxY - margin {
            clampedPosition.y = bounds.maxY - margin
            if clampedVelocity.dy > 0 { clampedVelocity.dy = 0 }
        }

        return (clampedPosition, clampedVelocity)
    }
}

struct TurnBendController {
    private(set) var turnSignal: CGFloat = 0

    mutating func update(angularVelocity: CGFloat, dt: TimeInterval) -> CGFloat {
        let dtf = max(CGFloat(dt), 0)
        guard dtf > 0 else { return turnSignal }

        let target = normalizedTarget(for: angularVelocity)
        if target == 0 {
            turnSignal = move(turnSignal, toward: 0, maxDelta: FishConfig.turnBendDecayRate * dtf)
        } else if turnSignal == 0 || turnSignal.sign == target.sign {
            let rate = abs(target) > abs(turnSignal)
                ? FishConfig.turnBendRiseRate
                : FishConfig.turnBendDecayRate
            turnSignal = move(turnSignal, toward: target, maxDelta: rate * dtf)
        } else {
            turnSignal = move(turnSignal, toward: 0, maxDelta: FishConfig.turnBendDecayRate * dtf)
        }

        if abs(turnSignal) < 0.0001 {
            turnSignal = 0
        }
        return turnSignal
    }

    func forceScale(at index: Int, particleCount: Int) -> CGFloat {
        guard particleCount >= 4 else { return 0 }
        guard index > 0 && index < particleCount - 1 else { return 0 }

        let t = CGFloat(index) / CGFloat(particleCount - 1)
        let bodyWindow = smoothstep(0.16, 0.34, t) * (1.0 - smoothstep(0.84, 0.98, t))
        let normalizedDistance = (t - 0.55) / 0.26
        let bellyPeak = max(0, 1.0 - normalizedDistance * normalizedDistance)
        let activation = abs(turnSignal)
        let lagExponent = 1.0 + max(0, t - 0.22) * 2.4
        let propagation = pow(activation, lagExponent)
        return signedUnit(turnSignal) * bodyWindow * bellyPeak * propagation
    }

    static func localLateralDirection(spine: SpineChain, index: Int) -> CGVector {
        let particles = spine.particles
        let count = particles.count
        guard count >= 2 else { return CGVector(dx: 0, dy: 1) }

        let prevIndex = max(0, index - 1)
        let nextIndex = min(count - 1, index + 1)
        let prevPos = particles[prevIndex].position
        let nextPos = particles[nextIndex].position

        var tx = prevPos.x - nextPos.x
        var ty = prevPos.y - nextPos.y
        let length = sqrt(tx * tx + ty * ty)
        if length > 0.001 {
            tx /= length
            ty /= length
            return CGVector(dx: -ty, dy: tx)
        }

        let headAngle = spine.headAngle
        return CGVector(dx: -sin(headAngle), dy: cos(headAngle))
    }

    private func normalizedTarget(for angularVelocity: CGFloat) -> CGFloat {
        let threshold = FishConfig.maxTurnRate * FishConfig.turnBendThresholdRatio
        let magnitude = abs(angularVelocity)
        guard magnitude > threshold else { return 0 }

        let normalized = min(
            max((magnitude - threshold) / max(FishConfig.maxTurnRate - threshold, 0.001), 0),
            1
        )
        let eased = normalized * normalized * (3 - 2 * normalized)
        return signedUnit(angularVelocity) * eased
    }

    private func move(_ value: CGFloat, toward target: CGFloat, maxDelta: CGFloat) -> CGFloat {
        let delta = target - value
        if abs(delta) <= maxDelta {
            return target
        }
        return value + signedUnit(delta) * maxDelta
    }

    private func signedUnit(_ value: CGFloat) -> CGFloat {
        value >= 0 ? 1 : -1
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        guard edge0 != edge1 else { return x < edge0 ? 0 : 1 }
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
