import SwiftUI

/// The look on top of the camera while you scan your computer's QR code:
/// the edges outside the square are dimmed, four bright corners mark where to aim,
/// and a glowing line sweeps up and down. Holds still with Reduce Motion.
struct ScannerViewfinder: View {
    var tint: Color
    var size: CGFloat = 200
    var cornerRadius: CGFloat = 22
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false
    @State private var glow = false

    var body: some View {
        ZStack {
            // Dim everything but the square.
            Rectangle()
                .fill(Color.black.opacity(0.38))
                .mask {
                    ZStack {
                        Rectangle()
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .frame(width: size, height: size)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // The outer edge of the camera card.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(tint.opacity(0.8), lineWidth: 2)
            // Four corner brackets.
            ViewfinderCorners(length: 34, radius: 18)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
                .shadow(color: tint.opacity(glow ? 0.9 : 0.4), radius: glow ? 10 : 4)
                .scaleEffect(glow ? 1.02 : 1)
            // The sweeping line.
            if !reduceMotion {
                Capsule()
                    .fill(
                        LinearGradient(colors: [.clear, tint, Color.white, tint, .clear],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: size - 24, height: 2.5)
                    .shadow(color: tint, radius: 6)
                    .offset(y: sweep ? size / 2 - 16 : -(size / 2 - 16))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { sweep = true }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

/// Just the four corners of a rounded square, drawn as open brackets.
struct ViewfinderCorners: Shape {
    var length: CGFloat
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(radius, length)
        // Top left.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        // Top right.
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        // Bottom right.
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        // Bottom left.
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        return path
    }
}

/// Covers the camera while pairing: a spinning ring around a link icon.
struct PairingBusyOverlay: View {
    var tint: Color
    var cornerRadius: CGFloat = 22
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Color.black.opacity(0.35)
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(spin ? 360 : 0))
                    Image(systemName: "link")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)
                Text("Pairing...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            if reduceMotion { return }
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}
