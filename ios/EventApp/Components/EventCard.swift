import SwiftUI

// MARK: - EventCard
// Standard list row: content on the left, rounded poster thumb on the right.
// Phase B redesign: elevated title, green-led chips, better rhythm.

struct EventCard: View {
    let event: Event

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // MARK: Poster / date thumb
            ZStack(alignment: .topLeading) {
                posterBackground

                // Date pill
                VStack(spacing: 0) {
                    Text(Self.monthFormatter.string(from: event.dateStart).uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                    Text(Self.dayFormatter.string(from: event.dateStart))
                        .font(.title3.weight(.black))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(8)
            }
            .frame(width: 100, height: 124)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))

            // MARK: Content
            VStack(alignment: .leading, spacing: 6) {
                // Category chip
                if let category = event.category {
                    CategoryBadge(text: category)
                }

                // Title
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Location + time
                HStack(spacing: AppTheme.Spacing.sm) {
                    if let city = event.city, !city.isEmpty {
                        Label(city, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Label(Self.timeFormatter.string(from: event.dateStart),
                          systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                // Bottom meta strip
                HStack(spacing: 6) {
                    if let free = event.isFree {
                        MetaChip(
                            text: free ? "Free" : "Paid",
                            tint: free ? AppTheme.success : AppTheme.warning
                        )
                    }
                    if let format = event.format {
                        FormatBadge(format: format)
                    }
                    if event.capacity > 0 {
                        MetaChip(
                            text: "\(event.capacity) spots",
                            systemImage: "person.2.fill",
                            tint: AppTheme.primary
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppTheme.Spacing.md)
            .padding(.trailing, AppTheme.Spacing.md)
        }
        .padding(.leading, AppTheme.Spacing.sm)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .softShadow()
    }

    @ViewBuilder
    private var posterBackground: some View {
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
            AppTheme.primaryGradient
        }
    }
}

// MARK: - HeroEventCard
// Full-bleed poster card used in the Discover "Featured" carousel.

struct HeroEventCard: View {
    let event: Event

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d  ·  HH:mm"; return f
    }()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop
            Group {
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
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()

            // Dark gradient for text legibility
            AppTheme.heroOverlay
                .frame(height: 220)

            // Content
            VStack(alignment: .leading, spacing: 8) {
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
                    if let free = event.isFree, free {
                        Text("Free")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.accent.opacity(0.95))
                            .foregroundStyle(AppTheme.textPrimary)
                            .clipShape(Capsule())
                    }
                }

                Text(event.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

                HStack(spacing: AppTheme.Spacing.md) {
                    Label(Self.dateFormatter.string(from: event.dateStart),
                          systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)

                    if let city = event.city, !city.isEmpty {
                        Label(city, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous))
        .cardShadow()
    }
}

// MARK: - MetaChip
// Small rounded info chip reused across cards.

struct MetaChip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = AppTheme.primary

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - CategoryBadge

struct CategoryBadge: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppTheme.primary.opacity(0.10))
            .foregroundStyle(AppTheme.primary)
            .clipShape(Capsule())
    }
}

// MARK: - FormatBadge

struct FormatBadge: View {
    let format: EventFormat

    private var color: Color {
        switch format {
        case .online:  return AppTheme.secondary
        case .offline: return AppTheme.primary
        case .hybrid:  return AppTheme.warning
        }
    }

    private var icon: String {
        switch format {
        case .online:  return "globe"
        case .offline: return "building.2.fill"
        case .hybrid:  return "rectangle.connected.to.line.below"
        }
    }

    var body: some View {
        MetaChip(text: format.displayName, systemImage: icon, tint: color)
    }
}

// MARK: - StatusBadge

struct StatusBadge: View {
    let status: RegStatus

    private var color: Color {
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

    private var icon: String {
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

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
            Text(status.displayName)
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.14))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}
