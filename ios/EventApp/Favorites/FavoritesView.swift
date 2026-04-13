import SwiftUI

// MARK: - ViewModel

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var state: Loadable<[Favorite]> = .idle

    let toast = ToastPresenter()
    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load() async {
        state = .loading
        do {
            let favs: [Favorite] = try await api.request(
                .myFavorites,
                responseType: [Favorite].self
            )
            state = .success(favs)
        } catch {
            state = .failure(error)
        }
    }

    func removeFavorite(eventID: Int) async {
        do {
            try await api.requestVoid(.removeFavorite(eventID: eventID))
            // Remove from local list immediately
            if var list = state.value {
                list.removeAll { $0.eventID == eventID }
                state = .success(list)
            }
            toast.showSuccess("Removed from saved")
        } catch {
            toast.showError(error)
        }
    }
}

// MARK: - View

struct FavoritesView: View {
    @StateObject private var vm = FavoritesViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Saved Events")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Events you bookmarked")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.md)

                // Content
                switch vm.state {
                case .idle, .loading where vm.state.value == nil:
                    Spacer()
                    ProgressView()
                    Spacer()

                case .failure(let error):
                    Spacer()
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: "Failed to load",
                        subtitle: error.localizedDescription,
                        actionTitle: "Retry"
                    ) { Task { await vm.load() } }
                    Spacer()

                default:
                    let favorites = vm.state.value ?? []
                    if favorites.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "bookmark",
                            title: "No saved events",
                            subtitle: "Bookmark events from the Discover tab to see them here."
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppTheme.Spacing.md) {
                                ForEach(favorites) { fav in
                                    if let event = fav.event {
                                        NavigationLink(destination: EventDetailView(event: event)) {
                                            FavoriteCard(event: event) {
                                                Task { await vm.removeFavorite(eventID: event.id) }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.xl)
                            .padding(.bottom, AppTheme.Spacing.xl)
                        }
                        .refreshable { await vm.load() }
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await vm.load() }
            .toastOverlay(vm.toast)
        }
    }
}

// MARK: - FavoriteCard

private struct FavoriteCard: View {
    let event: Event
    let onRemove: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            // Date box
            ZStack {
                AppTheme.primaryGradient
                VStack(spacing: 2) {
                    Text(Self.dateFormatter.string(from: event.dateStart).components(separatedBy: " ").first?.uppercased() ?? "")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(event.dateStart.formatted(.dateTime.day()))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 64)
            .frame(maxHeight: .infinity)
            .clipped()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                HStack {
                    if let cat = event.category {
                        CategoryBadge(text: cat)
                    }
                    Spacer()
                    Button { onRemove() } label: {
                        Image(systemName: "bookmark.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.primary)
                    }
                }

                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)

                if let org = event.organizer {
                    Text("by \(org.fullName)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                HStack(spacing: AppTheme.Spacing.md) {
                    if let city = event.city, !city.isEmpty {
                        Label(city, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Label(Self.dateFormatter.string(from: event.dateStart), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.md)
        }
        .frame(minHeight: 100)
        .surfaceCard(radius: AppTheme.Radius.lg)
        .clipped()
    }
}
