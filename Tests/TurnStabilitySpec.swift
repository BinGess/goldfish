import CoreGraphics
import Foundation
import SpriteKit

private enum SpecFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

@discardableResult
private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws -> Bool {
    if !condition() {
        throw SpecFailure.failed(message)
    }
    return true
}

private func approxGreater(_ lhs: CGFloat, _ rhs: CGFloat, epsilon: CGFloat = 0.0001) -> Bool {
    lhs > rhs + epsilon
}

private func testClampRemovesOnlyInwardVelocity() throws {
    let bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
    let margin: CGFloat = 20
    let startPosition = CGPoint(x: 8, y: 110)
    let startVelocity = CGVector(dx: -42, dy: 18)

    let result = TurnStability.clampToBounds(
        position: startPosition,
        velocity: startVelocity,
        bounds: bounds,
        margin: margin
    )

    try expect(result.position.x == margin, "Expected left-wall clamp to snap x to margin.")
    try expect(result.velocity.dx == 0, "Expected inward horizontal velocity to be removed at wall contact.")
    try expect(result.velocity.dy == startVelocity.dy, "Expected tangential velocity to be preserved at wall contact.")
}

private func testTurnBendPeaksAtMidBodyBeforeTailCatchesUp() throws {
    var controller = TurnBendController()
    let particleCount = 8

    _ = controller.update(angularVelocity: FishConfig.maxTurnRate, dt: 1.0 / 120.0)
    _ = controller.update(angularVelocity: FishConfig.maxTurnRate, dt: 1.0 / 120.0)

    let neck = abs(controller.forceScale(at: 2, particleCount: particleCount))
    let belly = abs(controller.forceScale(at: 4, particleCount: particleCount))
    let tailRoot = abs(controller.forceScale(at: 6, particleCount: particleCount))

    try expect(approxGreater(belly, neck), "Expected belly bend to exceed neck bend during turn entry.")
    try expect(approxGreater(belly, tailRoot), "Expected belly bend to peak before the tail fully catches up.")
}

private func testDirectionFlipReleasesBeforeReversing() throws {
    var controller = TurnBendController()
    let dt = 1.0 / 120.0

    for _ in 0..<10 {
        _ = controller.update(angularVelocity: FishConfig.maxTurnRate, dt: dt)
    }
    let leftSignal = controller.turnSignal

    let firstReverse = controller.update(angularVelocity: -FishConfig.maxTurnRate, dt: dt)

    try expect(leftSignal > 0.2, "Expected controller to build a visible left-turn signal before reversal.")
    try expect(firstReverse > -0.05, "Expected turn signal to release toward zero before snapping fully into opposite bend.")
}

private func testHighCurvatureNarrowsMeshMoreAggressively() throws {
    let moderate = MeshDeformer.curvatureReduction(angleDelta: FishConfig.maxSpineBendAngle * 0.35)
    let sharp = MeshDeformer.curvatureReduction(angleDelta: FishConfig.maxSpineBendAngle * 0.95)

    try expect(sharp < moderate, "Expected high curvature to narrow the mesh more aggressively than moderate curvature.")
    try expect(sharp <= 0.72, "Expected sharp-turn curvature guard to clamp width into a stronger protection range.")
}

@main
struct TurnStabilitySpecRunner {
    static func main() {
        do {
            try testClampRemovesOnlyInwardVelocity()
            try testTurnBendPeaksAtMidBodyBeforeTailCatchesUp()
            try testDirectionFlipReleasesBeforeReversing()
            try testHighCurvatureNarrowsMeshMoreAggressively()
            print("TurnStabilitySpec: PASS")
        } catch {
            fputs("TurnStabilitySpec: FAIL\n\(error)\n", stderr)
            exit(1)
        }
    }
}
