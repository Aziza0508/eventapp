import Foundation

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var applyState: Loadable<Registration> = .idle
    @Published var myRegistration: Registration?
    @Published var isFavorite = false
    @Published var freeSeats = 0
    @Published var detailedEvent: Event?

    let toast = ToastPresenter()

    private let regRepo: any RegistrationRepository
    private let api: APIClient

    init(repository: (any RegistrationRepository)? = nil, api: APIClient = .shared) {
        self.regRepo = repository ?? AppEnvironment.shared.makeRegistrationRepository()
        self.api = api
    }

    func loadDetails(eventID: Int) async {
        do {
            let detail: EventDetailResponse = try await api.request(
                .event(id: eventID),
                responseType: EventDetailResponse.self
            )
            detailedEvent = detail.asEvent
            freeSeats = detail.freeSeats
            isFavorite = detail.isFavorite
        } catch {
            toast.showError(error)
        }
    }

    func apply(eventID: Int) async {
        applyState = .loading
        do {
            let reg = try await regRepo.apply(eventID: eventID)
            applyState = .success(reg)
            myRegistration = reg
            toast.showSuccess("Application submitted!")
        } catch {
            applyState = .failure(error)
        }
    }

    func setExistingRegistration(_ reg: Registration?) {
        myRegistration = reg
        if let reg = reg {
            applyState = .success(reg)
        }
    }

    func setDetailData(freeSeats: Int, isFavorite: Bool) {
        self.freeSeats = freeSeats
        self.isFavorite = isFavorite
    }

    func toggleFavorite(eventID: Int) async {
        let wasFavorite = isFavorite
        // Optimistic UI update
        isFavorite.toggle()
        do {
            if wasFavorite {
                try await api.requestVoid(.removeFavorite(eventID: eventID))
                toast.showSuccess("Removed from saved")
            } else {
                let _: [String: String] = try await api.request(
                    .addFavorite(eventID: eventID),
                    responseType: [String: String].self
                )
                toast.showSuccess("Saved to favorites")
            }
        } catch {
            // Revert on failure
            isFavorite = wasFavorite
            toast.showError(error)
        }
    }
}
