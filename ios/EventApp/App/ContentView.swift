import SwiftUI

// Root view — shows Onboarding on first launch, then auth or main tabs.
struct ContentView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var appEnv: AppEnvironment
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if !hasSeenOnboarding {
                OnboardingView()
            } else if auth.isAuthenticated {
                if auth.biometricLocked {
                    biometricLockScreen
                } else if auth.isBlocked {
                    AccountBlockedView()
                } else if auth.isOrganizerPendingApproval {
                    OrganizerPendingTabView()
                        .id(appEnv.dataMode)
                } else {
                    MainTabView()
                        .id(appEnv.dataMode)
                }
            } else {
                LoginView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && biometricEnabled && auth.isAuthenticated {
                auth.biometricLocked = true
            }
        }
    }

    // MARK: - Biometric Lock Screen

    private var biometricLockScreen: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.primary)

            Text("EventApp is Locked")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)

            Text("Authenticate to continue")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            PrimaryButton("Unlock") {
                Task { _ = await auth.authenticateWithBiometrics() }
            }
            .frame(width: 200)

            Spacer()
        }
        .task {
            _ = await auth.authenticateWithBiometrics()
        }
    }
}

// MARK: - Organizer Pending Tab View (limited access)

/// When an organizer's account is pending approval, they can browse events and
/// edit their profile, but the "My Events" tab shows the pending status screen
/// instead of the organizer dashboard.
struct OrganizerPendingTabView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        TabView {
            EventListView()
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }

            OrganizerPendingView()
                .tabItem {
                    Label("My Events", systemImage: "calendar")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        .tint(AppTheme.primary)
    }
}

// MARK: - Main Tab Bar

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        TabView {
            EventListView()
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }

            FavoritesView()
                .tabItem {
                    Label("Saved", systemImage: "bookmark")
                }

            if auth.isOrganizer {
                OrganizerDashboardView()
                    .tabItem {
                        Label("My Events", systemImage: "calendar")
                    }
            } else {
                MyEventsView()
                    .tabItem {
                        Label("My Events", systemImage: "ticket")
                    }
            }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        .tint(AppTheme.primary)
    }
}
