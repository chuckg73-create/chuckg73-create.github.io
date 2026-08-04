import SwiftUI

// MARK: - Primary button

struct KindredButton: View {
    var title: String
    var systemImage: String?
    var style: Style = .primary
    var isLoading: Bool = false
    var action: () -> Void

    enum Style { case primary, warm, subtle }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(style == .subtle ? KindredTheme.hairline : .clear, lineWidth: 1)
            )
        }
        .disabled(isLoading)
        .shadow(color: shadow, radius: 18, y: 8)
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .primary: KindredTheme.brandGradient
        case .warm: KindredTheme.warmGradient
        case .subtle: KindredTheme.card
        }
    }

    private var foreground: Color { style == .subtle ? KindredTheme.text : .white }
    private var shadow: Color {
        switch style {
        case .primary: return KindredTheme.accent.opacity(0.35)
        case .warm: return KindredTheme.coral.opacity(0.30)
        case .subtle: return .clear
        }
    }
}

// MARK: - Chip

struct Chip: View {
    var text: String
    var systemImage: String?
    var tint: Color = KindredTheme.accent
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage).font(.caption2) }
            Text(text).font(.caption).fontWeight(.medium)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .foregroundStyle(filled ? .white : tint)
        .background(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14)), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(filled ? 0 : 0.3), lineWidth: 1))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    var label: String
    var body: some View {
        Text(label.uppercased())
            .font(.caption).fontWeight(.bold)
            .kerning(2)
            .foregroundStyle(KindredTheme.accent)
    }
}

// MARK: - Match score badge

struct MatchBadge: View {
    var score: Int

    private var color: Color {
        switch score {
        case 85...: return KindredTheme.mint
        case 65..<85: return KindredTheme.amber
        default: return KindredTheme.faint
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("\(score)").font(.headline).fontWeight(.bold).monospacedDigit()
            Text("match").font(.system(size: 8)).textCase(.uppercase).kerning(1)
        }
        .foregroundStyle(color)
        .frame(width: 52, height: 52)
        .background(color.opacity(0.12), in: Circle())
        .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 1.5))
    }
}

// MARK: - Empty state

struct EmptyState: View {
    var systemImage: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 46))
                .foregroundStyle(KindredTheme.accent.opacity(0.85))
            Text(title).font(.title3).fontWeight(.bold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                KindredButton(title: actionTitle, action: action)
                    .padding(.top, 4)
                    .frame(maxWidth: 260)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}
