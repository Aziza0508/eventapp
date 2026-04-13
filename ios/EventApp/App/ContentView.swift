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
                Task { await auth.authenticateWithBiometrics() }
            }
            .frame(width: 200)

            Spacer()
        }
        .task {
            await auth.authenticateWithBiometrics()
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
    @StateObject private var notifVM = NotificationsViewModel()
    @State private var showNotifications = false

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
        .overlay(alignment: .topTrailing) {
            notificationBell
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .task {
            await notifVM.fetchUnreadCount()
        }
    }

    private var notificationBell: some View {
        Button {
            showNotifications = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.surface)
                    .clipShape(Circle())
                    .cardShadow()

                if notifVM.unreadCount > 0 {
                    Text("\(min(notifVM.unreadCount, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(AppTheme.error)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .padding(.trailing, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.xs)
    }
}
