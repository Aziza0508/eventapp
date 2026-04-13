import Foundation
import Combine

@MainActor
final class EventListViewModel: ObservableObject {
    @Published var state: Loadable<[Event]> = .idle
    @Published var filterCity     = ""
    @Published var filterCategory = ""
    @Published var filterFormat   = ""
    @Published var searchQuery    = ""
    @Published private(set) var totalCount = 0
    @Published private(set) var isOffline = false

    private var page = 1
    private let limit = 20
    private var canLoadMore = true
    private let repository: any EventRepository
    private let cache = EventCache.shared

    init(repository: (any EventRepository)? = nil) {
        self.repository = repository ?? AppEnvironment.shared.makeEventRepository()
    }

    func loadInitial() async {
        page = 1
        canLoadMore = true
        isOffline = false

        // Show cached data immediately if available.
        if state.value == nil, let cached = await cache.load() {
            state = .success(cached.data)
            totalCount = cached.total
        } else {
            state = .loading
        }

        await fetch(reset: true)
    }

    func loadMore() async {
        guard canLoadMore, !state.isLoading else { return }
        await fetch(reset: false)
    }

    func applyFilters() async {
        await loadInitial()
    }

    func clearFilters() async {
        filterCity = ""
        filterCategory = ""
        filterFormat = ""
        searchQuery = ""
        await loadInitial()
    }

    private func fetch(reset: Bool) async {
        do {
            let response = try await repository.listEvents(
                city:     filterCity.isEmpty     ? nil : filterCity,
                category: filterCategory.isEmpty ? nil : filterCategory,
                format:   filterFormat.isEmpty   ? nil : filterFormat,
                search:   searchQuery.isEmpty    ? nil : searchQuery,
                page:     page,
                limit:    limit
            )

            let events = reset ? response.data : (state.value ?? []) + response.data
            totalCount = response.total
            canLoadMore = events.count < response.total
            page += 1
            state = .success(events)
            isOffline = false

            // Cache first page of unfiltered results.
            if reset && filterCity.isEmpty && filterCategory.isEmpty &&
               filterFormat.isEmpty && searchQuery.isEmpty {
                await cache.save(response)
            }
        } catch {
            // If we have cached data, keep showing it.
            if state.value != nil {
                isOffline = true
            } else {
                state = .failure(error)
            }
        }
    }
}
