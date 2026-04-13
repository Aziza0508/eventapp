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

    var baseURL: URL {
        switch self {
        case .local:
            // Simulator / same machine.
            return URL(string: "http://localhost:8080")!
        case .lan:
            // Change this to your LAN IP or ngrok/tunnel URL for device testing.
            // Example: "http://192.168.1.42:8080" or "https://abc123.ngrok.io"
            let override = Bundle.main.infoDictionary?["EA_API_BASE_URL"] as? String
            return URL(string: override ?? "http://localhost:8080")!
        case .production:
            let override = Bundle.main.infoDictionary?["EA_API_BASE_URL"] as? String
            return URL(string: override ?? "https://api.eventapp.kz")!
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

    // Phase A change (diploma stabilization): DEBUG defaults to `.live` so the
    // canonical demo path — Docker infra + seeded Postgres + local Go API —
    // is what the simulator actually shows. Mock remains opt-in via the
    // Profile → Developer toggle for offline UI work.
    #if DEBUG
    @Published var dataMode: DataMode = .live
    @Published var serverEnvironment: ServerEnvironment = .local
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
