import SwiftUI

/// Shown when an organizer's account is pending admin approval.
/// They can still access profile and sign out, but cannot create or manage events.
struct OrganizerPendingView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.warning.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "hourglass")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.warning)
            }

            Text("Account Pending Approval")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)

            Text("Your organizer account is being reviewed by an administrator. You'll be able to create and manage events once approved.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)

            // What you can do
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                statusRow(icon: "checkmark.circle.fill", color: AppTheme.success,
                          text: "Browse events")
                statusRow(icon: "checkmark.circle.fill", color: AppTheme.success,
                          text: "Edit your profile")
                statusRow(icon: "xmark.circle.fill", color: AppTheme.error,
                          text: "Create events")
                statusRow(icon: "xmark.circle.fill", color: AppTheme.error,
                          text: "Manage participants")
            }
            .padding(AppTheme.Spacing.lg)
            .surfaceCard()
            .padding(.horizontal, AppTheme.Spacing.xl)

            Spacer()

            VStack(spacing: AppTheme.Spacing.md) {
                PrimaryButton("Refresh Status") {
                    Task { await auth.refreshStatus() }
                }

                Button(role: .destructive) {
                    auth.logout()
                } label: {
                    Text("Sign Out")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.error)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func statusRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

/// Shown when a user's account has been blocked by an admin.
struct AccountBlockedView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.error.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.error)
            }

            Text("Account Restricted")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)

            Text("Your account has been restricted by an administrator. If you believe this is a mistake, please contact support.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)

            Spacer()

            Button(role: .destructive) {
                auth.logout()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                        .font(.headline)
                }
                .foregroundStyle(AppTheme.error)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(AppTheme.error.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.full))
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}
