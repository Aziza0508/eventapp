import SwiftUI

/// Lightweight placeholder used while events load.
/// Gives the Discover screen visible rhythm instead of a bare spinner.
struct SkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .fill(shimmerFill)
                .frame(width: 84, height: 100)
                .padding(AppTheme.Spacing.md)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Capsule()
                    .fill(shimmerFill)
                    .frame(width: 90, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerFill)
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerFill)
                    .frame(width: 140, height: 12)
                HStack(spacing: AppTheme.Spacing.sm) {
                    Capsule()
                        .fill(shimmerFill)
                        .frame(width: 60, height: 14)
                    Capsule()
                        .fill(shimmerFill)
                        .frame(width: 40, height: 14)
                }
            }
            .padding(.vertical, AppTheme.Spacing.md)
            .padding(.trailing, AppTheme.Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .softShadow()
        .onAppear { isAnimating = true }
    }

    private var shimmerFill: some ShapeStyle {
        AppTheme.surfaceTinted.opacity(isAnimating ? 0.6 : 1.0)
    }
}
