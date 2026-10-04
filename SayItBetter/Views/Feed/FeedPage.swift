import SwiftUI

/// Label, icon and tint for each kind of post.
extension FeedPost.Kind {
    var title: String {
        switch self {
        case .wordCard: "Word"
        case .swap: "Say it better"
        case .quiz: "Quick quiz"
        case .meeting: "Meeting moment"
        case .mistake: "Common mistake"
        case .review: "Review"
        case .dailyDone: "Daily set"
        }
    }

    var symbol: String {
        switch self {
        case .wordCard: "textformat.abc"
        case .swap: "arrow.triangle.swap"
        case .quiz: "questionmark.bubble"
        case .meeting: "person.2"
        case .mistake: "exclamationmark.triangle"
        case .review: "arrow.counterclockwise"
        case .dailyDone: "checkmark.seal"
        }
    }

    var tint: Color {
        switch self {
        case .wordCard: .accentColor
        case .swap: .orange
        case .quiz: .purple
        case .meeting: .teal
        case .mistake: .pink
        case .review: .indigo
        case .dailyDone: .green
        }
    }
}

/// The full-screen frame around every post: a soft tinted backdrop, one big card, a kind label
/// on top, and (on the first post only) a "swipe up" hint underneath.
struct FeedPage<Content: View>: View {
    let kind: FeedPost.Kind
    var label: String?
    var showsSwipeHint = false
    @ViewBuilder let content: Content

    @Environment(\.feedBottomInset) private var bottomInset
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        VStack(spacing: 12) {
            // The card takes exactly the height the page gives it, so content that is too tall
            // scrolls inside the card instead of pushing its actions off screen.
            GeometryReader { proxy in
                card
                    .frame(height: proxy.size.height)
            }
            if showsSwipeHint {
                SwipeUpHint()
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16 + bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AnimatedBackdrop(tint: kind.tint) }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(label ?? kind.title, systemImage: kind.symbol)
                .font(Theme.mono.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(kind.tint)
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(kind.tint.opacity(glow ? 0.6 : 0.2), lineWidth: glow ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

/// Gradient plus three colour blobs that slowly drift and breathe behind each page.
/// Motion stops when Reduce Motion is on, leaving the static gradient.
private struct AnimatedBackdrop: View {
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.26), tint.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            blob(color: tint.opacity(0.35), size: 280, x: drift ? 150 : 90, y: drift ? -230 : -190, blur: 60)
            blob(color: tint.opacity(0.25), size: 210, x: drift ? -160 : -120, y: drift ? 250 : 210, blur: 50)
            blob(color: .white.opacity(0.12), size: 140, x: drift ? -40 : 30, y: drift ? 20 : -30, blur: 40)
        }
        .clipped()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func blob(color: Color, size: CGFloat, x: CGFloat, y: CGFloat, blur: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: blur)
            .offset(x: x, y: y)
    }
}

/// Turns content over like a card: it starts edge-on and swings flat, used when a word is revealed.
struct FlipIn: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
            .opacity(angle == 0 ? 1 : 0)
    }
}

extension AnyTransition {
    static var flip: AnyTransition {
        .modifier(active: FlipIn(angle: -90), identity: FlipIn(angle: 0))
    }
}

/// A burst of coloured pieces that fly out from the centre and fade. Plays once on appear.
struct ConfettiBurst: View {
    private struct Piece: Identifiable {
        let id: Int
        let color: Color
        let angle: Double
        let distance: CGFloat
        let spin: Double
        let isCircle: Bool
    }

    private static let colors: [Color] = [.green, .orange, .pink, .purple, .teal, .yellow, .indigo]

    private let pieces: [Piece] = (0..<36).map { index in
        Piece(
            id: index,
            color: colors[index % colors.count],
            angle: Double.random(in: 0..<(2 * .pi)),
            distance: CGFloat.random(in: 120...260),
            spin: Double.random(in: 180...540),
            isCircle: index.isMultiple(of: 3)
        )
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var launched = false

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                // A 9pt square with a 4.5pt corner radius is a dot; a smaller radius is a chip.
                RoundedRectangle(cornerRadius: piece.isCircle ? 4.5 : 2)
                .fill(piece.color)
                .frame(width: 9, height: 9)
                .rotationEffect(.degrees(launched ? piece.spin : 0))
                .offset(
                    x: launched ? cos(piece.angle) * piece.distance : 0,
                    y: launched ? sin(piece.angle) * piece.distance : 0
                )
                .opacity(launched ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6)) {
                launched = true
            }
        }
    }
}

extension EnvironmentValues {
    /// How far the floating tab bar overlaps the bottom of a feed page.
    @Entry var feedBottomInset: CGFloat = 0
}

/// Big serif headword that still scales with Dynamic Type.
struct FeedHeadword: View {
    let text: String
    var color: Color = .primary
    var baseSize: CGFloat = 46

    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 46

    var body: some View {
        Text(text)
            .font(.system(size: baseSize == 46 ? size : baseSize, weight: .semibold, design: .serif))
            .foregroundStyle(color)
            .minimumScaleFactor(0.6)
            .lineLimit(2)
    }
}

/// A gently bouncing chevron that tells first-time users how the feed works.
private struct SwipeUpHint: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "chevron.up")
                .font(.headline)
                .offset(y: lifted ? -5 : 0)
            Text("Swipe up for the next one")
                .font(Theme.monoSmall)
        }
        .foregroundStyle(.secondary)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .combine)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                lifted = true
            }
        }
    }
}
