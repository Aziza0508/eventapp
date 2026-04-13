import SwiftUI

struct EventListView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var vm = EventListViewModel()

    // Categories rendered as icon tiles at the top of the Discover feed.
    private struct CategoryEntry: Identifiable {
        let id: String
        let title: String
        let icon: String
        let tint: Color
        let filter: String   // passed to EventListViewModel.filterCategory
    }

    private let categories: [CategoryEntry] = [
        .init(id: "all",  title: "All",         icon: "sparkles",                    tint: AppTheme.primary,   filter: ""),
        .init(id: "rob",  title: "Robotics",    icon: "gearshape.2.fill",            tint: AppTheme.primary,   filter: "Robotics"),
        .init(id: "prog", title: "Programming", icon: "chevron.left.forwardslash.chevron.right", tint: AppTheme.secondary, filter: "Programming"),
        .init(id: "ai",   title: "AI / ML",     icon: "brain.head.profile",          tint: Color(red: 0.32, green: 0.56, blue: 0.78), filter: "AI/ML"),
        .init(id: "hack", title: "Hackathon",   icon: "bolt.fill",                   tint: AppTheme.warning,   filter: "Hackathon"),
        .init(id: "iot",  title: "IoT",         icon: "sensor.tag.radiowaves.forward.fill", tint: AppTheme.secondary, filter: "IoT"),
        .init(id: "ws",   title: "Workshops",   icon: "hammer.fill",                 tint: Color(red: 0.90, green: 0.55, blue: 0.27), filter: "Workshop"),
        .init(id: "comp", title: "Olympiad",    icon: "trophy.fill",                 tint: Color(red: 0.82, green: 0.62, blue: 0.14), filter: "Competition"),
    ]

    private var activeCategoryID: String {
        if vm.filterCategory.isEmpty { return "all" }
        return categories.first { $0.filter == vm.filterCategory }?.id ?? "all"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.lg) {
                    headerSection

                    searchSection

                    if vm.isOffline {
                        offlineBanner
                    }

                    categorySection

                    if let list = vm.state.value, !list.isEmpty {
                        featuredSection(list: list)

                        upcomingSection(list: list)
                    } else {
                        switch vm.state {
                        case .idle, .loading:
                            loadingSkeletons

                        case .failure(let error):
                            errorState(error: error)

                        case .success:
                            emptyState
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.bottom, AppTheme.Spacing.xl)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable { await vm.loadInitial() }
            .task { await vm.loadInitial() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(firstName)
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
            HStack(spacing: AppTheme.Spacing.sm) {
                if let city = auth.currentUser?.city, !city.isEmpty {
                    Label(city, systemImage: "mappin.and.ellipse")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(AppTheme.primary.opacity(0.10))
                        .clipShape(Capsule())
                }
                avatarChip
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.lg)
    }

    private var avatarChip: some View {
        ZStack {
            Circle()
                .fill(AppTheme.primaryGradient)
                .frame(width: 40, height: 40)
            Text(initials)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
        .softShadow()
    }

    // MARK: - Search

    private var searchSection: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            SearchField(
                text: $vm.searchQuery,
                placeholder: "Search events, tags, topics…"
            ) { Task { await vm.applyFilters() } }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

    // MARK: - Categories

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Browse by topic")
                .padding(.horizontal, AppTheme.Spacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(categories) { c in
                        CategoryTile(
                            title: c.title,
                            systemImage: c.icon,
                            tint: c.tint,
                            isSelected: activeCategoryID == c.id
                        ) {
                            vm.filterCategory = c.filter
                            Task { await vm.applyFilters() }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
            }
        }
    }

    // MARK: - Featured carousel (upcoming events with largest visual appeal)

    private func featuredSection(list: [Event]) -> some View {
        let featured = Array(list
            .filter { $0.dateStart >= Date() }
            .prefix(5))

        return Group {
            if !featured.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionHeader(
                        title: "Featured",
                        subtitle: "Hand-picked for you this week"
                    )
                    .padding(.horizontal, AppTheme.Spacing.xl)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.Spacing.md) {
                            ForEach(featured) { event in
                                NavigationLink(destination: EventDetailView(event: event)) {
                                    HeroEventCard(event: event)
                                        .frame(width: 320)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.xl)
                    }
                }
            }
        }
    }

    // MARK: - Upcoming list

    private func upcomingSection(list: [Event]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(
                title: "Upcoming",
                subtitle: "\(vm.totalCount) events available"
            )
            .padding(.horizontal, AppTheme.Spacing.xl)

            LazyVStack(spacing: AppTheme.Spacing.md) {
                ForEach(list) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        EventCard(event: event)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if event.id == list.last?.id {
                            Task { await vm.loadMore() }
                        }
                    }
                }
                if vm.state.isLoading {
                    ProgressView()
                        .tint(AppTheme.primary)
                        .padding(.vertical, AppTheme.Spacing.md)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }

    // MARK: - States

    private var loadingSkeletons: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonCard()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

    private func errorState(error: Error) -> some View {
        EmptyStateView(
            icon: "wifi.slash",
            title: "Couldn't load events",
            subtitle: error.localizedDescription,
            actionTitle: "Try again"
        ) { Task { await vm.loadInitial() } }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "sparkles",
            title: "Nothing here yet",
            subtitle: "Try a different category or clear your filters to see more events.",
            actionTitle: "Clear filters"
        ) {
            vm.filterCategory = ""
            vm.searchQuery = ""
            Task { await vm.applyFilters() }
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: "wifi.slash")
            Text("Showing cached events — reconnect to refresh.")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(AppTheme.warning)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.warning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

    // MARK: - Helpers

    private var firstName: String {
        auth.currentUser?.fullName.components(separatedBy: " ").first ?? "Explorer"
    }

    private var initials: String {
        guard let user = auth.currentUser else { return "E" }
        let parts = user.fullName.components(separatedBy: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? (parts.last?.first.map(String.init) ?? "") : ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "E" : result
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning,"
        case 12..<18: return "Good afternoon,"
        case 18..<22: return "Good evening,"
        default:      return "Hello,"
        }
    }
}
