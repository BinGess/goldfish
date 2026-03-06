import Foundation

/// Tracks rolling FPS average and decides on quality degradation level.
final class PerformanceMonitor {

    /// Quality levels: 0 = full, 1 = reduced, 2 = minimal.
    private(set) var degradationLevel: Int = 0

    private var frameTimes: [TimeInterval] = []
    private let sampleCount = 120 // ~2 seconds at 60fps

    /// Current rolling average FPS.
    var averageFPS: Float {
        guard !frameTimes.isEmpty else { return 60 }
        let avgDt = frameTimes.reduce(0, +) / Double(frameTimes.count)
        return avgDt > 0 ? Float(1.0 / avgDt) : 60
    }

    /// Call once per frame with the frame's delta time.
    func recordFrame(deltaTime: TimeInterval) {
        frameTimes.append(deltaTime)
        if frameTimes.count > sampleCount {
            frameTimes.removeFirst()
        }
        evaluate()
    }

    private func evaluate() {
        let fps = averageFPS
        if fps < FishConfig.degradationThresholdFPS && degradationLevel < 2 {
            degradationLevel += 1
        } else if fps > FishConfig.restorationThresholdFPS && degradationLevel > 0 {
            degradationLevel -= 1
        }
    }
}
