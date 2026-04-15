import SwiftUI

@MainActor
final class ParticipantsViewModel: ObservableObject {
    @Published var state: Loadable<[Registration]> = .idle
    @Published var updatingID: Int? = nil

    let toast = ToastPresenter()

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load(eventID: Int) async {
        state = .loading
        do {
            let regs: [Registration] = try await api.request(
                .participants(eventID: eventID),
                responseType: [Registration].self
            )
            state = .success(regs)
        } catch {
            state = .failure(error)
        }
    }

    func updateStatus(regID: Int, newStatus: RegStatus, eventID: Int) async {
        updatingID = regID
        defer { updatingID = nil }
        do {
            let _: Registration = try await api.request(
                .updateStatus(regID: regID, status: newStatus.rawValue),
                responseType: Registration.self
            )
            toast.showSuccess("Status updated to \(newStatus.displayName)")
        } catch {
            toast.showError(error)
        }
        await load(eventID: eventID)
    }
}

struct ParticipantsView: View {
    let event: Event
    @StateObject private var vm = ParticipantsViewModel()
    @State private var showQRScanner = false

    var body: some View {
        Group {
            switch vm.state {
            case .idle where vm.state.value == nil,
                 .loading where vm.state.value == nil:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failure(let error):
                ContentUnavailableView {
                    Label("Failed to load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Retry") { Task { await vm.load(eventID: event.id) } }
                        .buttonStyle(.borderedProminent)
                }

            default:
                participantList
            }
        }
        .navigationTitle("Participants")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showQRScanner = true
                } label: {
                    Label("Scan QR", systemImage: "qrcode.viewfinder")
                }
            }
        }
        .fullScreenCover(isPresented: $showQRScanner, onDismiss: {
            Task { await vm.load(eventID: event.id) }
        }) {
            QRScannerView(event: event)
        }
        .task { await vm.load(eventID: event.id) }
        .refreshable { await vm.load(eventID: event.id) }
        .toastOverlay(vm.toast)
    }

    private var participantList: some View {
        let regs = vm.state.value ?? []
        return Group {
            if regs.isEmpty {
                ContentUnavailableView("No participants yet",
                                       systemImage: "person.3",
                                       description: Text("No one has applied yet."))
            } else {
                List(regs) { reg in
                    ParticipantRow(
                        registration: reg,
                        isUpdating: vm.updatingID == reg.id,
                        onApprove: {
                            Task { await vm.updateStatus(regID: reg.id, newStatus: .approved, eventID: event.id) }
                        },
                        onReject: {
                            Task { await vm.updateStatus(regID: reg.id, newStatus: .rejected, eventID: event.id) }
                        },
                        onCheckin: {
                            Task { await vm.updateStatus(regID: reg.id, newStatus: .checked_in, eventID: event.id) }
                        },
                        onComplete: {
                            Task { await vm.updateStatus(regID: reg.id, newStatus: .completed, eventID: event.id) }
                        }
                    )
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Participant Row

private struct ParticipantRow: View {
    let registration: Registration
    let isUpdating: Bool
    let onApprove: () -> Void
    let onReject: () -> Void
    let onCheckin: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text(registration.user?.fullName ?? "Student #\(registration.userID)")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Text(registration.user?.email ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let school = registration.user?.school, !school.isEmpty {
                            Text("\u{2022} \(school)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                StatusBadge(status: registration.status)
            }

            // Action buttons based on status
            if isUpdating {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                actionButtons
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch registration.status {
        case .pending, .waitlisted:
            HStack(spacing: 12) {
                Button("Approve") { onApprove() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .frame(maxWidth: .infinity)
                Button("Reject") { onReject() }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
            }
            .font(.subheadline)

        case .approved:
            Button {
                onCheckin()
            } label: {
                Label("Check In", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .font(.subheadline)

        case .checked_in:
            Button {
                onComplete()
            } label: {
                Label("Mark Completed", systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .font(.subheadline)

        default:
            EmptyView()
        }
    }
}
