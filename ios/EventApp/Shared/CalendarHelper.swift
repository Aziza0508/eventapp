import EventKit
import EventKitUI

/// CalendarHelper wraps EventKit operations for adding events to the user's calendar.
@MainActor
final class CalendarHelper {
    static let shared = CalendarHelper()

    private let store = EKEventStore()

    enum CalendarError: LocalizedError {
        case accessDenied
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .accessDenied: return "Calendar access was denied. Enable it in Settings."
            case .saveFailed(let e): return "Failed to save event: \(e.localizedDescription)"
            }
        }
    }

    /// Request calendar access and add the event.
    func addToCalendar(
        title: String,
        startDate: Date,
        endDate: Date?,
        location: String?,
        notes: String?
    ) async throws {
        // Request access (iOS 17+ uses the new API, fallback for 16).
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await store.requestFullAccessToEvents()
        } else {
            granted = try await withCheckedThrowingContinuation { cont in
                store.requestAccess(to: .event) { ok, err in
                    if let err = err { cont.resume(throwing: err) }
                    else { cont.resume(returning: ok) }
                }
            }
        }

        guard granted else {
            throw CalendarError.accessDenied
        }

        let ekEvent = EKEvent(eventStore: store)
        ekEvent.title = title
        ekEvent.startDate = startDate
        ekEvent.endDate = endDate ?? startDate.addingTimeInterval(3600) // default 1h
        ekEvent.location = location
        ekEvent.notes = notes
        ekEvent.calendar = store.defaultCalendarForNewEvents

        // Add a reminder 1 hour before.
        ekEvent.addAlarm(EKAlarm(relativeOffset: -3600))

        do {
            try store.save(ekEvent, span: .thisEvent)
        } catch {
            throw CalendarError.saveFailed(error)
        }
    }
}
