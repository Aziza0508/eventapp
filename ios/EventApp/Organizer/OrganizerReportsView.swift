import SwiftUI

// MARK: - Summary ViewModel

@MainActor
final class OrganizerReportsViewModel: ObservableObject {
    @Published var state: Loadable<OrganizerSummary> = .idle

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load() async {
        state = .loading
        do {
            let summary: OrganizerSummary = try await api.request(
                .organizerSummary,
                responseType: OrganizerSummary.self
            )
            state = .success(summary)
        } catch {
            state = .failure(error)
        }
    }
}

// MARK: - Summary View

struct OrganizerReportsView: View {
    @StateObject private var vm = OrganizerReportsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .idle, .loading where vm.state.value == nil:
                    ProgressView()

                case .failure(let error):
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: "Failed to load",
                        subtitle: error.localizedDescription,
                        actionTitle: "Retry"
                    ) { Task { await vm.load() } }

                case .success(let summary):
                    summaryContent(summary)

                default:
                    if let summary = vm.state.value {
                        summaryContent(summary)
                    }
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }

    private func summaryContent(_ summary: OrganizerSummary) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Stat cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: AppTheme.Spacing.md) {
                    StatCard(title: "Total Events", value: "\(summary.totalEvents)",
                             icon: "calendar", color: AppTheme.primary)
                    StatCard(title: "Registrations", value: "\(summary.totalRegistered)",
                             icon: "person.2", color: AppTheme.secondary)
                    StatCard(title: "Checked In", value: "\(summary.totalCheckedIn)",
                             icon: "checkmark.circle", color: AppTheme.success)
                    StatCard(title: "Avg Fill Rate", value: String(format: "%.0f%%", summary.avgFillRate),
                             icon: "chart.bar", color: AppTheme.warning)
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.top, AppTheme.Spacing.md)

                // Events breakdown
                if !summary.events.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("EVENT BREAKDOWN")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, AppTheme.Spacing.xl)

                        ForEach(summary.events) { row in
                            NavigationLink(destination: AttendanceReportView(eventID: row.eventID, eventTitle: row.title)) {
                                EventReportRow(row: row)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, AppTheme.Spacing.sm)
                }
            }
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .background(AppTheme.background)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(AppTheme.Spacing.md)
        .surfaceCard()
    }
}

// MARK: - Event Report Row

private struct EventReportRow: View {
    let row: EventSummaryRow

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            HStack(spacing: AppTheme.Spacing.md) {
                Label(Self.dateFormatter.string(from: row.dateStart), systemImage: "calendar")
                if row.capacity > 0 {
                    Label("\(row.registered)/\(row.capacity)", systemImage: "person.2")
                } else {
                    Label("\(row.registered) registered", systemImage: "person.2")
                }
            }
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)

            // Mini bar
            HStack(spacing: AppTheme.Spacing.sm) {
                miniStat("Fill", value: String(format: "%.0f%%", row.fillRate), color: AppTheme.primary)
                miniStat("Check-in", value: String(format: "%.0f%%", row.checkinRate), color: AppTheme.success)
                miniStat("Approved", value: "\(row.approved)", color: AppTheme.success)
                miniStat("Pending", value: "\(row.registered - row.approved - row.rejected - row.cancelled)", color: AppTheme.warning)
            }
        }
        .padding(AppTheme.Spacing.md)
        .surfaceCard()
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

    private func miniStat(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Attendance Report View

@MainActor
final class AttendanceReportViewModel: ObservableObject {
    @Published var state: Loadable<AttendanceReport> = .idle

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load(eventID: Int) async {
        state = .loading
        do {
            let report: AttendanceReport = try await api.request(
                .attendanceReport(eventID: eventID),
                responseType: AttendanceReport.self
            )
            state = .success(report)
        } catch {
            state = .failure(error)
        }
    }
}

struct AttendanceReportView: View {
    let eventID: Int
    let eventTitle: String

    @StateObject private var vm = AttendanceReportViewModel()

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading where vm.state.value == nil:
                ProgressView()

            case .failure(let error):
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Failed to load",
                    subtitle: error.localizedDescription,
                    actionTitle: "Retry"
                ) { Task { await vm.load(eventID: eventID) } }

            case .success(let report):
                reportContent(report)

            default:
                if let report = vm.state.value { reportContent(report) }
            }
        }
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(eventID: eventID) }
        .refreshable { await vm.load(eventID: eventID) }
    }

    private func reportContent(_ report: AttendanceReport) -> some View {
        List {
            // Summary
            Section("Summary") {
                LabeledContent("Event", value: report.eventTitle)
                LabeledContent("Capacity", value: report.capacity > 0 ? "\(report.capacity)" : "Unlimited")
                LabeledContent("Total Participants", value: "\(report.totalRows)")

                ForEach(report.statusCount.sorted(by: { $0.key < $1.key }), id: \.key) { status, count in
                    LabeledContent(status.capitalized, value: "\(count)")
                }
            }

            // Rows
            Section("Participants (\(report.rows.count))") {
                ForEach(report.rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.userName)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(row.status.capitalized)
                                .font(.caption.bold())
                                .foregroundStyle(statusColor(row.status))
                        }
                        HStack {
                            Text(row.userEmail)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            if !row.school.isEmpty {
                                Text(row.school)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "approved":   return AppTheme.success
        case "rejected":   return AppTheme.error
        case "pending":    return AppTheme.warning
        case "checked_in": return .purple
        case "completed":  return AppTheme.success
        case "waitlisted": return .blue
        default:           return .gray
        }
    }
}
