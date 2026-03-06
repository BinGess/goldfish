import Foundation

/// Global time management for fixed-timestep physics simulation.
enum Time {
    /// Delta time for the current frame (seconds).
    private(set) static var deltaTime: TimeInterval = 0
    /// Total elapsed time since scene start.
    private(set) static var elapsed: TimeInterval = 0

    private static var lastUpdate: TimeInterval = 0
    private static var initialized = false

    /// Call once per frame from SKScene.update(_:).
    /// Returns clamped delta time (max 1/30s to prevent spiral of death).
    @discardableResult
    static func update(_ currentTime: TimeInterval) -> TimeInterval {
        if !initialized {
            lastUpdate = currentTime
            initialized = true
            deltaTime = 0
            return 0
        }
        let raw = currentTime - lastUpdate
        deltaTime = min(raw, 1.0 / 30.0) // Clamp to prevent spiral of death
        elapsed += deltaTime
        lastUpdate = currentTime
        return deltaTime
    }

    static func reset() {
        deltaTime = 0
        elapsed = 0
        lastUpdate = 0
        initialized = false
    }
}
