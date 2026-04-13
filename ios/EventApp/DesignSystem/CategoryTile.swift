import SwiftUI

/// Rounded "browse" tile used in the Discover horizontal category strip.
/// Each tile carries a softly tinted color that matches the category theme.
struct CategoryTile: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                        .fill(isSelected ? tint : tint.opacity(0.16))
                        .frame(width: 58, height: 58)
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : tint)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25), value: isSelected)
    }
}
