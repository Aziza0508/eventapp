import SwiftUI

/// Standard section header used across screens: title + optional trailing
/// "See all" action. Keeps vertical rhythm consistent between Discover, My
/// Events, Organizer Dashboard, and Profile.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }
}

/// Small uppercase eyebrow label for settings-style grouped rows.
struct SectionEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(AppTheme.textSecondary)
    }
}
