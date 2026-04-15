import Foundation
import Combine
import LocalAuthentication
import UIKit

/// AuthStore is the single source of truth for authentication state.
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated = false
    @Published var biometricLocked = false

    private let api: APIClient
    private let keychain: KeychainManager

    init(api: APIClient = .shared, keychain: KeychainManager = .shared) {
        self.api = api
        self.keychain = keychain

        configureAPISessionCallbacks()

        #if DEBUG
        if AppEnvironment.shared.dataMode == .mock {
            currentUser = MockEventFactory.currentUser
            isAuthenticated = true
            return
        }
        #endif

        // Restore session from keychain.
        if let token = keychain.loadToken() {
            api.tokenProvider = { token }
            isAuthenticated = true
            Task { await fetchMe() }
        }
    }

    // MARK: - Auth Actions

    func register(email: String, password: String, fullName: String,
                  role: String = "student", city: String = "",
                  school: String = "", grade: Int? = nil) async throws {
        let response: AuthResponse = try await api.request(
            .register(email: email, password: password, fullName: fullName,
                      role: role, city: city, school: school, grade: grade),
            responseType: AuthResponse.self
        )
        applyAuth(response)
    }

    func login(email: String, password: String) async throws {
        let response: AuthResponse = try await api.request(
            .login(email: email, password: password),
            responseType: AuthResponse.self
        )
        applyAuth(response)
    }

    func logout() {
        // Revoke refresh token server-side (best-effort).
        if let refreshToken = keychain.loadRefreshToken() {
            Task {
                try? await api.requestVoid(.logout(refreshToken: refreshToken))
            }
        }

        keychain.clearAll()
        api.tokenProvider = nil
        currentUser = nil
        isAuthenticated = false
        biometricLocked = false
    }

    func useMockSession() {
        keychain.clearAll()
        api.tokenProvider = nil
        currentUser = MockEventFactory.currentUser
        isAuthenticated = true
    }

    func updateCurrentUser(_ user: User) {
        currentUser = user
    }

    var role: UserRole { currentUser?.role ?? .student }
    var isOrganizer: Bool { role == .organizer || role == .admin }

    /// True when organizer account exists but has not yet been approved by admin.
    var isOrganizerPendingApproval: Bool {
        guard let user = currentUser else { return false }
        return user.role == .organizer && user.approved == false
    }

    /// True when the account has been blocked by an admin.
    var isBlocked: Bool {
        currentUser?.blocked == true
    }

    /// Re-fetch current user from backend to check if status changed (e.g. approved).
    func refreshStatus() async {
        await fetchMe()
    }

    // MARK: - Biometric Auth

    /// Check if biometrics are available on this device.
    var canUseBiometrics: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Authenticate with Face ID / Touch ID. Returns true on success.
    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        context.localizedReason = "Unlock EventApp"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock EventApp"
            )
            if success {
                biometricLocked = false
            }
            return success
        } catch {
            return false
        }
    }

    // MARK: - Private

    private func applyAuth(_ response: AuthResponse) {
        configureAPISessionCallbacks()
        keychain.saveToken(response.accessToken)
        if let refresh = response.refreshToken {
            keychain.saveRefreshToken(refresh)
        }
        api.tokenProvider = { response.accessToken }
        currentUser = response.user
        isAuthenticated = true
        registerDeviceTokenIfNeeded()
    }

    private func fetchMe() async {
        do {
            let user: User = try await api.request(.me, responseType: User.self)
            currentUser = user
            registerDeviceTokenIfNeeded()
        } catch NetworkError.unauthorized {
            logout()
        } catch {
            // Preserve the session on transient network or backend failures.
        }
    }

    private func configureAPISessionCallbacks() {
        api.refreshTokenProvider = { [weak keychain] in keychain?.loadRefreshToken() }
        api.onTokenRefreshed = { [weak self] access, refresh in
            Task { @MainActor in
                self?.keychain.saveToken(access)
                self?.keychain.saveRefreshToken(refresh)
                self?.api.tokenProvider = { access }
            }
        }
        api.onSessionExpired = { [weak self] in
            Task { @MainActor in self?.logout() }
        }
    }

    private func registerDeviceTokenIfNeeded() {
        (UIApplication.shared.delegate as? AppDelegate)?.registerDeviceTokenIfNeeded()
    }
}

// MARK: - Auth DTOs

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}
