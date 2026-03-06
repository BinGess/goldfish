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
    /// Runtime panel-controlled amplitude scale.
    var externalAmplitudeScale: CGFloat = MotionTuningValues.default.tailAmplitudeScale

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
        let panelAmplitude = max(0.35, min(2.0, externalAmplitudeScale))
        let effectiveAmp = max(amplitude, baseAmp * 0.15) * panelAmplitude

        // Advance phase
        oscillationPhase += effectiveFreq * 2 * .pi * dtf

        // Keep phase in [0, 2π] to prevent floating point drift
        if oscillationPhase > 2 * .pi * 100 {
            oscillationPhase -= 2 * .pi * 100
        }

        let particleCount = spine.particles.count
        let amplitudeGradient = FishConfig.amplitudeGradient
        let forceScale = FishConfig.oscillationForceScale

        // Apply wave forces to body and tail particles (skip head at index 0)
        for i in 1..<particleCount {
            let t = CGFloat(i) / CGFloat(particleCount - 1) // 0 at head, 1 at tail

            // Amplitude ramps up non-linearly toward tail for less "robotic" uniform sway.
            let easedTail = t * t * (3 - 2 * t) // smoothstep
            var localAmplitude = effectiveAmp * (amplitudeGradient + (1 - amplitudeGradient) * easedTail)
            if i == 1 {
                // Keep neck area stiffer than tail.
                localAmplitude *= 0.6
            }

            // Traveling wave from head toward tail with slightly longer wavelength.
            let wave = sin(oscillationPhase - t * 1.65 * .pi) * localAmplitude

            // Use local spine tangent for force direction to avoid whole-body rigid swinging.
            let lateral = localLateralDirection(spine: spine, index: i)
            let forceX = lateral.dx * wave * forceScale * dtf
            let forceY = lateral.dy * wave * forceScale * dtf

            spine.particles[i].applyForce(CGVector(dx: forceX, dy: forceY))
        }
    }

    /// Local lateral direction (unit vector) derived from neighborhood tangent.
    private func localLateralDirection(spine: SpineChain, index: Int) -> CGVector {
        let particles = spine.particles
        let count = particles.count
        guard count >= 2 else { return CGVector(dx: 0, dy: 1) }

        let prevIndex = max(0, index - 1)
        let nextIndex = min(count - 1, index + 1)
        let prevPos = particles[prevIndex].position
        let nextPos = particles[nextIndex].position

        var tx = prevPos.x - nextPos.x
        var ty = prevPos.y - nextPos.y
        let tLen = sqrt(tx * tx + ty * ty)
        if tLen > 0.001 {
            tx /= tLen
            ty /= tLen
            return CGVector(dx: -ty, dy: tx)
        }

        // Fallback to head orientation if local tangent degenerates.
        let headAngle = spine.headAngle
        return CGVector(dx: -sin(headAngle), dy: cos(headAngle))
    }
}
