import SwiftUI

// MARK: - AppTheme
// Single source of truth for all design tokens.
// Phase B (visual redesign) shifted the palette from a generic blue-purple into
// a green-led student-event identity:
//
//   primary       → deep emerald (CTAs, active state)
//   secondary     → teal-mint (supporting accent, organizer touches)
//   accent        → warm lime (highlights, badges)
//   surfaceTinted → very light green-gray for grouped section backgrounds

enum AppTheme {

    // MARK: Colors
    static let primary     = Color(red: 0.11, green: 0.60, blue: 0.45)  // #1C9973 emerald
    static let primaryDark = Color(red: 0.05, green: 0.42, blue: 0.33)  // #0B6B54
    static let secondary   = Color(red: 0.20, green: 0.72, blue: 0.62)  // #33B79E mint-teal
    static let accent      = Color(red: 0.83, green: 0.92, blue: 0.31)  // #D4EB50 lime highlight

    static let background    = Color(red: 0.97, green: 0.98, blue: 0.97) // very light green-gray
    static let backgroundAlt = Color(red: 0.93, green: 0.97, blue: 0.95) // grouped content tint
    static let surface       = Color(.systemBackground)
    static let surfaceTinted = Color(red: 0.93, green: 0.97, blue: 0.94) // mint-tinted surface
    static let divider       = Color(white: 0, opacity: 0.08)

    static let textPrimary   = Color(red: 0.08, green: 0.15, blue: 0.12) // deep neutral green-black
    static let textSecondary = Color(red: 0.33, green: 0.38, blue: 0.36)
    static let textTertiary  = Color(red: 0.55, green: 0.60, blue: 0.58)

    static let success = Color(red: 0.18, green: 0.72, blue: 0.44)   // forest success
    static let warning = Color(red: 0.96, green: 0.62, blue: 0.18)   // warm amber
    static let error   = Color(red: 0.94, green: 0.36, blue: 0.36)   // coral

    // MARK: Gradients
    static let primaryGradient = LinearGradient(
        colors: [primary, secondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [primaryDark.opacity(0.96), primary.opacity(0.92), secondary.opacity(0.88)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let profileHeaderGradient = LinearGradient(
        colors: [primary, secondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft mint wash for section backgrounds, stat cards, onboarding.
    static let mintWash = LinearGradient(
        colors: [Color(red: 0.93, green: 0.97, blue: 0.94),
                 Color(red: 0.88, green: 0.96, blue: 0.92)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Used behind hero images to keep white text legible.
    static let heroOverlay = LinearGradient(
        colors: [.clear, .black.opacity(0.15), .black.opacity(0.55)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Corner Radius
    enum Radius {
        static let sm: CGFloat   = 8
        static let md: CGFloat   = 14
        static let lg: CGFloat   = 20
        static let xl: CGFloat   = 28
        static let xxl: CGFloat  = 36
        static let full: CGFloat = 100
    }

    // MARK: Shadow
    struct CardShadow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .shadow(color: primary.opacity(0.06), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
    }

    struct SoftShadow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - View Extensions

extension View {
    func cardShadow() -> some View {
        modifier(AppTheme.CardShadow())
    }

    func softShadow() -> some View {
        modifier(AppTheme.SoftShadow())
    }

    func surfaceCard(radius: CGFloat = AppTheme.Radius.lg) -> some View {
        self
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .cardShadow()
    }

    /// Pill-shaped tinted "glass" surface used for stat chips, header decorations.
    func glassPill(tint: Color = AppTheme.primary) -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(tint.opacity(0.10))
            .clipShape(Capsule(style: .continuous))
    }
}
