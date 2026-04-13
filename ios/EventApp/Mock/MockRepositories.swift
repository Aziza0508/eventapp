import Foundation

// MARK: - MockEventRepository

struct MockEventRepository: EventRepository {

    func listEvents(
        city: String?,
        category: String?,
        format: String?,
        search: String?,
        page: Int,
        limit: Int
    ) async throws -> EventListResponse {
        try await Task.sleep(nanoseconds: 600_000_000)

        var events = MockEventFactory.allEvents

        if let city = city, !city.isEmpty {
            events = events.filter {
                $0.city?.localizedCaseInsensitiveContains(city) ?? false
            }
        }
        if let category = category, !category.isEmpty {
            events = events.filter {
                $0.category?.localizedCaseInsensitiveContains(category) ?? false
            }
        }
        if let format = format, !format.isEmpty {
            events = events.filter { $0.format?.rawValue == format }
        }
        if let search = search, !search.isEmpty {
            events = events.filter {
                $0.title.localizedCaseInsensitiveContains(search) ||
                ($0.description?.localizedCaseInsensitiveContains(search) ?? false)
            }
        }

        let total = events.count
        let clampedLimit = limit > 0 ? limit : 20
        let clampedPage  = page > 0 ? page : 1
        let startIndex   = (clampedPage - 1) * clampedLimit
        let endIndex     = min(startIndex + clampedLimit, total)
        let pageSlice    = startIndex < total ? Array(events[startIndex..<endIndex]) : []

        return EventListResponse(data: pageSlice, total: total, page: clampedPage, limit: clampedLimit)
    }

    func getEvent(id: Int) async throws -> EventDetailResponse {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard let event = MockEventFactory.allEvents.first(where: { $0.id == id }) else {
            throw NetworkError.notFound
        }
        return EventDetailResponse(
            id: event.id, title: event.title, description: event.description,
            category: event.category, tags: event.tags, format: event.format,
            city: event.city, address: event.address,
            latitude: event.latitude, longitude: event.longitude,
            organizerContact: event.organizerContact,
            additionalInfo: event.additionalInfo,
            dateStart: event.dateStart, dateEnd: event.dateEnd,
            regDeadline: event.regDeadline, capacity: event.capacity,
            isFree: event.isFree, price: event.price,
            posterURL: event.posterURL, checkinToken: event.checkinToken,
            organizerID: event.organizerID, organizer: event.organizer,
            createdAt: event.createdAt,
            freeSeats: max(0, event.capacity - 3),
            isFavorite: event.id == 1 || event.id == 3
        )
    }
}

// MARK: - MockRegistrationRepository

struct MockRegistrationRepository: RegistrationRepository {

    func myRegistrations() async throws -> [Registration] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return MockEventFactory.myRegistrations
    }

    func apply(eventID: Int) async throws -> Registration {
        try await Task.sleep(nanoseconds: 800_000_000)

        guard let event = MockEventFactory.allEvents.first(where: { $0.id == eventID }) else {
            throw NetworkError.notFound
        }

        let alreadyApplied = MockEventFactory.myRegistrations.contains { $0.eventID == eventID }
        if alreadyApplied {
            throw NetworkError.conflict("You have already applied to this event.")
        }

        return Registration(
            id: 9000 + eventID,
            userID: MockEventFactory.currentUser.id,
            eventID: eventID,
            status: .pending,
            checkedInAt: nil,
            event: event,
            user: MockEventFactory.currentUser,
            createdAt: Date()
        )
    }
}
