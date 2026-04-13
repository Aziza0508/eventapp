import Foundation

// MARK: - EventRepository

protocol EventRepository {
    func listEvents(
        city: String?,
        category: String?,
        format: String?,
        search: String?,
        page: Int,
        limit: Int
    ) async throws -> EventListResponse

    func getEvent(id: Int) async throws -> EventDetailResponse
}

// MARK: - RegistrationRepository

protocol RegistrationRepository {
    func myRegistrations() async throws -> [Registration]
    func apply(eventID: Int) async throws -> Registration
}

// MARK: - Live: EventRepository

struct LiveEventRepository: EventRepository {
    private let api = APIClient.shared

    func listEvents(
        city: String?,
        category: String?,
        format: String?,
        search: String?,
        page: Int,
        limit: Int
    ) async throws -> EventListResponse {
        try await api.request(
            .events(city: city, category: category, format: format,
                    search: search, page: page, limit: limit),
            responseType: EventListResponse.self
        )
    }

    func getEvent(id: Int) async throws -> EventDetailResponse {
        try await api.request(.event(id: id), responseType: EventDetailResponse.self)
    }
}

// MARK: - Live: RegistrationRepository

struct LiveRegistrationRepository: RegistrationRepository {
    private let api = APIClient.shared

    func myRegistrations() async throws -> [Registration] {
        try await api.request(.myEvents, responseType: [Registration].self)
    }

    func apply(eventID: Int) async throws -> Registration {
        try await api.request(.apply(eventID: eventID), responseType: Registration.self)
    }
}
