import SwiftUI

/// Compact stat card used in Organizer Dashboard summary and My Events hero.
/// Renders a number, a label, and a tinted icon.
/// (Named `DashboardStatCard` to avoid collision with the private `StatCard`
/// already defined inside OrganizerReportsView.swift.)
struct DashboardStatCard: View {
    let icon: String
    let label: String
    let value: String
    var tint: Color = AppTheme.primary
    var trend: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }
                Spacer()
                if let trend {
                    Text(trend)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.success.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .softShadow()
    }
}

/// Tiny horizontal stat pill used in the Profile hero strip.
struct StatPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
    }
}
