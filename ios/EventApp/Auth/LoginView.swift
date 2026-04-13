import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRegister = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 &&
        !isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppTheme.mintWash.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        brandHero

                        formCard

                        TextLinkButton("Sign up", prefix: "New to EventApp?") {
                            showRegister = true
                        }
                        .padding(.top, AppTheme.Spacing.lg)
                        .padding(.bottom, AppTheme.Spacing.xxl)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }

    // MARK: - Brand hero

    private var brandHero: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Logo mark
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 72, height: 72)
                    .shadow(color: AppTheme.primary.opacity(0.35), radius: 12, y: 6)
                Text("E")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(.top, AppTheme.Spacing.xxl)

            VStack(spacing: 6) {
                Text("Welcome back")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Sign in and pick up where you left off.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.bottom, AppTheme.Spacing.xl)
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            IconTextField(
                icon: "envelope.fill",
                placeholder: "Email address",
                text: $email,
                keyboardType: .emailAddress,
                autocapitalization: .never
            )

            IconTextField(
                icon: "lock.fill",
                placeholder: "Password",
                text: $password,
                autocapitalization: .never,
                isSecure: true
            )

            HStack {
                Spacer()
                Button("Forgot password?") { }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            if let error = errorMessage {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error).font(.caption)
                }
                .foregroundStyle(AppTheme.error)
                .padding(AppTheme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.error.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            }

            PrimaryButton("Sign in", isLoading: isLoading, isDisabled: !canSubmit) {
                login()
            }
            .padding(.top, AppTheme.Spacing.xs)

            HStack(spacing: AppTheme.Spacing.sm) {
                Rectangle().fill(AppTheme.divider).frame(height: 1)
                Text("OR")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                Rectangle().fill(AppTheme.divider).frame(height: 1)
            }
            .padding(.vertical, AppTheme.Spacing.xs)

            SecondaryButton("Continue with Google", systemImage: "globe") { }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous))
        .cardShadow()
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

    private func login() {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                try await auth.login(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
