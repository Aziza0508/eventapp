import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var appEnv: AppEnvironment
    @State private var showEditProfile = false
    @State private var showNotifications = false
    @State private var showOrganizerApprovals = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.lg) {
                    headerCard

                    if let user = auth.currentUser, let interests = user.interests, !interests.isEmpty {
                        interestsSection(interests: interests)
                    }

                    if let user = auth.currentUser {
                        detailsSection(user: user)
                    }

                    if let user = auth.currentUser, let privacy = user.privacy {
                        privacySection(privacy: privacy)
                    }

                    settingsSection

                    #if DEBUG
                    devSection
                    #endif

                    signOutButton
                }
                .padding(.bottom, AppTheme.Spacing.xxl)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showEditProfile) {
                if let user = auth.currentUser {
                    EditProfileView(user: user) { updatedUser in
                        auth.updateCurrentUser(updatedUser)
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showOrganizerApprovals) {
                AdminOrganizerApprovalsView()
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            VStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 108, height: 108)
                    Circle()
                        .fill(.white.opacity(0.28))
                        .frame(width: 94, height: 94)
                    Text(initials)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                }

                if let user = auth.currentUser {
                    VStack(spacing: 2) {
                        Text(user.fullName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.80))
                    }

                    HStack(spacing: 6) {
                        roleChip(text: user.role.rawValue.capitalized, icon: roleIcon(user.role))
                        if let city = user.city, !city.isEmpty {
                            roleChip(text: city, icon: "mappin.and.ellipse")
                        }
                        if let grade = user.grade, grade > 0 {
                            roleChip(text: "Grade \(grade)", icon: "graduationcap")
                        }
                    }

                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                    }
                }

                Button { showEditProfile = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Edit profile")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(Capsule())
                    .softShadow()
                }
                .padding(.top, AppTheme.Spacing.xs)
            }
            .padding(.top, 64)
            .padding(.bottom, AppTheme.Spacing.lg)
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.heroGradient)
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 0,
                    bottomLeading: AppTheme.Radius.xxl,
                    bottomTrailing: AppTheme.Radius.xxl,
                    topTrailing: 0
                ),
                style: .continuous
            )
        )
        .ignoresSafeArea(edges: .top)
    }

    private func roleChip(text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.20))
        .clipShape(Capsule())
    }

    private func roleIcon(_ role: UserRole) -> String {
        switch role {
        case .student:   return "graduationcap.fill"
        case .organizer: return "person.badge.key.fill"
        case .admin:     return "shield.lefthalf.filled"
        }
    }

    // MARK: - Interests

    private func interestsSection(interests: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(
                title: "Interests",
                subtitle: "Topics you follow"
            )
            .padding(.horizontal, AppTheme.Spacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(interests, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.primary.opacity(0.10))
                            .foregroundStyle(AppTheme.primary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
            }
        }
    }

    // MARK: - Details

    private func detailsSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "About you")
                .padding(.horizontal, AppTheme.Spacing.xl)

            VStack(spacing: 0) {
                if let phone = user.phone, !phone.isEmpty {
                    detailRow(icon: "phone.fill", label: "Phone", value: phone, tint: AppTheme.secondary)
                    Divider().padding(.leading, 64)
                }
                if let city = user.city, !city.isEmpty {
                    detailRow(icon: "mappin.and.ellipse", label: "City", value: city, tint: AppTheme.primary)
                    Divider().padding(.leading, 64)
                }
                if let school = user.school, !school.isEmpty {
                    detailRow(icon: "building.columns.fill", label: "School", value: school, tint: AppTheme.primary)
                    Divider().padding(.leading, 64)
                }
                if let grade = user.grade, grade > 0 {
                    detailRow(icon: "graduationcap.fill", label: "Grade", value: "\(grade)", tint: AppTheme.warning)
                }
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .softShadow()
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }

    // MARK: - Privacy

    private func privacySection(privacy: PrivacySettings) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Privacy")
                .padding(.horizontal, AppTheme.Spacing.xl)

            VStack(spacing: 0) {
                privacyRow(icon: "eye.fill",
                           label: "Visible to organizers",
                           isOn: privacy.visibleToOrganizers)
                Divider().padding(.leading, 64)
                privacyRow(icon: "building.columns.fill",
                           label: "Visible to school",
                           isOn: privacy.visibleToSchool)
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .softShadow()
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }

    private func privacyRow(icon: String, label: String, isOn: Bool) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            iconTile(icon: icon, tint: AppTheme.secondary)
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(isOn ? "On" : "Off")
                .font(.caption.weight(.bold))
                .foregroundStyle(isOn ? AppTheme.success : AppTheme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((isOn ? AppTheme.success : AppTheme.textTertiary).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    // MARK: - Settings

    @AppStorage("biometricEnabled") private var biometricEnabled = false

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Settings")
                .padding(.horizontal, AppTheme.Spacing.xl)

            VStack(spacing: 0) {
                settingsRow(icon: "bell.fill", label: "Notifications") {
                    showNotifications = true
                }
                Divider().padding(.leading, 64)
                settingsRow(icon: "pencil", label: "Edit profile") {
                    showEditProfile = true
                }
                if auth.role == .admin {
                    Divider().padding(.leading, 64)
                    settingsRow(icon: "checkmark.shield.fill", label: "Organizer approvals") {
                        showOrganizerApprovals = true
                    }
                }
                if auth.canUseBiometrics {
                    Divider().padding(.leading, 64)
                    HStack(spacing: AppTheme.Spacing.md) {
                        iconTile(icon: "faceid", tint: AppTheme.primary)
                        Text("Face ID lock")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Toggle("", isOn: $biometricEnabled)
                            .labelsHidden()
                            .tint(AppTheme.primary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                }
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .softShadow()
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }

    private func settingsRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                iconTile(icon: icon, tint: AppTheme.primary)
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    private func detailRow(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            iconTile(icon: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private func iconTile(icon: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.12))
                .frame(width: 36, height: 36)
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button(role: .destructive) {
            auth.logout()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign out")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(AppTheme.error)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.error.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.full, style: .continuous))
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.md)
    }

    // MARK: - Dev section (DEBUG only)

    #if DEBUG
    private var devSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Developer")
                .padding(.horizontal, AppTheme.Spacing.xl)

            VStack(spacing: 0) {
                HStack(spacing: AppTheme.Spacing.md) {
                    iconTile(icon: "ladybug.fill", tint: AppTheme.warning)
                    Text("Data source")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Picker("Data source", selection: Binding(
                        get: { appEnv.dataMode },
                        set: { newMode in
                            appEnv.dataMode = newMode
                            if newMode == .mock {
                                auth.useMockSession()
                            } else {
                                auth.logout()
                            }
                        }
                    )) {
                        ForEach(DataMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)

                Divider().padding(.leading, 64)

                HStack(spacing: AppTheme.Spacing.md) {
                    iconTile(icon: "server.rack", tint: AppTheme.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Picker("Server", selection: $appEnv.serverEnvironment) {
                            ForEach(ServerEnvironment.allCases) { env in
                                Text(env.rawValue).tag(env)
                            }
                        }
                        .pickerStyle(.menu)
                        Text(appEnv.baseURL.absoluteString)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .softShadow()
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }
    #endif

    // MARK: - Helpers

    private var initials: String {
        guard let user = auth.currentUser else { return "?" }
        let parts = user.fullName.components(separatedBy: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last  = parts.count > 1 ? (parts.last?.first.map(String.init) ?? "") : ""
        return (first + last).uppercased()
    }
}

@MainActor
final class AdminOrganizerApprovalsViewModel: ObservableObject {
    @Published var state: Loadable<[User]> = .idle
    @Published var processingID: Int?

    let toast = ToastPresenter()

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load() async {
        state = .loading
        do {
            let organizers: [User] = try await api.request(
                .pendingOrganizers,
                responseType: [User].self
            )
            state = .success(organizers)
        } catch {
            state = .failure(error)
        }
    }

    func approve(userID: Int) async {
        await moderate(
            userID: userID,
            endpoint: .approveOrganizer(id: userID),
            successMessage: "Organizer approved"
        )
    }

    func reject(userID: Int) async {
        await moderate(
            userID: userID,
            endpoint: .rejectOrganizer(id: userID),
            successMessage: "Organizer rejected"
        )
    }

    private func moderate(userID: Int, endpoint: Endpoint, successMessage: String) async {
        processingID = userID
        defer { processingID = nil }

        do {
            let updated: User = try await api.request(endpoint, responseType: User.self)
            removeUser(updated.id)
            toast.showSuccess(successMessage)
        } catch {
            toast.showError(error)
        }
    }

    private func removeUser(_ userID: Int) {
        guard case .success(let users) = state else { return }
        state = .success(users.filter { $0.id != userID })
    }
}

struct AdminOrganizerApprovalsView: View {
    @StateObject private var vm = AdminOrganizerApprovalsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .idle where vm.state.value == nil,
                     .loading where vm.state.value == nil:
                    ProgressView()

                case .failure(let error):
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: "Failed to load requests",
                        subtitle: error.localizedDescription,
                        actionTitle: "Retry"
                    ) { Task { await vm.load() } }

                case .success(let organizers):
                    if organizers.isEmpty {
                        emptyState
                    } else {
                        organizerList(organizers)
                    }

                default:
                    if let organizers = vm.state.value, !organizers.isEmpty {
                        organizerList(organizers)
                    } else {
                        emptyState
                    }
                }
            }
            .navigationTitle("Approvals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
        .toastOverlay(vm.toast)
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "checkmark.shield",
            title: "No pending organizers",
            subtitle: "New organizer applications will show up here."
        )
    }

    private func organizerList(_ organizers: [User]) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                ForEach(organizers) { organizer in
                    OrganizerApprovalCard(
                        organizer: organizer,
                        isProcessing: vm.processingID == organizer.id,
                        onApprove: { Task { await vm.approve(userID: organizer.id) } },
                        onReject: { Task { await vm.reject(userID: organizer.id) } }
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.md)
        }
        .background(AppTheme.background)
    }
}

private struct OrganizerApprovalCard: View {
    let organizer: User
    let isProcessing: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "person.badge.key.fill")
                        .foregroundStyle(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(organizer.fullName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(organizer.email)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    if let city = organizer.city, !city.isEmpty {
                        Label(city, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }

                    if let school = organizer.school, !school.isEmpty {
                        Label(school, systemImage: "building.columns.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }

                Spacer()
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Button(action: onReject) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "xmark")
                        }
                        Text("Reject")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.error)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.error.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.full, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)

                Button(action: onApprove) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                        }
                        Text("Approve")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.full, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
        }
        .padding(AppTheme.Spacing.md)
        .surfaceCard()
    }
}
