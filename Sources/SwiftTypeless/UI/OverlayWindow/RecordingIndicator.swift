import SwiftUI

struct RecordingIndicator: View {
    let level: Float

    private static let barCount = 9
    private static let barWidth: CGFloat = 3
    private static let barGap: CGFloat = 3
    private static let minHeight: CGFloat = 3
    private static let maxDelta: CGFloat = 14   // height range: 3..17

    // Quadratic bell weights: 1 - (dist/center)^2
    // center bar = 1.0, edge bars ≈ 0
    private static let weights: [CGFloat] = {
        let center = CGFloat(barCount - 1) / 2.0
        return (0..<barCount).map { i in
            let dist = abs(CGFloat(i) - center) / center
            return 1.0 - dist * dist
        }
    }()

    @State private var bars: [CGFloat] = Array(repeating: 0, count: barCount)
    @State private var barTargets: [CGFloat] = Array(repeating: 0, count: barCount)
    @State private var barCurrents: [CGFloat] = Array(repeating: 0, count: barCount)
    @State private var currentLevel: CGFloat = 0
    @State private var displayLink: Timer?

    // Per-bar unique smoothing speeds (randomized once)
    @State private var riseSpeeds: [CGFloat] = (0..<barCount).map { _ in 0.45 + CGFloat.random(in: 0...0.3) }
    @State private var fallSpeeds: [CGFloat] = (0..<barCount).map { _ in 0.1 + CGFloat.random(in: 0...0.1) }

    var body: some View {
        HStack(spacing: Self.barGap) {
            ForEach(0..<Self.barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.barColor)
                    .frame(width: Self.barWidth, height: Self.minHeight + bars[i] * Self.maxDelta)
            }
        }
        .frame(height: 20)
        .onAppear { startAnimation() }
        .onDisappear { stopAnimation() }
        .onChange(of: level) { _, newLevel in
            updateTargets(CGFloat(newLevel))
        }
    }

    // MARK: - Animation (matches original requestAnimationFrame at ~60fps)

    private func startAnimation() {
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            animate()
        }
    }

    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Called when a new audio level arrives — compute per-bar targets
    private func updateTargets(_ targetLevel: CGFloat) {
        // Global smoothing: fast rise (0.6), slow fall (0.2)
        if targetLevel > currentLevel {
            currentLevel += (targetLevel - currentLevel) * 0.6
        } else {
            currentLevel += (targetLevel - currentLevel) * 0.2
        }

        for i in 0..<Self.barCount {
            let base = currentLevel * Self.weights[i]
            // Jitter: level * (random 0..0.5 - 0.1) * weight → range [-0.1..0.4] scaled
            let jitter = currentLevel * (CGFloat.random(in: 0...0.5) - 0.1) * Self.weights[i]
            barTargets[i] = max(0, min(1, base + jitter))
        }
    }

    /// Per-bar independent smoothing each frame
    private func animate() {
        for i in 0..<Self.barCount {
            if barTargets[i] > barCurrents[i] {
                barCurrents[i] += (barTargets[i] - barCurrents[i]) * riseSpeeds[i]
            } else {
                barCurrents[i] += (barTargets[i] - barCurrents[i]) * fallSpeeds[i]
            }
            bars[i] = barCurrents[i]
        }
    }
}
