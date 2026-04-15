import SwiftUI

struct MyEventsView: View {
    @StateObject private var vm = MyEventsViewModel()
    @State private var selectedSegment = 0

    private var registrations: [Registration] { vm.state.value ?? [] }

    private var upcoming: [Registration] {
        registrations.filter {
            ($0.event?.dateStart ?? .distantPast) >= Date() &&
            $0.status != .cancelled
        }
    }
    private var past: [Registration] {
        registrations.filter {
            ($0.event?.dateStart ?? .distantFuture) < Date() ||
            $0.status == .cancelled
        }
    }
    private var displayed: [Registration] {
        selectedSegment == 0 ? upcoming : past
    }

    private var approvedCount: Int {
        registrations.filter { $0.status == .approved || $0.status == .checked_in }.count
    }
    private var completedCount: Int {
        registrations.filter { $0.status == .completed || $0.status == .checked_in }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.lg) {
                    journeyHeader

                    segmentControl

                    switch vm.state {
                    case .idle where vm.state.value == nil,
                         .loading where vm.state.value == nil:
                        VStack(spacing: AppTheme.Spacing.md) {
                            ForEach(0..<3, id: \.self) { _ in SkeletonCard() }
                        }
                        .padding(.horizontal, AppTheme.Spacing.xl)

                    case .failure(let error):
                        EmptyStateView(
                            icon: "exclamationmark.triangle",
                            title: "Couldn't load your events",
                            subtitle: error.localizedDescription,
                            actionTitle: "Retry"
                        ) { Task { await vm.load() } }
                            .padding(.top, AppTheme.Spacing.xl)

                    default:
                        if displayed.isEmpty {
                            emptyStateCard
                        } else {
                            LazyVStack(spacing: AppTheme.Spacing.md) {
                                ForEach(displayed) { reg in
                                    if let event = reg.event {
                                        NavigationLink(destination:
                                            EventDetailView(event: event, existingRegistration: reg)
                                        ) {
                                            RegistrationCard(
                                                registration: reg,
                                                event: event,
                                                onCancel: reg.status.isCancellableByUser ? {
                                                    Task { await vm.cancel(regID: reg.id) }
                                                } : nil
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.xl)
                        }
                    }

                    Spacer(minLength: 60)
                }
                .padding(.bottom, AppTheme.Spacing.xl)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .toastOverlay(vm.toast)
        }
    }

    // MARK: - Journey header

    private var journeyHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("My journey")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Track every event you applied to")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                StatPill(icon: "paperplane.fill",
                         label: "Applied",
                         value: "\(registrations.count)")
                StatPill(icon: "checkmark.seal.fill",
                         label: "Approved",
                         value: "\(approvedCount)")
                StatPill(icon: "trophy.fill",
                         label: "Completed",
                         value: "\(completedCount)")
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous))
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.lg)
    }

    // MARK: - Segment

    private var segmentControl: some View {
        PillSegmentControl(
            segments: ["Upcoming (\(upcoming.count))", "Past (\(past.count))"],
            selected: $selectedSegment
        )
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

    // MARK: - Empty state

    private var emptyStateCard: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.10))
                    .frame(width: 100, height: 100)
                Image(systemName: selectedSegment == 0 ? "ticket" : "clock")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
            }
            Text(selectedSegment == 0
                 ? "No upcoming events yet"
                 : "No past events")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(selectedSegment == 0
                 ? "Head to Discover to find workshops, hackathons, and olympiads that match your interests."
                 : "Your event history will show up here once you've attended your first event.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
        }
        .padding(.vertical, AppTheme.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - RegistrationCard

private struct RegistrationCard: View {
    let registration: Registration
    let event: Event
    let onCancel: (() -> Void)?

    private static let appliedFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    private static let eventDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d · HH:mm"; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Header row with poster thumb
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                posterThumb
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text(event.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                        Spacer()
                        StatusBadge(status: registration.status)
                    }

                    HStack(spacing: AppTheme.Spacing.sm) {
                        Label(Self.eventDateFormatter.string(from: event.dateStart),
                              systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        if let city = event.city, !city.isEmpty {
                            Label(city, systemImage: "mappin")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Divider()

            // Footer: applied date + next action
            HStack {
                Text("Applied \(Self.appliedFormatter.string(from: registration.createdAt))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                if registration.status == .approved || registration.status == .checked_in {
                    HStack(spacing: 4) {
                        Image(systemName: "qrcode")
                        Text("View ticket")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                } else if let onCancel {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.error)
                    }
                } else {
                    Text(nextActionHint)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .softShadow()
        .overlay(alignment: .leading) {
            // Status stripe
            RoundedRectangle(cornerRadius: 3)
                .fill(stripeColor)
                .frame(width: 5)
                .padding(.vertical, AppTheme.Spacing.md)
                .padding(.leading, 0)
        }
    }

    @ViewBuilder
    private var posterThumb: some View {
        if let poster = event.posterURL, !poster.isEmpty, let url = URL(string: poster) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                default: AppTheme.primaryGradient
                }
            }
        } else {
            ZStack {
                AppTheme.primaryGradient
                Image(systemName: "sparkles")
                    .foregroundStyle(.white.opacity(0.6))
                    .font(.title3)
            }
        }
    }

    private var nextActionHint: String {
        switch registration.status {
        case .pending:    return "Awaiting decision"
        case .waitlisted: return "On the waitlist"
        case .rejected:   return "Not approved"
        case .completed:  return "Completed"
        case .cancelled:  return "Cancelled"
        default:          return ""
        }
    }

    private var stripeColor: Color {
        switch registration.status {
        case .pending:    return AppTheme.warning
        case .approved:   return AppTheme.success
        case .rejected:   return AppTheme.error
        case .waitlisted: return AppTheme.secondary
        case .checked_in: return AppTheme.primaryDark
        case .completed:  return AppTheme.success
        case .cancelled:  return AppTheme.textTertiary
        }
    }
}
