import SwiftUI

// MARK: - ViewModel

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var state: Loadable<[AppNotification]> = .idle
    @Published var unreadCount: Int = 0

    let toast = ToastPresenter()
    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load() async {
        state = .loading
        do {
            let notifs: [AppNotification] = try await api.request(
                .notifications(),
                responseType: [AppNotification].self
            )
            state = .success(notifs)
            unreadCount = notifs.filter { !$0.read }.count
        } catch {
            state = .failure(error)
        }
    }

    func fetchUnreadCount() async {
        do {
            let response: UnreadCountResponse = try await api.request(
                .notificationsUnreadCount,
                responseType: UnreadCountResponse.self
            )
            unreadCount = response.count
        } catch {
            // Non-critical — keep existing count
        }
    }

    func markRead(id: Int) async {
        do {
            try await api.requestVoid(.markNotificationRead(id: id))
            // Update locally
            if var list = state.value,
               let idx = list.firstIndex(where: { $0.id == id }) {
                let old = list[idx]
                if !old.read {
                    // Create updated notification (struct is immutable, so rebuild)
                    let updated = AppNotification(
                        id: old.id, userID: old.userID, type: old.type,
                        title: old.title, body: old.body, eventID: old.eventID,
                        read: true, createdAt: old.createdAt
                    )
                    list[idx] = updated
                    state = .success(list)
                    unreadCount = max(0, unreadCount - 1)
                }
            }
        } catch {
            toast.showError(error)
        }
    }

    func markAllRead() async {
        do {
            try await api.requestVoid(.markAllNotificationsRead)
            // Update all locally
            if let list = state.value {
                let updated = list.map { n in
                    AppNotification(
                        id: n.id, userID: n.userID, type: n.type,
                        title: n.title, body: n.body, eventID: n.eventID,
                        read: true, createdAt: n.createdAt
                    )
                }
                state = .success(updated)
                unreadCount = 0
            }
            toast.showSuccess("All notifications marked as read")
        } catch {
            toast.showError(error)
        }
    }
}

// MARK: - View

struct NotificationsView: View {
    @StateObject private var vm = NotificationsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    let notifications = vm.state.value ?? []
                    if notifications.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "bell.slash",
                            title: "No notifications",
                            subtitle: "You'll see updates about your event applications here."
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(notifications) { notif in
                                    NotificationRow(notification: notif) {
                                        Task { await vm.markRead(id: notif.id) }
                                    }
                                    if notif.id != notifications.last?.id {
                                        Divider()
                                            .padding(.leading, 60)
                                            .padding(.horizontal, AppTheme.Spacing.xl)
                                    }
                                }
                            }
                            .padding(.bottom, AppTheme.Spacing.xl)
                        }
                        .refreshable { await vm.load() }
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.unreadCount > 0 {
                        Button {
                            Task { await vm.markAllRead() }
                        } label: {
                            Text("Read All")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .task { await vm.load() }
            .toastOverlay(vm.toast)
        }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    private static let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(notification.iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: notification.icon)
                        .font(.caption.bold())
                        .foregroundStyle(notification.iconColor)
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    HStack {
                        Text(notification.title)
                            .font(.subheadline.weight(notification.read ? .regular : .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(Self.timeFormatter.localizedString(for: notification.createdAt, relativeTo: Date()))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                    }

                    if !notification.body.isEmpty {
                        Text(notification.body)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }
                }

                // Unread dot
                if !notification.read {
                    Circle()
                        .fill(AppTheme.primary)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(notification.read ? Color.clear : AppTheme.primary.opacity(0.03))
        }
        .buttonStyle(.plain)
    }
}
