import SwiftUI

// MARK: - Onboarding data

private struct OnboardingPage {
    let illustration: String
    let tint: Color
    let accent: Color
    let eyebrow: String
    let title: String
    let subtitle: String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        illustration: "sparkles",
        tint: AppTheme.primary,
        accent: AppTheme.secondary,
        eyebrow: "DISCOVER",
        title: "Find events that\nmatch your ambition",
        subtitle: "Hackathons, robotics tournaments, AI bootcamps — everything in one feed curated for school students across Kazakhstan."
    ),
    OnboardingPage(
        illustration: "bolt.badge.checkmark",
        tint: AppTheme.secondary,
        accent: AppTheme.primary,
        eyebrow: "APPLY",
        title: "Register in\nseconds, not days",
        subtitle: "One-tap applications, live registration status, smart waitlists, and instant push updates when a seat opens up."
    ),
    OnboardingPage(
        illustration: "trophy.fill",
        tint: Color(red: 0.82, green: 0.62, blue: 0.14),
        accent: AppTheme.primary,
        eyebrow: "GROW",
        title: "Build your\nSTEM journey",
        subtitle: "Track every event you've joined, collect achievements, and grow a portfolio you can actually show to universities."
    )
]

// MARK: - Onboarding view

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppTheme.mintWash.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        OnboardingPageView(page: pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Controls
                VStack(spacing: AppTheme.Spacing.lg) {
                    HStack(spacing: 6) {
                        ForEach(pages.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? AppTheme.primary : AppTheme.primary.opacity(0.18))
                                .frame(width: i == currentPage ? 28 : 8, height: 8)
                                .animation(.spring(duration: 0.3), value: currentPage)
                        }
                    }

                    if currentPage < pages.count - 1 {
                        PrimaryButton("Continue") {
                            withAnimation { currentPage += 1 }
                        }
                    } else {
                        PrimaryButton("Get started") {
                            hasSeenOnboarding = true
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.bottom, AppTheme.Spacing.xl)
            }

            // Skip button
            if currentPage < pages.count - 1 {
                Button("Skip") { hasSeenOnboarding = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, AppTheme.Spacing.xl)
                    .padding(.trailing, AppTheme.Spacing.xl)
            }
        }
    }
}

// MARK: - Single page

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer(minLength: 24)

            // Layered illustration
            ZStack {
                // Outer soft square
                RoundedRectangle(cornerRadius: 52, style: .continuous)
                    .fill(page.tint.opacity(0.12))
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-8))

                // Middle circle
                Circle()
                    .fill(page.tint.opacity(0.22))
                    .frame(width: 200, height: 200)

                // Inner gradient "ticket"
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [page.tint, page.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 150)
                    .shadow(color: page.tint.opacity(0.35), radius: 18, y: 10)

                Image(systemName: page.illustration)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)

                // Floating accent dot
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 28, height: 28)
                    .offset(x: 80, y: -90)
                    .shadow(color: AppTheme.accent.opacity(0.4), radius: 6)
            }

            VStack(spacing: AppTheme.Spacing.md) {
                Text(page.eyebrow)
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(page.tint)
                Text(page.title)
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(page.subtitle)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, AppTheme.Spacing.lg)
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            Spacer(minLength: 40)
        }
    }
}
