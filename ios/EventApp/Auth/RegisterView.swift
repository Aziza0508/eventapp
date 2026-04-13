import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var city = ""
    @State private var school = ""
    @State private var selectedRole = "student"
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 &&
        !isLoading
    }

    var body: some View {
        ZStack {
            AppTheme.mintWash.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header

                    VStack(spacing: AppTheme.Spacing.lg) {
                        rolePicker

                        VStack(spacing: AppTheme.Spacing.md) {
                            IconTextField(
                                icon: "person.fill",
                                placeholder: "Full name",
                                text: $fullName
                            )
                            IconTextField(
                                icon: "envelope.fill",
                                placeholder: "Email address",
                                text: $email,
                                keyboardType: .emailAddress,
                                autocapitalization: .never
                            )
                            IconTextField(
                                icon: "lock.fill",
                                placeholder: "Password (at least 6 characters)",
                                text: $password,
                                autocapitalization: .never,
                                isSecure: true
                            )
                            IconTextField(
                                icon: "mappin.and.ellipse",
                                placeholder: "City (optional)",
                                text: $city
                            )
                            if selectedRole == "student" {
                                IconTextField(
                                    icon: "building.columns.fill",
                                    placeholder: "School (optional)",
                                    text: $school
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .animation(.spring(duration: 0.3), value: selectedRole)

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

                        PrimaryButton("Create account", isLoading: isLoading, isDisabled: !canSubmit) {
                            register()
                        }

                        TextLinkButton("Sign in", prefix: "Already have an account?") {
                            dismiss()
                        }
                        .padding(.top, AppTheme.Spacing.sm)
                    }
                    .padding(AppTheme.Spacing.lg)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous))
                    .cardShadow()
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.bottom, AppTheme.Spacing.xxl)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Create your account")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Join students across Kazakhstan discovering the next STEM opportunity.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.xxl)
        .padding(.bottom, AppTheme.Spacing.lg)
    }

    // MARK: - Role picker

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionEyebrow(text: "I want to")

            HStack(spacing: AppTheme.Spacing.sm) {
                roleTile(
                    role: "student",
                    title: "Join events",
                    subtitle: "As a student",
                    icon: "graduationcap.fill"
                )
                roleTile(
                    role: "organizer",
                    title: "Run events",
                    subtitle: "As an organizer",
                    icon: "person.badge.key.fill"
                )
            }
        }
    }

    private func roleTile(role: String, title: String, subtitle: String, icon: String) -> some View {
        let isSelected = selectedRole == role
        return Button {
            withAnimation(.spring(duration: 0.25)) { selectedRole = role }
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(isSelected ? .white.opacity(0.20) : AppTheme.primary.opacity(0.10))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isSelected ? .white : AppTheme.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    Text(subtitle)
                        .font(.caption)
                        .opacity(0.85)
                }
            }
            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                        .fill(AppTheme.primaryGradient)
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                        .fill(AppTheme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                                .strokeBorder(AppTheme.divider, lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func register() {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                try await auth.register(
                    email: email,
                    password: password,
                    fullName: fullName,
                    role: selectedRole,
                    city: city,
                    school: school
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
