import SwiftUI

/// Rounded search field used on Discover, Favorites, etc.
/// Extracted from EventListView so every screen can share the same shape.
struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            TextField(placeholder, text: $text)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                    onSubmit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .frame(height: 50)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .strokeBorder(AppTheme.divider, lineWidth: 1)
        }
        .softShadow()
    }
}
