// MARK: - Domain Models
// These match the backend JSON contracts exactly.

import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let fullName: String
    let role: UserRole
    let approved: Bool?
    let blocked: Bool?
    let phone: String?
    let city: String?
    let school: String?
    let grade: Int?
    let bio: String?
    let avatarURL: String?
    let interests: [String]?
    let privacy: PrivacySettings?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, role, approved, blocked, phone, city, school, grade, bio, interests, privacy
        case fullName  = "full_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
    }
}

struct PrivacySettings: Codable {
    var visibleToOrganizers: Bool
    var visibleToSchool: Bool

    enum CodingKeys: String, CodingKey {
        case visibleToOrganizers = "visible_to_organizers"
        case visibleToSchool     = "visible_to_school"
    }
}

enum UserRole: String, Codable {
    case student
    case organizer
    case admin
}

// MARK: - Event

struct Event: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let category: String?
    let tags: [String]?
    let format: EventFormat?
    let city: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let organizerContact: String?
    let additionalInfo: String?
    let dateStart: Date
    let dateEnd: Date?
    let regDeadline: Date?
    let capacity: Int
    let isFree: Bool?
    let price: Double?
    let posterURL: String?
    let checkinToken: String?
    let organizerID: Int
    let organizer: User?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, tags, format, city, address
        case latitude, longitude, capacity, organizer
        case organizerContact = "organizer_contact"
        case additionalInfo   = "additional_info"
        case dateStart        = "date_start"
        case dateEnd          = "date_end"
        case regDeadline      = "reg_deadline"
        case isFree           = "is_free"
        case price
        case posterURL        = "poster_url"
        case checkinToken     = "checkin_token"
        case organizerID      = "organizer_id"
        case createdAt        = "created_at"
    }
}

/// Enriched response from GET /api/events/:id
struct EventDetailResponse: Codable {
    let id: Int
    let title: String
    let description: String?
    let category: String?
    let tags: [String]?
    let format: EventFormat?
    let city: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let organizerContact: String?
    let additionalInfo: String?
    let dateStart: Date
    let dateEnd: Date?
    let regDeadline: Date?
    let capacity: Int
    let isFree: Bool?
    let price: Double?
    let posterURL: String?
    let checkinToken: String?
    let organizerID: Int
    let organizer: User?
    let createdAt: Date
    let freeSeats: Int
    let isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, tags, format, city, address
        case latitude, longitude, capacity, organizer, price
        case organizerContact = "organizer_contact"
        case additionalInfo   = "additional_info"
        case dateStart        = "date_start"
        case dateEnd          = "date_end"
        case regDeadline      = "reg_deadline"
        case isFree           = "is_free"
        case posterURL        = "poster_url"
        case checkinToken     = "checkin_token"
        case organizerID      = "organizer_id"
        case createdAt        = "created_at"
        case freeSeats        = "free_seats"
        case isFavorite       = "is_favorite"
    }

    /// Convert to a plain Event for reuse in views.
    var asEvent: Event {
        Event(id: id, title: title, description: description, category: category,
              tags: tags, format: format, city: city, address: address,
              latitude: latitude, longitude: longitude,
              organizerContact: organizerContact, additionalInfo: additionalInfo,
              dateStart: dateStart, dateEnd: dateEnd, regDeadline: regDeadline,
              capacity: capacity, isFree: isFree, price: price,
              posterURL: posterURL, checkinToken: checkinToken,
              organizerID: organizerID, organizer: organizer, createdAt: createdAt)
    }
}

enum EventFormat: String, Codable, CaseIterable {
    case online
    case offline
    case hybrid

    var displayName: String {
        switch self {
        case .online:  return "Online"
        case .offline: return "Offline"
        case .hybrid:  return "Hybrid"
        }
    }
}

// MARK: - Registration

struct Registration: Codable, Identifiable {
    let id: Int
    let userID: Int
    let eventID: Int
    let status: RegStatus
    let checkedInAt: Date?
    let event: Event?
    let user: User?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status, event, user
        case userID      = "user_id"
        case eventID     = "event_id"
        case checkedInAt = "checked_in_at"
        case createdAt   = "created_at"
    }
}

enum RegStatus: String, Codable {
    case pending
    case approved
    case rejected
    case waitlisted
    case checked_in
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .pending:    return "Pending"
        case .approved:   return "Approved"
        case .rejected:   return "Rejected"
        case .waitlisted: return "Waitlisted"
        case .checked_in: return "Checked In"
        case .completed:  return "Completed"
        case .cancelled:  return "Cancelled"
        }
    }

    var color: String {
        switch self {
        case .pending:    return "orange"
        case .approved:   return "green"
        case .rejected:   return "red"
        case .waitlisted: return "blue"
        case .checked_in: return "purple"
        case .completed:  return "green"
        case .cancelled:  return "gray"
        }
    }

    var isCancellableByUser: Bool {
        switch self {
        case .pending, .approved, .waitlisted: return true
        default: return false
        }
    }
}

// MARK: - Favorite

struct Favorite: Codable, Identifiable {
    let id: Int
    let userID: Int
    let eventID: Int
    let event: Event?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, event
        case userID    = "user_id"
        case eventID   = "event_id"
        case createdAt = "created_at"
    }
}

// MARK: - Notification

struct AppNotification: Codable, Identifiable {
    let id: Int
    let userID: Int
    let type: String
    let title: String
    let body: String
    let eventID: Int?
    let read: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, read
        case userID    = "user_id"
        case eventID   = "event_id"
        case createdAt = "created_at"
    }

    var icon: String {
        switch type {
        case "registration_submitted":  return "paperplane.fill"
        case "registration_approved":   return "checkmark.circle.fill"
        case "registration_rejected":   return "xmark.circle.fill"
        case "waitlist_promoted":       return "arrow.up.circle.fill"
        case "event_reminder":          return "bell.fill"
        case "event_updated":           return "arrow.triangle.2.circlepath"
        default:                        return "bell.fill"
        }
    }

    var iconColor: Color {
        switch type {
        case "registration_approved", "waitlist_promoted": return AppTheme.success
        case "registration_rejected":                      return AppTheme.error
        case "registration_submitted":                     return AppTheme.primary
        case "event_reminder":                             return AppTheme.warning
        default:                                           return AppTheme.secondary
        }
    }
}

import SwiftUI

struct UnreadCountResponse: Codable {
    let count: Int

    enum CodingKeys: String, CodingKey {
        case count = "unread_count"
    }
}

// MARK: - Paginated Response

struct EventListResponse: Codable {
    let data: [Event]
    let total: Int
    let page: Int
    let limit: Int
}

// MARK: - Upload Response

struct UploadResponse: Codable {
    let url: String
}

// MARK: - Report DTOs

struct OrganizerSummary: Codable {
    let organizerID: Int
    let totalEvents: Int
    let totalRegistered: Int
    let totalCheckedIn: Int
    let avgFillRate: Double
    let events: [EventSummaryRow]

    enum CodingKeys: String, CodingKey {
        case organizerID     = "organizer_id"
        case totalEvents     = "total_events"
        case totalRegistered = "total_registered"
        case totalCheckedIn  = "total_checked_in"
        case avgFillRate     = "avg_fill_rate_pct"
        case events
    }
}

struct EventSummaryRow: Codable, Identifiable {
    let eventID: Int
    let title: String
    let dateStart: Date
    let capacity: Int
    let registered: Int
    let approved: Int
    let checkedIn: Int
    let completed: Int
    let rejected: Int
    let waitlisted: Int
    let cancelled: Int
    let fillRate: Double
    let checkinRate: Double

    var id: Int { eventID }

    enum CodingKeys: String, CodingKey {
        case eventID     = "event_id"
        case title
        case dateStart   = "date_start"
        case capacity, registered, approved, rejected, waitlisted, cancelled, completed
        case checkedIn   = "checked_in"
        case fillRate    = "fill_rate_pct"
        case checkinRate = "checkin_rate_pct"
    }
}

struct AttendanceReport: Codable {
    let eventID: Int
    let eventTitle: String
    let eventDate: Date
    let capacity: Int
    let statusCount: [String: Int]
    let totalRows: Int
    let rows: [AttendanceRow]

    enum CodingKeys: String, CodingKey {
        case eventID     = "event_id"
        case eventTitle  = "event_title"
        case eventDate   = "event_date"
        case capacity
        case statusCount = "status_count"
        case totalRows   = "total_rows"
        case rows
    }
}

struct AttendanceRow: Codable, Identifiable {
    let userName: String
    let userEmail: String
    let school: String
    let city: String
    let grade: Int
    let status: String
    let checkedInAt: Date?
    let appliedAt: Date

    var id: String { userEmail }

    enum CodingKeys: String, CodingKey {
        case userName    = "user_name"
        case userEmail   = "user_email"
        case school, city, grade, status
        case checkedInAt = "checked_in_at"
        case appliedAt   = "applied_at"
    }
}
