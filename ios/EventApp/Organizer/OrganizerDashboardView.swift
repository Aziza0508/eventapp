import SwiftUI

@MainActor
final class OrganizerDashboardViewModel: ObservableObject {
    @Published var state: Loadable<[Event]> = .idle
    var organizerID: Int = 0

    let toast = ToastPresenter()
    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load() async {
        guard organizerID > 0 else { return }
        state = .loading
        do {
            let response: EventListResponse = try await api.request(
                .events(limit: 100),
                responseType: EventListResponse.self
            )
            let mine = response.data.filter { $0.organizerID == organizerID }
            state = .success(mine)
        } catch {
            state = .failure(error)
        }
    }

    func deleteEvent(id: Int) async {
        do {
            try await api.requestVoid(.deleteEvent(id: id))
            if var list = state.value {
                list.removeAll { $0.id == id }
                state = .success(list)
            }
            toast.showSuccess("Event deleted")
        } catch {
            toast.showError(error)
        }
    }
}

struct OrganizerDashboardView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var vm = OrganizerDashboardViewModel()
    @State private var showCreate = false
    @State private var showReports = false
    @State private var editingEvent: Event? = nil
    @State private var selectedSegment = 0
    @State private var deleteTarget: Event? = nil

    private var events: [Event] { vm.state.value ?? [] }

    private var upcomingEvents: [Event] {
        events.filter { $0.dateStart >= Date() }.sorted { $0.dateStart < $1.dateStart }
    }
    private var pastEvents: [Event] {
        events.filter { $0.dateStart < Date() }.sorted { $0.dateStart > $1.dateStart }
    }
    private var displayed: [Event] {
        selectedSegment == 0 ? upcomingEvents : pastEvents
    }

    private var totalCapacity: Int {
        events.reduce(0) { $0 + $1.capacity }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.lg) {
                    header

                    statsRow

                    primaryActions

                    segmentControl

                    content
                }
                .padding(.bottom, AppTheme.Spacing.xl)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreate) {
                EventFormView(mode: .create) { _ in Task { await vm.load() } }
            }
            .sheet(item: $editingEvent) { event in
                EventFormView(mode: .edit(event)) { _ in Task { await vm.load() } }
            }
            .sheet(isPresented: $showReports) {
                OrganizerReportsView()
            }
            .confirmationDialog(
                "Delete Event",
                isPresented: Binding(
                    get: { deleteTarget != nil },
                    set: { if !$0 { deleteTarget = nil } }
                ),
                titleVisibility: .visible,
                presenting: deleteTarget
            ) { event in
                Button("Delete \"\(event.title)\"", role: .destructive) {
                    Task { await vm.deleteEvent(id: event.id) }
                }
            } message: { event in
                Text("This will permanently remove the event and all its registrations. This action cannot be undone.")
            }
            .task {
                vm.organizerID = auth.currentUser?.id ?? 0
                await vm.load()
            }
            .toastOverlay(vm.toast)
            .refreshable { await vm.load() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dashboard")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(firstName)
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
            Button { showReports = true } label: {
                Image(systemName: "chart.bar.xaxis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.primary.opacity(0.10))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.lg)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            DashboardStatCard(
                icon: "calendar.badge.checkmark",
                label: "Upcoming",
                value: "\(upcomingEvents.count)",
                tint: AppTheme.primary
            )
            DashboardStatCard(
                icon: "person.2.fill",
                label: "Total seats",
                value: "\(totalCapacity)",
                tint: AppTheme.secondary
            )
            DashboardStatCard(
                icon: "clock.fill",
                label: "Past",
                value: "\(pastEvents.count)",
                tint: AppTheme.warning
            )
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

    // MARK: - Primary actions

    private var primaryActions: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Button { showCreate = true } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New event")
                            .font(.subheadline.weight(.bold))
                        Text("Publish to discovery")
                            .font(.caption)
                            .opacity(0.9)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
                .cardShadow()
            }

            Button { showReports = true } label: {
                VStack(spacing: 2) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                    Text("Reports")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(AppTheme.primary)
                .frame(width: 88, height: 80)
                .background(AppTheme.surfaceTinted)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

    // MARK: - Segment

    private var segmentControl: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Your events")
                .padding(.horizontal, AppTheme.Spacing.xl)

            PillSegmentControl(
                segments: ["Upcoming (\(upcomingEvents.count))", "Past (\(pastEvents.count))"],
                selected: $selectedSegment
            )
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle where vm.state.value == nil,
             .loading where vm.state.value == nil:
            VStack(spacing: AppTheme.Spacing.md) {
                ForEach(0..<2, id: \.self) { _ in SkeletonCard() }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)

        case .failure(let error):
            EmptyStateView(
                icon: "exclamationmark.triangle",
                title: "Failed to load",
                subtitle: error.localizedDescription,
                actionTitle: "Retry"
            ) { Task { await vm.load() } }

        default:
            if displayed.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: AppTheme.Spacing.md) {
                    ForEach(displayed) { event in
                        OrganizerEventCard(
                            event: event,
                            onEdit: { editingEvent = event },
                            onDelete: { deleteTarget = event }
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: selectedSegment == 0 ? "calendar.badge.plus" : "clock")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
            }
            Text(selectedSegment == 0 ? "No upcoming events" : "No past events")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(selectedSegment == 0
                 ? "Spin up your first event and students can apply in seconds."
                 : "Your completed events will show up here.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)

            if selectedSegment == 0 {
                PrimaryButton("Create event") { showCreate = true }
                    .frame(width: 220)
                    .padding(.top, AppTheme.Spacing.sm)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var firstName: String {
        auth.currentUser?.fullName.components(separatedBy: " ").first ?? "Organizer"
    }
}

// MARK: - Event conformance (kept from original)

extension Event: Equatable {
    static func == (lhs: Event, rhs: Event) -> Bool { lhs.id == rhs.id }
}
extension Event: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Organizer Event Card

private struct OrganizerEventCard: View {
    let event: Event
    let onEdit: () -> Void
    let onDelete: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy · HH:mm"; return f
    }()

    private var isPast: Bool { event.dateStart < Date() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Poster / gradient header
            ZStack(alignment: .topLeading) {
                posterBackground

                AppTheme.heroOverlay
                    .opacity(0.55)

                // Chips overlay
                HStack(spacing: 6) {
                    if let cat = event.category, !cat.isEmpty {
                        Text(cat)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.25))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    if isPast {
                        Text("Past")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.35))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if let fmt = event.format {
                        Text(fmt.displayName)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.25))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(AppTheme.Spacing.sm)
            }
            .frame(height: 120)
            .clipped()

            // Content
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: AppTheme.Spacing.md) {
                    Label(Self.dateFormatter.string(from: event.dateStart), systemImage: "calendar")
                    if let city = event.city, !city.isEmpty {
                        Label(city, systemImage: "mappin")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: AppTheme.Spacing.sm) {
                    MetaChip(
                        text: event.capacity > 0 ? "\(event.capacity) seats" : "Unlimited",
                        systemImage: event.capacity > 0 ? "person.2.fill" : "infinity",
                        tint: AppTheme.primary
                    )
                    MetaChip(
                        text: event.pricingBadgeText,
                        tint: event.isFreeEvent ? AppTheme.success : AppTheme.warning
                    )
                }
                .padding(.top, 2)

                Divider().padding(.top, AppTheme.Spacing.sm)

                // Actions row
                HStack(spacing: AppTheme.Spacing.sm) {
                    NavigationLink(destination: EventDetailView(event: event)) {
                        Label("Open", systemImage: "arrow.right.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: ParticipantsView(event: event)) {
                        Label("Participants", systemImage: "person.2")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondary)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(AppTheme.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.error)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.error.opacity(0.10))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .softShadow()
        .opacity(isPast ? 0.78 : 1.0)
    }

    @ViewBuilder
    private var posterBackground: some View {
        if let poster = event.posterURL, !poster.isEmpty, let url = URL(string: poster) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                default: AppTheme.heroGradient
                }
            }
        } else {
            AppTheme.heroGradient
        }
    }
}
