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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection

                contentColumn
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.top, AppTheme.Spacing.lg)
            }
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
        .onAppear { vm.setExistingRegistration(existingRegistration) }
        .toastOverlay(vm.toast)
    }

    // MARK: - Content column

    @ViewBuilder
    private var contentColumn: some View {
        // Stats pill strip
        statsStrip
            .padding(.bottom, AppTheme.Spacing.lg)

        // Organizer row
        if let org = event.organizer {
            organizerRow(org: org)
                .padding(.bottom, AppTheme.Spacing.lg)
        }

        // Tags
        if let tags = event.tags, !tags.isEmpty {
            tagsRow(tags: tags)
                .padding(.bottom, AppTheme.Spacing.md)
        }

        // About
        if let desc = event.description, !desc.isEmpty {
            aboutSection(description: desc)
                .padding(.bottom, AppTheme.Spacing.lg)
        }

        // Detailed info card
        detailsCard
            .padding(.bottom, AppTheme.Spacing.lg)

        // Additional info
        if let info = event.additionalInfo, !info.isEmpty {
            additionalSection(info: info)
                .padding(.bottom, AppTheme.Spacing.lg)
        }

        // Add to Calendar
        addToCalendarButton

        Spacer(minLength: 100)
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            posterBackground

            // Dark gradient for legibility
            AppTheme.heroOverlay
                .frame(height: 340)

            // Top action bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                Spacer()
                Button {
                    Task { await vm.toggleFavorite(eventID: event.id) }
                } label: {
                    Image(systemName: vm.isFavorite ? "bookmark.fill" : "bookmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(vm.isFavorite ? AppTheme.accent : .white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.top, 56)
            .padding(.horizontal, AppTheme.Spacing.xl)

            // Hero body content
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack(spacing: 6) {
                        if let cat = event.category {
                            Text(cat)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.25))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        if let free = event.isFree {
                            Text(free ? "Free" : "Paid")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(free ? AppTheme.accent.opacity(0.95) : AppTheme.warning.opacity(0.95))
                                .foregroundStyle(AppTheme.textPrimary)
                                .clipShape(Capsule())
                        }
                        if let format = event.format {
                            Text(format.displayName)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.20))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }

                    Text(event.title)
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
        if let poster = event.posterURL, !poster.isEmpty, let url = URL(string: poster) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                        .frame(height: 340).clipped()
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
            statPill(icon: "calendar",
                     value: Self.fullDateFormatter.string(from: event.dateStart),
                     label: Self.timeFormatter.string(from: event.dateStart))
            if event.capacity > 0 {
                statPill(icon: "person.2.fill",
                         value: vm.freeSeats > 0 ? "\(vm.freeSeats) left" : "Full",
                         label: "of \(event.capacity) seats",
                         tint: vm.freeSeats > 0 ? AppTheme.primary : AppTheme.error)
            } else {
                statPill(icon: "infinity",
                         value: "Open",
                         label: "no seat limit")
            }
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
                if let contact = event.organizerContact, !contact.isEmpty {
                    Text(contact)
                        .font(.caption)
                        .foregroundStyle(AppTheme.primary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let contact = event.organizerContact, !contact.isEmpty,
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
                infoRow(icon: "calendar",
                        label: "Date",
                        value: Self.dateFormatter.string(from: event.dateStart))
                Divider().padding(.leading, 56)
                infoRow(icon: "clock",
                        label: "Time",
                        value: Self.timeFormatter.string(from: event.dateStart))

                if let city = event.city, !city.isEmpty {
                    Divider().padding(.leading, 56)
                    let loc = [city, event.address]
                        .compactMap { $0?.isEmpty == false ? $0 : nil }
                        .joined(separator: ", ")
                    infoRow(icon: "mappin.and.ellipse",
                            label: "Location", value: loc)
                }

                if let deadline = event.regDeadline {
                    Divider().padding(.leading, 56)
                    infoRow(icon: "exclamationmark.circle",
                            label: "Apply before",
                            value: Self.dateFormatter.string(from: deadline),
                            tint: AppTheme.warning)
                }

                if let price = event.price, price > 0, event.isFree == false {
                    Divider().padding(.leading, 56)
                    infoRow(icon: "creditcard.fill",
                            label: "Price",
                            value: String(format: "%.0f KZT", price),
                            tint: AppTheme.warning)
                }

                if let end = event.dateEnd {
                    Divider().padding(.leading, 56)
                    infoRow(icon: "flag.checkered",
                            label: "Ends",
                            value: Self.dateFormatter.string(from: end))
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
                        let location = [event.city, event.address]
                            .compactMap { $0?.isEmpty == false ? $0 : nil }
                            .joined(separator: ", ")
                        do {
                            try await CalendarHelper.shared.addToCalendar(
                                title: event.title,
                                startDate: event.dateStart,
                                endDate: event.dateEnd,
                                location: location.isEmpty ? nil : location,
                                notes: event.description
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
                Task { await vm.apply(eventID: event.id) }
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
                    Task { await vm.apply(eventID: event.id) }
                }
            }
        }
    }

    private func regStatusIcon(_ status: RegStatus) -> String {
        switch status {
        case .pending:    return "clock.fill"
        case .approved:   return "checkmark.seal.fill"
        case .rejected:   return "xmark.seal.fill"
        case .waitlisted: return "hourglass"
        case .checked_in: return "qrcode.viewfinder"
        case .completed:  return "trophy.fill"
        case .cancelled:  return "slash.circle"
        }
    }

    private func statusColor(_ status: RegStatus) -> Color {
        switch status {
        case .pending:    return AppTheme.warning
        case .approved:   return AppTheme.success
        case .rejected:   return AppTheme.error
        case .waitlisted: return AppTheme.secondary
        case .checked_in: return AppTheme.primaryDark
        case .completed:  return AppTheme.success
        case .cancelled:  return AppTheme.textTertiary
        }
    }

    private func statusSubtitle(_ status: RegStatus) -> String {
        switch status {
        case .pending:    return "Waiting on organizer review"
        case .approved:   return "You're in! Your ticket is ready."
        case .rejected:   return "Application was declined"
        case .waitlisted: return "A seat will open up if someone cancels"
        case .checked_in: return "You're checked in — enjoy the event!"
        case .completed:  return "Event completed"
        case .cancelled:  return "Registration cancelled"
        }
    }

    private func initials(from name: String) -> String {
        let parts = name.components(separatedBy: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? (parts.last?.first.map(String.init) ?? "") : ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }
}
