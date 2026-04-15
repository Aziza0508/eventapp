import Foundation
import SwiftUI

// MARK: - DataMode

enum DataMode: String, CaseIterable, Identifiable {
    case mock = "Mock"
    case live = "Live"
    var id: String { rawValue }
}

// MARK: - ServerEnvironment

/// Predefined backend targets. Add LAN/tunnel URLs here for demo.
enum ServerEnvironment: String, CaseIterable, Identifiable {
    case local      = "Local"
    case lan        = "LAN / Tunnel"
    case production = "Production"

    var id: String { rawValue }
    private static let localhostURL = URL(string: "http://localhost:8080")!

    private var configuredBaseURL: URL? {
        guard let raw = Bundle.main.infoDictionary?["EA_API_BASE_URL"] as? String,
              let url = URL(string: raw),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return url
    }

    var baseURL: URL {
        switch self {
        case .local:
            return Self.localhostURL
        case .lan:
            // Use the configured LAN/tunnel URL when present.
            return configuredBaseURL ?? Self.localhostURL
        case .production:
            return configuredBaseURL ?? URL(string: "https://api.eventapp.kz")!
        }
    }
}

// MARK: - AppEnvironment

/// Single source of truth for data-layer configuration.
/// Inject into SwiftUI environment via `.environmentObject(AppEnvironment.shared)`.
///
/// Default in DEBUG builds:  `.mock` (works without a running backend)
/// Default in RELEASE builds: `.live` (hits real Go API)
final class AppEnvironment: ObservableObject {

    static let shared = AppEnvironment()
    private static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private static var defaultDebugServerEnvironment: ServerEnvironment {
        if isRunningOnSimulator {
            return .local
        }
        guard let raw = Bundle.main.infoDictionary?["EA_API_BASE_URL"] as? String else {
            return .local
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty || trimmed.contains("localhost") || trimmed.contains("127.0.0.1") {
            return .local
        }
        return .lan
    }

    // Phase A change (diploma stabilization): DEBUG defaults to `.live` so the
    // canonical demo path — Docker infra + seeded Postgres + local Go API —
    // is what the simulator actually shows. Mock remains opt-in via the
    // Profile → Developer toggle for offline UI work.
    #if DEBUG
    @Published var dataMode: DataMode = .live
    @Published var serverEnvironment: ServerEnvironment = AppEnvironment.defaultDebugServerEnvironment
    #else
    @Published var dataMode: DataMode = .live
    @Published var serverEnvironment: ServerEnvironment = .production
    #endif

    /// Resolved base URL for the current server environment.
    var baseURL: URL { serverEnvironment.baseURL }

    // MARK: - Factory

    func makeEventRepository() -> any EventRepository {
        switch dataMode {
        case .mock: return MockEventRepository()
        case .live: return LiveEventRepository()
        }
    }

    func makeRegistrationRepository() -> any RegistrationRepository {
        switch dataMode {
        case .mock: return MockRegistrationRepository()
        case .live: return LiveRegistrationRepository()
        }
    }
}
