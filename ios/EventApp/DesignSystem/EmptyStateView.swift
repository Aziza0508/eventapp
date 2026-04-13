import SwiftUI

/// Reusable empty-state placeholder used across screens.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textTertiary)

            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
            }

            if let actionTitle, let action {
                PrimaryButton(actionTitle) { action() }
                    .frame(width: 180)
                    .padding(.top, AppTheme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xxl)
    }
}
