import Foundation

@MainActor
final class EditProfileViewModel: ObservableObject {
    @Published var fullName: String = ""
    @Published var phone: String = ""
    @Published var school: String = ""
    @Published var city: String = ""
    @Published var grade: Int = 0
    @Published var bio: String = ""
    @Published var interests: [String] = []
    @Published var visibleToOrganizers: Bool = true
    @Published var visibleToSchool: Bool = true

    @Published var state: Loadable<User> = .idle
    @Published var newInterest: String = ""

    let toast = ToastPresenter()
    var onSaved: ((User) -> Void)?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    /// Populate form fields from the current user.
    func populate(from user: User) {
        fullName = user.fullName
        phone = user.phone ?? ""
        school = user.school ?? ""
        city = user.city ?? ""
        grade = user.grade ?? 0
        bio = user.bio ?? ""
        interests = user.interests ?? []
        visibleToOrganizers = user.privacy?.visibleToOrganizers ?? true
        visibleToSchool = user.privacy?.visibleToSchool ?? true
    }

    func addInterest() {
        let trimmed = newInterest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lowered = trimmed.lowercased()
        if !interests.contains(where: { $0.lowercased() == lowered }) {
            interests.append(trimmed)
        }
        newInterest = ""
    }

    func removeInterest(_ interest: String) {
        interests.removeAll { $0 == interest }
    }

    var isValid: Bool {
        fullName.trimmingCharacters(in: .whitespaces).count >= 2
    }

    func save() async {
        state = .loading
        do {
            let body = UpdateProfileBody(
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                phone: phone.isEmpty ? nil : phone,
                school: school.isEmpty ? nil : school,
                city: city.isEmpty ? nil : city,
                grade: grade > 0 ? grade : nil,
                bio: bio.isEmpty ? nil : bio,
                interests: interests,
                privacy: PrivacySettingsBody(
                    visibleToOrganizers: visibleToOrganizers,
                    visibleToSchool: visibleToSchool
                )
            )
            let user: User = try await api.request(.updateProfile(body: body), responseType: User.self)
            state = .success(user)
            toast.showSuccess("Profile saved")
            onSaved?(user)
        } catch {
            state = .failure(error)
            toast.showError(error)
        }
    }
}
