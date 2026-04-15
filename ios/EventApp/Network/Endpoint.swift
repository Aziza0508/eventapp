import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String {
    case GET, POST, PUT, PATCH, DELETE
}

// MARK: - Endpoint

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let queryParams: [String: Any]?
    let body: Encodable?
    let requiresAuth: Bool

    init(path: String,
         method: HTTPMethod = .GET,
         queryParams: [String: Any]? = nil,
         body: Encodable? = nil,
         requiresAuth: Bool = true) {
        self.path = path
        self.method = method
        self.queryParams = queryParams
        self.body = body
        self.requiresAuth = requiresAuth
    }
}

// MARK: - Auth Endpoints

extension Endpoint {
    static func register(email: String, password: String, fullName: String,
                         role: String = "student", city: String? = nil,
                         school: String? = nil, grade: Int? = nil) -> Endpoint {
        let body = RegisterBody(email: email, password: password, fullName: fullName,
                                role: role, city: city, school: school, grade: grade)
        return Endpoint(path: "/auth/register", method: .POST, body: body, requiresAuth: false)
    }

    static func login(email: String, password: String) -> Endpoint {
        let body = LoginBody(email: email, password: password)
        return Endpoint(path: "/auth/login", method: .POST, body: body, requiresAuth: false)
    }

    static func refresh(refreshToken: String) -> Endpoint {
        let body = RefreshBody(refreshToken: refreshToken)
        return Endpoint(path: "/auth/refresh", method: .POST, body: body, requiresAuth: false)
    }

    static func logout(refreshToken: String) -> Endpoint {
        let body = LogoutBody(refreshToken: refreshToken)
        return Endpoint(path: "/auth/logout", method: .POST, body: body)
    }

    static var me: Endpoint {
        Endpoint(path: "/api/me")
    }

    static func updateProfile(body: UpdateProfileBody) -> Endpoint {
        Endpoint(path: "/api/me", method: .PUT, body: body)
    }
}

// MARK: - Event Endpoints

extension Endpoint {
    static func events(city: String? = nil, category: String? = nil,
                       format: String? = nil, search: String? = nil,
                       isFree: Bool? = nil,
                       page: Int = 1, limit: Int = 20) -> Endpoint {
        var params: [String: Any] = ["page": page, "limit": limit]
        if let city = city, !city.isEmpty     { params["city"] = city }
        if let cat  = category, !cat.isEmpty  { params["category"] = cat }
        if let fmt  = format, !fmt.isEmpty    { params["format"] = fmt }
        if let s    = search, !s.isEmpty      { params["search"] = s }
        if let free = isFree                  { params["is_free"] = free ? "true" : "false" }
        return Endpoint(path: "/api/events", queryParams: params)
    }

    static func event(id: Int) -> Endpoint {
        Endpoint(path: "/api/events/\(id)")
    }

    static func createEvent(body: CreateEventBody) -> Endpoint {
        Endpoint(path: "/api/events", method: .POST, body: body)
    }

    static func updateEvent(id: Int, body: FullUpdateEventBody) -> Endpoint {
        Endpoint(path: "/api/events/\(id)", method: .PUT, body: body)
    }

    static func deleteEvent(id: Int) -> Endpoint {
        Endpoint(path: "/api/events/\(id)", method: .DELETE)
    }
}

// MARK: - Registration Endpoints

extension Endpoint {
    static func apply(eventID: Int) -> Endpoint {
        Endpoint(path: "/api/events/\(eventID)/apply", method: .POST)
    }

    static var myEvents: Endpoint {
        Endpoint(path: "/api/my/events")
    }

    static func participants(eventID: Int) -> Endpoint {
        Endpoint(path: "/api/events/\(eventID)/participants")
    }

    static func updateStatus(regID: Int, status: String) -> Endpoint {
        let body = UpdateStatusBody(status: status)
        return Endpoint(path: "/api/registrations/\(regID)/status", method: .PATCH, body: body)
    }

    static func cancelRegistration(regID: Int) -> Endpoint {
        Endpoint(path: "/api/registrations/\(regID)", method: .DELETE)
    }

    static func getQRPayload(regID: Int) -> Endpoint {
        Endpoint(path: "/api/registrations/\(regID)/qr")
    }

    static func checkinByQR(regID: Int, qrHMAC: String) -> Endpoint {
        let body = CheckinBody(qrHMAC: qrHMAC)
        return Endpoint(path: "/api/registrations/\(regID)/checkin", method: .PATCH, body: body)
    }
}

// MARK: - Favorite Endpoints

extension Endpoint {
    static func addFavorite(eventID: Int) -> Endpoint {
        Endpoint(path: "/api/events/\(eventID)/favorite", method: .POST)
    }

    static func removeFavorite(eventID: Int) -> Endpoint {
        Endpoint(path: "/api/events/\(eventID)/favorite", method: .DELETE)
    }

    static var myFavorites: Endpoint {
        Endpoint(path: "/api/me/favorites")
    }
}

// MARK: - Notification Endpoints

extension Endpoint {
    static func notifications(unreadOnly: Bool = false, limit: Int = 50) -> Endpoint {
        var params: [String: Any] = ["limit": limit]
        if unreadOnly { params["unread_only"] = "true" }
        return Endpoint(path: "/api/notifications", queryParams: params)
    }

    static var notificationsUnreadCount: Endpoint {
        Endpoint(path: "/api/notifications/unread-count")
    }

    static func markNotificationRead(id: Int) -> Endpoint {
        Endpoint(path: "/api/notifications/\(id)/read", method: .PATCH)
    }

    static var markAllNotificationsRead: Endpoint {
        Endpoint(path: "/api/notifications/read-all", method: .POST)
    }
}

// MARK: - Report Endpoints

extension Endpoint {
    static func attendanceReport(eventID: Int) -> Endpoint {
        Endpoint(path: "/api/reports/events/\(eventID)/attendance")
    }

    static var organizerSummary: Endpoint {
        Endpoint(path: "/api/reports/organizer/summary")
    }
}

// MARK: - Admin Endpoints

extension Endpoint {
    static var pendingOrganizers: Endpoint {
        Endpoint(path: "/api/admin/organizers/pending")
    }

    static func approveOrganizer(id: Int) -> Endpoint {
        Endpoint(path: "/api/admin/organizers/\(id)/approve", method: .PATCH)
    }

    static func rejectOrganizer(id: Int) -> Endpoint {
        Endpoint(path: "/api/admin/organizers/\(id)/reject", method: .PATCH)
    }
}

// MARK: - Request Bodies

struct RegisterBody: Encodable {
    let email: String
    let password: String
    let fullName: String
    let role: String
    let city: String?
    let school: String?
    let grade: Int?
    enum CodingKeys: String, CodingKey {
        case email, password, role, city, school, grade
        case fullName = "full_name"
    }
}

struct LoginBody: Encodable {
    let email: String
    let password: String
}

struct RefreshBody: Encodable {
    let refreshToken: String
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct LogoutBody: Encodable {
    let refreshToken: String
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct CreateEventBody: Encodable {
    let title: String
    let description: String
    let category: String
    let tags: [String]
    let format: String
    let city: String
    let address: String
    let organizerContact: String
    let additionalInfo: String
    let dateStart: Date
    let dateEnd: Date?
    let regDeadline: Date?
    let capacity: Int
    let isFree: Bool
    let price: Double
    var posterURL: String?
    enum CodingKeys: String, CodingKey {
        case title, description, category, tags, format, city, address, capacity, price
        case organizerContact = "organizer_contact"
        case additionalInfo   = "additional_info"
        case dateStart        = "date_start"
        case dateEnd          = "date_end"
        case regDeadline      = "reg_deadline"
        case isFree           = "is_free"
        case posterURL        = "poster_url"
    }
}

/// Full update body with all event fields for PUT /api/events/:id.
struct FullUpdateEventBody: Encodable {
    let title: String
    let description: String
    let category: String
    let tags: [String]
    let format: String
    let city: String
    let address: String
    let organizerContact: String
    let additionalInfo: String
    let dateStart: Date
    let dateEnd: Date?
    let regDeadline: Date?
    let capacity: Int
    let isFree: Bool
    let price: Double
    let posterURL: String?
    enum CodingKeys: String, CodingKey {
        case title, description, category, tags, format, city, address, capacity, price
        case organizerContact = "organizer_contact"
        case additionalInfo   = "additional_info"
        case dateStart        = "date_start"
        case dateEnd          = "date_end"
        case regDeadline      = "reg_deadline"
        case isFree           = "is_free"
        case posterURL        = "poster_url"
    }
}

struct UpdateStatusBody: Encodable {
    let status: String
}

struct CheckinBody: Encodable {
    let qrHMAC: String
    enum CodingKeys: String, CodingKey {
        case qrHMAC = "qr_hmac"
    }
}

struct UpdateProfileBody: Encodable {
    var fullName: String?
    var phone: String?
    var school: String?
    var city: String?
    var grade: Int?
    var bio: String?
    var avatarURL: String?
    var interests: [String]?
    var privacy: PrivacySettingsBody?

    enum CodingKeys: String, CodingKey {
        case phone, school, city, grade, bio, interests, privacy
        case fullName  = "full_name"
        case avatarURL = "avatar_url"
    }
}

struct PrivacySettingsBody: Encodable {
    var visibleToOrganizers: Bool?
    var visibleToSchool: Bool?

    enum CodingKeys: String, CodingKey {
        case visibleToOrganizers = "visible_to_organizers"
        case visibleToSchool     = "visible_to_school"
    }
}
