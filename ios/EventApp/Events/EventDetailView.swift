import SwiftUI

struct EventDetailView: View {
    let event: Event
    var existingRegistration: Registration? = nil

    @EnvironmentObject private var auth: AuthStore
    @StateObject private var vm = EventDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var calendarAdded = false
    @State private var calendarError: String?

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f
    }()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .none; return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private var displayEvent: Event {
        vm.detailedEvent ?? event
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection

                    contentColumn
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.top, AppTheme.Spacing.lg)
                }
            }

            topBar
        }
        .ignoresSafeArea(edges: .top)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom) {
            if !auth.isOrganizer {
                applyBar
                    .padding(AppTheme.Spacing.md)
                    .background(.regularMaterial)
            }
        }
        .task {
            vm.setExistingRegistration(existingRegistration)
            await vm.loadDetails(eventID: event.id)
        }
        .toastOverlay(vm.toast)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            Spacer()
            Button {
                Task { await vm.toggleFavorite(eventID: displayEvent.id) }
            } label: {
                Image(systemName: vm.isFavorite ? "bookmark.fill" : "bookmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(vm.isFavorite ? AppTheme.accent : .white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, 56)
        .zIndex(1)
    }

    // MARK: - Content column

    @ViewBuilder
    private var contentColumn: some View {
        statsStrip
            .padding(.bottom, AppTheme.Spacing.lg)

        if let org = displayEvent.organizer {
            organizerRow(org: org)
                .padding(.bottom, AppTheme.Spacing.lg)
        }

        if let tags = displayEvent.tags, !tags.isEmpty {
            tagsRow(tags: tags)
                .padding(.bottom, AppTheme.Spacing.md)
        }

        if let desc = displayEvent.description, !desc.isEmpty {
            aboutSection(description: desc)
                .padding(.bottom, AppTheme.Spacing.lg)
        }

        detailsCard
            .padding(.bottom, AppTheme.Spacing.lg)

        if let info = displayEvent.additionalInfo, !info.isEmpty {
            additionalSection(info: info)
                .padding(.bottom, AppTheme.Spacing.lg)
        }

        addToCalendarButton

        Spacer(minLength: 100)
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            posterBackground

            AppTheme.heroOverlay
                .frame(height: 340)

            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack(spacing: 6) {
                        if let cat = displayEvent.category, !cat.isEmpty {
                            Text(cat)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.25))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }

                        Text(displayEvent.isFreeEvent ? "Free" : "Paid")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(displayEvent.isFreeEvent ? AppTheme.accent.opacity(0.95) : AppTheme.warning.opacity(0.95))
                            .foregroundStyle(AppTheme.textPrimary)
                            .clipShape(Capsule())

                        if displayEvent.isPaidEvent, let price = displayEvent.price, price > 0 {
                            Text(String(format: "%.0f KZT", price))
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.22))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }

                        if let format = displayEvent.format {
                            Text(format.displayName)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.20))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }

                    Text(displayEvent.title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
            .frame(height: 340)
        }
        .frame(height: 340)
    }

    @ViewBuilder
    private var posterBackground: some View {
        if let poster = displayEvent.posterURL, !poster.isEmpty, let url = URL(string: poster) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                        .frame(height: 340)
                        .clipped()
                default:
                    Rectangle().fill(AppTheme.heroGradient).frame(height: 340)
                }
            }
        } else {
            Rectangle().fill(AppTheme.heroGradient).frame(height: 340)
        }
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            statPill(
                icon: "calendar",
                value: Self.fullDateFormatter.string(from: displayEvent.dateStart),
                label: Self.timeFormatter.string(from: displayEvent.dateStart)
            )

            if displayEvent.capacity > 0 {
                statPill(
                    icon: "person.2.fill",
                    value: seatInfo.value,
                    label: "of \(displayEvent.capacity) seats",
                    tint: seatInfo.tint
                )
            } else {
                statPill(
                    icon: "infinity",
                    value: "Open",
                    label: "no seat limit"
                )
            }
        }
    }

    private var seatInfo: (value: String, tint: Color) {
        if vm.detailedEvent == nil {
            return ("\(displayEvent.capacity) seats", AppTheme.primary)
        } else if vm.freeSeats == 0 {
            return ("Full", AppTheme.error)
        } else {
            return ("\(vm.freeSeats) left", AppTheme.primary)
        }
    }

    private func statPill(icon: String, value: String, label: String, tint: Color = AppTheme.primary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .softShadow()
    }

    // MARK: - Organizer row

    private func organizerRow(org: User) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 48, height: 48)
                Text(initials(from: org.fullName))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Organized by")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(org.fullName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let contact = displayEvent.organizerContact, !contact.isEmpty {
                    Text(contact)
                        .font(.caption)
                        .foregroundStyle(AppTheme.primary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let contact = displayEvent.organizerContact, !contact.isEmpty,
               let url = URL(string: "mailto:\(contact)") {
                Link(destination: url) {
                    Image(systemName: "envelope.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.primary.opacity(0.10))
                        .clipShape(Circle())
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.surfaceTinted)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
    }

    // MARK: - Tags

    private func tagsRow(tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.secondary.opacity(0.12))
                        .foregroundStyle(AppTheme.primaryDark)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - About

    private func aboutSection(description: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("About this event")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(description)
                .font(.body)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Details card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Event details")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.md)

            VStack(spacing: 0) {
                infoRow(
                    icon: "calendar",
                    label: "Date",
                    value: Self.dateFormatter.string(from: displayEvent.dateStart)
                )
                Divider().padding(.leading, 56)
                infoRow(
                    icon: "clock",
                    label: "Time",
                    value: Self.timeFormatter.string(from: displayEvent.dateStart)
                )

                if let city = displayEvent.city, !city.isEmpty {
                    Divider().padding(.leading, 56)
                    let loc = [city, displayEvent.address]
                        .compactMap { $0?.isEmpty == false ? $0 : nil }
                        .joined(separator: ", ")
                    infoRow(icon: "mappin.and.ellipse", label: "Location", value: loc)
                }

                if let deadline = displayEvent.regDeadline {
                    Divider().padding(.leading, 56)
                    infoRow(
                        icon: "exclamationmark.circle",
                        label: "Apply before",
                        value: Self.dateFormatter.string(from: deadline),
                        tint: AppTheme.warning
                    )
                }

                if let price = displayEvent.price, price > 0, displayEvent.isPaidEvent {
                    Divider().padding(.leading, 56)
                    infoRow(
                        icon: "creditcard.fill",
                        label: "Price",
                        value: String(format: "%.0f KZT", price),
                        tint: AppTheme.warning
                    )
                }

                if let end = displayEvent.dateEnd {
                    Divider().padding(.leading, 56)
                    infoRow(
                        icon: "flag.checkered",
                        label: "Ends",
                        value: Self.dateFormatter.string(from: end)
                    )
                }
            }
            .padding(.bottom, AppTheme.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .softShadow()
    }

    private func infoRow(icon: String, label: String, value: String, tint: Color = AppTheme.primary) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
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

    // MARK: - Additional info

    private func additionalSection(info: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppTheme.secondary)
                Text("Good to know")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Text(info)
                .font(.body)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceTinted)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
    }

    // MARK: - Add to Calendar

    private var addToCalendarButton: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if calendarAdded {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                    Text("Added to your calendar")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.success)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.success.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            } else {
                Button {
                    Task {
                        let location = [displayEvent.city, displayEvent.address]
                            .compactMap { $0?.isEmpty == false ? $0 : nil }
                            .joined(separator: ", ")
                        do {
                            try await CalendarHelper.shared.addToCalendar(
                                title: displayEvent.title,
                                startDate: displayEvent.dateStart,
                                endDate: displayEvent.dateEnd,
                                location: location.isEmpty ? nil : location,
                                notes: displayEvent.description
                            )
                            calendarAdded = true
                            calendarError = nil
                        } catch {
                            calendarError = error.localizedDescription
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                        Text("Add to Calendar")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                }
            }

            if let err = calendarError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(AppTheme.error)
            }
        }
    }

    // MARK: - Apply bar

    @ViewBuilder
    private var applyBar: some View {
        switch vm.applyState {
        case .idle:
            PrimaryButton("Apply to this event") {
                Task { await vm.apply(eventID: displayEvent.id) }
            }
        case .loading:
            PrimaryButton("Applying…", isLoading: true) { }
        case .success(let reg):
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: regStatusIcon(reg.status))
                    .font(.title3)
                    .foregroundStyle(statusColor(reg.status))
                VStack(alignment: .leading, spacing: 2) {
                    Text(reg.status.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(statusSubtitle(reg.status))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                StatusBadge(status: reg.status)
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .softShadow()
        case .failure(let error):
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(AppTheme.error)
                    .multilineTextAlignment(.center)
                PrimaryButton("Try again") {
                    Task { await vm.apply(eventID: displayEvent.id) }
                }
            }
        }
    }

    private func regStatusIcon(_ status: RegStatus) -> String {
        switch status {
        case .pending: return "clock.badge"
        case .approved: return "checkmark.seal.fill"
        case .checked_in: return "qrcode.viewfinder"
        case .waitlisted: return "hourglass"
        case .rejected: return "xmark.octagon.fill"
        case .completed: return "trophy.fill"
        case .cancelled: return "slash.circle.fill"
        }
    }

    private func statusColor(_ status: RegStatus) -> Color {
        switch status {
        case .pending: return AppTheme.warning
        case .approved, .completed, .checked_in: return AppTheme.success
        case .waitlisted: return AppTheme.secondary
        case .rejected, .cancelled: return AppTheme.error
        }
    }

    private func statusSubtitle(_ status: RegStatus) -> String {
        switch status {
        case .pending:
            return "Waiting for organizer approval"
        case .approved:
            return "You're on the guest list"
        case .checked_in:
            return "Your ticket has been checked"
        case .waitlisted:
            return "We'll notify you if a seat opens up"
        case .rejected:
            return "Organizer declined this application"
        case .completed:
            return "Thanks for attending"
        case .cancelled:
            return "Registration cancelled"
        }
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        return (first + last).uppercased()
    }
}
