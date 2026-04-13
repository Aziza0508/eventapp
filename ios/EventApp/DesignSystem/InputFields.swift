import SwiftUI

// MARK: - IconTextField
// Text field with a leading SF Symbol icon — matches the screenshot design.

struct IconTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure: Bool = false

    @State private var isPasswordVisible = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 20)

            Group {
                if isSecure && !isPasswordVisible {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled()
                }
            }
            .font(.body)

            if isSecure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .frame(height: 56)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                .strokeBorder(AppTheme.divider, lineWidth: 1)
        }
    }
}
