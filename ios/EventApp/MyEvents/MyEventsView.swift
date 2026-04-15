import SwiftUI
import CoreImage.CIFilterBuiltins

struct MyEventsView: View {
    @StateObject private var vm = MyEventsViewModel()
    @State private var selectedSegment = 0
    @State private var ticketRegistration: Registration?

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
                                        NavigationLink(destination: EventDetailView(event: event, existingRegistration: reg)) {
                                            RegistrationCard(
                                                registration: reg,
                                                event: event,
                                                onShowTicket: (reg.status == .approved || reg.status == .checked_in) ? {
                                                    ticketRegistration = reg
                                                } : nil,
                                                onCancel: reg.status.isCancellableByUser ? {
                                                    Task<Void, Never> { await vm.cancel(regID: reg.id) }
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
            .sheet(item: $ticketRegistration) { reg in
                if let event = reg.event {
                    TicketView(registration: reg, event: event)
                }
            }
            .toastOverlay(vm.toast)
        }
    }

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
                StatPill(icon: "paperplane.fill", label: "Applied", value: "\(registrations.count)")
                StatPill(icon: "checkmark.seal.fill", label: "Approved", value: "\(approvedCount)")
                StatPill(icon: "trophy.fill", label: "Completed", value: "\(completedCount)")
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous))
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.lg)
    }

    private var segmentControl: some View {
        PillSegmentControl(
            segments: ["Upcoming (\(upcoming.count))", "Past (\(past.count))"],
            selected: $selectedSegment
        )
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

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
            Text(selectedSegment == 0 ? "No upcoming events yet" : "No past events")
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

private struct RegistrationCard: View {
    let registration: Registration
    let event: Event
    let onShowTicket: (() -> Void)?
    let onCancel: (() -> Void)?

    private static let appliedFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    private static let eventDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d · HH:mm"; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
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
                        Label(Self.eventDateFormatter.string(from: event.dateStart), systemImage: "calendar")
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

            HStack {
                Text("Applied \(Self.appliedFormatter.string(from: registration.createdAt))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                if let onShowTicket, registration.status == .approved || registration.status == .checked_in {
                    Button(action: onShowTicket) {
                        HStack(spacing: 4) {
                            Image(systemName: "qrcode")
                            Text("View ticket")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                    }
                    .buttonStyle(.plain)
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
            RoundedRectangle(cornerRadius: 3)
                .fill(stripeColor)
                .frame(width: 5)
                .padding(.vertical, AppTheme.Spacing.md)
        }
    }

    @ViewBuilder
    private var posterThumb: some View {
        if let poster = event.posterURL, !poster.isEmpty, let url = URL(string: poster) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    AppTheme.primaryGradient
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
        case .pending: return "Awaiting decision"
        case .waitlisted: return "On the waitlist"
        case .rejected: return "Not approved"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        default: return ""
        }
    }

    private var stripeColor: Color {
        switch registration.status {
        case .pending: return AppTheme.warning
        case .approved: return AppTheme.success
        case .rejected: return AppTheme.error
        case .waitlisted: return AppTheme.secondary
        case .checked_in: return AppTheme.primaryDark
        case .completed: return AppTheme.success
        case .cancelled: return AppTheme.textTertiary
        }
    }
}

@MainActor
final class TicketViewModel: ObservableObject {
    @Published var state: Loadable<String> = .idle

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load(registrationID: Int) async {
        state = .loading
        do {
            let payload: [String: String] = try await api.request(
                .getQRPayload(regID: registrationID),
                responseType: [String: String].self
            )
            guard let qr = payload["qr_payload"] else {
                throw NetworkError.decoding(NSError(
                    domain: "",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "QR payload missing from response"]
                ))
            }
            state = .success(qr)
        } catch {
            state = .failure(error)
        }
    }
}

private struct TicketView: View {
    let registration: Registration
    let event: Event

    @StateObject private var vm = TicketViewModel()
    @Environment(\.dismiss) private var dismiss
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(event.title)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(registration.status.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusTint)
                }

                Group {
                    switch vm.state {
                    case .idle, .loading:
                        ProgressView("Loading ticket...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .failure(let error):
                        EmptyStateView(
                            icon: "qrcode",
                            title: "Couldn't load ticket",
                            subtitle: error.localizedDescription,
                            actionTitle: "Try again"
                        ) {
                            Task { await vm.load(registrationID: registration.id) }
                        }

                    case .success(let payload):
                        VStack(spacing: AppTheme.Spacing.md) {
                            if let image = qrImage(from: payload) {
                                Image(uiImage: image)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 240, height: 240)
                                    .padding()
                                    .background(AppTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
                                    .softShadow()
                            }

                            Text("Show this QR code to the organizer at check-in.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppTheme.Spacing.xl)
                        }
                    }
                }

                Spacer()
            }
            .padding(AppTheme.Spacing.xl)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Your Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await vm.load(registrationID: registration.id)
            }
        }
    }

    private var statusTint: Color {
        switch registration.status {
        case .approved: return AppTheme.success
        case .checked_in: return AppTheme.primary
        default: return AppTheme.textSecondary
        }
    }

    private func qrImage(from payload: String) -> UIImage? {
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
