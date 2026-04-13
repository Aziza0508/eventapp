import SwiftUI

// MARK: - PrimaryButton
// Full-width gradient button used for Sign In, Apply, Get Started, etc.

struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(_ title: String, isLoading: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isDisabled
                    ? LinearGradient(colors: [Color(.systemGray3), Color(.systemGray3)], startPoint: .leading, endPoint: .trailing)
                    : AppTheme.primaryGradient
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.full))
        }
        .disabled(isLoading || isDisabled)
    }
}

// MARK: - SecondaryButton
// Outlined button (e.g. "Continue with Google", "Skip")

struct SecondaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = systemImage {
                    Image(systemName: icon)
                        .font(.subheadline)
                }
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.full))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.full)
                    .strokeBorder(AppTheme.divider, lineWidth: 1)
            }
        }
    }
}

// MARK: - TextLinkButton
// Inline text-only link

struct TextLinkButton: View {
    let prefix: String?
    let title: String
    let action: () -> Void

    init(_ title: String, prefix: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.prefix = prefix
        self.action = action
    }

    var body: some View {
        HStack(spacing: 4) {
            if let p = prefix {
                Text(p).foregroundStyle(AppTheme.textSecondary)
            }
            Button(action: action) {
                Text(title)
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
            }
        }
        .font(.subheadline)
    }
}
