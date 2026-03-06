import CoreGraphics
import Foundation

/// Drives sinusoidal body oscillation on the spine chain.
/// Applies lateral wave forces to spine particles, creating natural tail-beat motion.
final class FishMotionDriver {

    /// Current phase of the oscillation wave (radians).
    private var oscillationPhase: CGFloat = 0

    /// Frequency multiplier (modified by state).
    var frequencyMultiplier: CGFloat = 1.0
    /// Amplitude multiplier (modified by state).
    var amplitudeMultiplier: CGFloat = 1.0

    /// Apply oscillation forces to the spine chain.
    /// - Parameters:
    ///   - spine: The spine chain to drive.
    ///   - speed: Current swimming speed (used to scale frequency/amplitude).
    ///   - maxSpeed: Maximum possible speed (for normalization).
    ///   - dt: Physics tick delta time.
    func drive(spine: SpineChain, speed: CGFloat, maxSpeed: CGFloat, dt: TimeInterval) {
        let dtf = CGFloat(dt)

        // Speed ratio for dynamic frequency/amplitude
        let speedRatio = min(speed / max(maxSpeed, 1), 1.0)

        // Dynamic frequency: faster swimming = faster tail beats
        let baseFreq = FishConfig.baseFrequency
        let frequency = baseFreq * (0.5 + 0.5 * speedRatio) * frequencyMultiplier
        // Minimum frequency to prevent total stillness
        let effectiveFreq = max(frequency, 0.2)

        // Dynamic amplitude: faster = wider sweeps
        let baseAmp = FishConfig.baseAmplitude
        let amplitude = baseAmp * (0.3 + 0.7 * speedRatio) * amplitudeMultiplier
        // Minimum amplitude for idle breathing
        let effectiveAmp = max(amplitude, baseAmp * 0.15)

        // Advance phase
        oscillationPhase += effectiveFreq * 2 * .pi * dtf

        // Keep phase in [0, 2π] to prevent floating point drift
        if oscillationPhase > 2 * .pi * 100 {
            oscillationPhase -= 2 * .pi * 100
        }

        // Get heading perpendicular for lateral force direction
        let headAngle = spine.headAngle
        let perpX = -sin(headAngle)
        let perpY = cos(headAngle)

        let particleCount = spine.particles.count
        let amplitudeGradient = FishConfig.amplitudeGradient
        let forceScale = FishConfig.oscillationForceScale

        // Apply wave forces to body and tail particles (skip head at index 0)
        for i in 1..<particleCount {
            let t = CGFloat(i) / CGFloat(particleCount - 1) // 0 at head, 1 at tail

            // Amplitude increases toward tail
            let localAmplitude = effectiveAmp * (amplitudeGradient + (1 - amplitudeGradient) * t)

            // Traveling wave: phase decreases along body
            let wave = sin(oscillationPhase - t * 1.5 * .pi) * localAmplitude

            // Apply as lateral force
            let forceX = perpX * wave * forceScale * dtf
            let forceY = perpY * wave * forceScale * dtf

            spine.particles[i].applyForce(CGVector(dx: forceX, dy: forceY))
        }
    }
}
