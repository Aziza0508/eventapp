import Foundation

@MainActor
final class MyEventsViewModel: ObservableObject {
    @Published var state: Loadable<[Registration]> = .idle

    let toast = ToastPresenter()

    private let repository: any RegistrationRepository
    private let api: APIClient

    init(repository: (any RegistrationRepository)? = nil, api: APIClient = .shared) {
        self.repository = repository ?? AppEnvironment.shared.makeRegistrationRepository()
        self.api = api
    }

    func load() async {
        state = .loading
        do {
            let regs = try await repository.myRegistrations()
            state = .success(regs)
        } catch {
            state = .failure(error)
        }
    }

    func cancel(regID: Int) async {
        do {
            try await api.requestVoid(.cancelRegistration(regID: regID))
            toast.showSuccess("Registration cancelled")
            await load()
        } catch {
            toast.showError(error)
        }
    }
}
