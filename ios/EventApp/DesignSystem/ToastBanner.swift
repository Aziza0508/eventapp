import SwiftUI

// MARK: - Toast Style

enum ToastStyle {
    case success
    case error
    case info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return AppTheme.success
        case .error:   return AppTheme.error
        case .info:    return AppTheme.primary
        }
    }
}

// MARK: - Toast Item

struct ToastItem: Equatable {
    let id = UUID()
    let style: ToastStyle
    let message: String

    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - ToastPresenter (observable, shared per view hierarchy)

@MainActor
final class ToastPresenter: ObservableObject {
    @Published var current: ToastItem?

    func show(_ style: ToastStyle, _ message: String) {
        current = ToastItem(style: style, message: message)
    }

    func showSuccess(_ message: String) { show(.success, message) }
    func showError(_ error: Error)      { show(.error, error.localizedDescription) }
    func showError(_ message: String)   { show(.error, message) }
    func dismiss()                      { current = nil }
}

// MARK: - Toast Banner View

private struct ToastBannerView: View {
    let item: ToastItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: item.style.icon)
                .font(.body.bold())
                .foregroundStyle(item.style.tint)

            Text(item.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        .cardShadow()
        .padding(.horizontal, AppTheme.Spacing.xl)
    }
}

// MARK: - View Modifier

struct ToastOverlayModifier: ViewModifier {
    @ObservedObject var presenter: ToastPresenter

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let item = presenter.current {
                    ToastBannerView(item: item) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            presenter.dismiss()
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, AppTheme.Spacing.sm)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if presenter.current == item {
                                    presenter.dismiss()
                                }
                            }
                        }
                    }
                }
            }
            .animation(.spring(duration: 0.3), value: presenter.current)
    }
}

extension View {
    func toastOverlay(_ presenter: ToastPresenter) -> some View {
        modifier(ToastOverlayModifier(presenter: presenter))
    }
}
