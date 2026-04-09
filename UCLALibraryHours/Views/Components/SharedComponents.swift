import SwiftUI

// MARK: - Colors

extension Color {
    static let uclaBlue = Color(red: 0.043, green: 0.416, blue: 0.718)
    static let uclaGold = Color(red: 1.0, green: 0.843, blue: 0.0)
}


// MARK: - Status Badge

enum BadgeSize { case small, medium, large }

struct StatusBadge: View {
    let status: OpenStatus
    var size: BadgeSize = .medium

    var body: some View {
        Text(status.displayText)
            .font(font)
            .bold()
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(badgeColor, in: Capsule())
    }

    private var badgeColor: Color {
        switch status {
        case .open: return .green
        case .open24: return .uclaBlue
        case .closed: return Color(.systemGray3)
        case .byAppointment: return .orange
        case .unknown: return Color(.systemGray4)
        }
    }

    private var font: Font {
        switch size {
        case .small: return .caption2.bold()
        case .medium: return .caption.bold()
        case .large: return .subheadline.bold()
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 6
        case .medium: return 8
        case .large: return 12
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small: return 3
        case .medium: return 4
        case .large: return 6
        }
    }
}

// MARK: - Stars View

struct StarsView: View {
    let rating: Int
    var size: Font = .subheadline

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(size)
                    .foregroundStyle(i <= rating ? Color.yellow : Color(.systemGray4))
            }
        }
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: SpaceTag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label(tag.displayName, systemImage: tag.systemImage)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.uclaBlue : Color(.systemGray6),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Unlock Animation View

struct UnlockAnimationView: View {
    let onComplete: () -> Void
    @State private var opacity = 0.0
    @State private var scale = 0.3
    @State private var checkScale = 0.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.uclaBlue)
                        .frame(width: 88, height: 88)

                    Image(systemName: "location.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                        .scaleEffect(checkScale)
                }
                .scaleEffect(scale)

                Text("Study Spaces Unlocked")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Find your perfect spot")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .opacity(opacity)
        }
        .onAppear { animate() }
        .onTapGesture { onComplete() }
    }

    private func animate() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            opacity = 1
            scale = 1
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.2)) {
            checkScale = 1
        }
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0
            }
            try? await Task.sleep(for: .seconds(0.3))
            onComplete()
        }
    }
}
