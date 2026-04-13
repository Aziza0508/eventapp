import Foundation

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case unauthorized
    case forbidden
    case notFound
    case conflict(String)
    case validation(String)
    case server(String)
    case decoding(Error)
    case unknown(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid URL"
        case .unauthorized:        return "Please log in again"
        case .forbidden:           return "You don't have permission to do this"
        case .notFound:            return "Not found"
        case .conflict(let msg):   return msg
        case .validation(let msg): return msg
        case .server(let msg):     return "Server error: \(msg)"
        case .decoding(let e):     return "Response parsing error: \(e.localizedDescription)"
        case .unknown(let code, let msg): return "Error \(code): \(msg)"
        }
    }
}

// MARK: - API Error Response

private struct APIErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let code: String
        let message: String
    }
    let error: ErrorBody
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient()

    /// Resolved dynamically from AppEnvironment so switching server env takes effect immediately.
    private var baseURL: URL { AppEnvironment.shared.baseURL }

    private let session: URLSession
    private let decoder: JSONDecoder

    /// Inject token through a closure to avoid circular dependency with AuthStore.
    var tokenProvider: (() -> String?)?

    /// Called when a 401 cannot be recovered (refresh failed). AuthStore sets this.
    var onSessionExpired: (() -> Void)?

    /// Provides the refresh token for auto-retry.
    var refreshTokenProvider: (() -> String?)?

    /// Called after a successful token refresh to persist new tokens.
    var onTokenRefreshed: ((_ access: String, _ refresh: String) -> Void)?

    private var isRefreshing = false

    init(session: URLSession = .shared) {
        self.session = session

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Core Request

    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type = T.self
    ) async throws -> T {
        do {
            return try await performRequest(endpoint, responseType: responseType)
        } catch NetworkError.unauthorized {
            // Try to refresh token and retry once.
            if endpoint.path != "/auth/refresh" && endpoint.path != "/auth/login" {
                if try await attemptTokenRefresh() {
                    return try await performRequest(endpoint, responseType: responseType)
                }
            }
            onSessionExpired?()
            throw NetworkError.unauthorized
        }
    }

    func requestVoid(_ endpoint: Endpoint) async throws {
        do {
            try await performRequestVoid(endpoint)
        } catch NetworkError.unauthorized {
            if endpoint.path != "/auth/refresh" && endpoint.path != "/auth/logout" {
                if try await attemptTokenRefresh() {
                    try await performRequestVoid(endpoint)
                    return
                }
            }
            onSessionExpired?()
            throw NetworkError.unauthorized
        }
    }

    // MARK: - Token Refresh

    private func attemptTokenRefresh() async throws -> Bool {
        guard !isRefreshing,
              let refreshToken = refreshTokenProvider?(),
              let accessToken = tokenProvider?() else {
            return false
        }

        isRefreshing = true
        defer { isRefreshing = false }

        // Build refresh request manually — needs expired access token in header.
        let refreshEndpoint = Endpoint.refresh(refreshToken: refreshToken)
        var urlRequest = try buildRequest(refreshEndpoint)
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            return false
        }

        // Parse new tokens.
        struct RefreshResponse: Decodable {
            let accessToken: String
            let refreshToken: String
            let user: User
            enum CodingKeys: String, CodingKey {
                case accessToken  = "access_token"
                case refreshToken = "refresh_token"
                case user
            }
        }

        guard let result = try? decoder.decode(RefreshResponse.self, from: data) else {
            return false
        }

        // Persist new tokens.
        onTokenRefreshed?(result.accessToken, result.refreshToken)
        return true
    }

    // MARK: - Internal Request Execution

    private func performRequest<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        let urlRequest = try buildRequest(endpoint)
        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown(0, "No HTTP response")
        }

        if (200..<300).contains(http.statusCode) {
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decoding(error)
            }
        }

        throw mapError(statusCode: http.statusCode, data: data)
    }

    private func performRequestVoid(_ endpoint: Endpoint) async throws {
        let urlRequest = try buildRequest(endpoint)
        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown(0, "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw mapError(statusCode: http.statusCode, data: data)
        }
    }

    private func mapError(statusCode: Int, data: Data) -> NetworkError {
        let errorMessage = (try? decoder.decode(APIErrorResponse.self, from: data))?.error.message
            ?? String(data: data, encoding: .utf8)
            ?? "Unknown error"

        switch statusCode {
        case 400: return .validation(errorMessage)
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 409: return .conflict(errorMessage)
        case 500...: return .server(errorMessage)
        default:  return .unknown(statusCode, errorMessage)
        }
    }

    // MARK: - Multipart Upload

    /// Upload image data as multipart/form-data. Returns the parsed response.
    func uploadImage<T: Decodable>(
        path: String,
        imageData: Data,
        filename: String,
        mimeType: String = "image/jpeg",
        responseType: T.Type
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        let boundary = "Boundary-\(UUID().uuidString)"

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = tokenProvider?() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown(0, "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw mapError(statusCode: http.statusCode, data: data)
        }
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Build URLRequest

    private func buildRequest(_ endpoint: Endpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path),
                                       resolvingAgainstBaseURL: true)!

        if let params = endpoint.queryParams {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        }

        guard let url = components.url else { throw NetworkError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if endpoint.requiresAuth, let token = tokenProvider?() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            req.httpBody = try encoder.encode(body)
        }

        return req
    }
}
