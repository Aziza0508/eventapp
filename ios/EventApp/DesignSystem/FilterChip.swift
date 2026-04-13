import SwiftUI

// MARK: - FilterChip
// Pill-shaped selectable chip used in the Discover screen category row.

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background {
                    if isSelected {
                        Capsule().fill(AppTheme.primaryGradient)
                    } else {
                        Capsule()
                            .fill(AppTheme.surface)
                            .overlay {
                                Capsule().strokeBorder(AppTheme.divider, lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

// MARK: - Chip Row
// Horizontal scrollable row of FilterChips

struct FilterChipRow<Item: Hashable>: View {
    let items: [Item]
    @Binding var selected: Item
    let title: (Item) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(items, id: \.self) { item in
                    FilterChip(title: title(item), isSelected: selected == item) {
                        selected = item
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - Segment Control
// Custom pill-shaped segmented control (Upcoming / Past)

struct PillSegmentControl: View {
    let segments: [String]
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(duration: 0.25)) { selected = i }
                } label: {
                    Text(segments[i])
                        .font(.subheadline.weight(selected == i ? .semibold : .regular))
                        .foregroundStyle(selected == i ? AppTheme.textPrimary : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if selected == i {
                                RoundedRectangle(cornerRadius: AppTheme.Radius.full)
                                    .fill(AppTheme.surface)
                                    .cardShadow()
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.systemFill))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.full))
    }
}
