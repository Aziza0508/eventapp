package app

import (
	"context"
	"time"

	"eventapp/internal/domain"
)

// UserFilter holds query parameters for admin user listing.
type UserFilter struct {
	Role     domain.UserRole
	Approved *bool
	Blocked  *bool
	Search   string
	Page     int
	Limit    int
}

// UserRepository defines data access operations for users.
type UserRepository interface {
	Create(user *domain.User) error
	GetByEmail(email string) (*domain.User, error)
	GetByID(id uint) (*domain.User, error)
	Update(user *domain.User) error
	ListByRoleAndApproval(role domain.UserRole, approved bool) ([]domain.User, error)
	ListFiltered(filter UserFilter) ([]domain.User, int64, error)
	CountByRole() (map[domain.UserRole]int64, error)
}

// AuditLogRepository persists and queries audit log entries.
type AuditLogRepository interface {
	Create(log *domain.AuditLog) error
	List(limit int) ([]domain.AuditLog, error)
	ListByActor(actorID uint, limit int) ([]domain.AuditLog, error)
}

// EventRepository defines data access operations for events.
type EventRepository interface {
	Create(event *domain.Event) error
	GetByID(id uint) (*domain.Event, error)
	List(filter domain.EventFilter) ([]domain.Event, int64, error)
	Update(event *domain.Event) error
	Delete(id uint) error
	CountRegistrations(eventID uint) (int64, error)
}

// RegistrationRepository defines data access operations for registrations.
type RegistrationRepository interface {
	Create(reg *domain.Registration) error
	GetByID(id uint) (*domain.Registration, error)
	GetByUserAndEvent(userID, eventID uint) (*domain.Registration, error)
	ListByUser(userID uint) ([]domain.Registration, error)
	ListByEvent(eventID uint) ([]domain.Registration, error)
	Update(reg *domain.Registration) error
	// FirstWaitlisted returns the oldest waitlisted registration for an event (for promotion).
	FirstWaitlisted(eventID uint) (*domain.Registration, error)
	// CountByEventAndStatus returns registration counts grouped by status for an event.
	CountByEventAndStatus(eventID uint) (map[domain.RegStatus]int64, error)
}

// JWTProvider defines token operations.
type JWTProvider interface {
	Generate(userID uint, role domain.UserRole) (string, error)
	// Validate parses a token string and returns (userID, role, error).
	Validate(tokenString string) (uint, domain.UserRole, error)
}

// FavoriteRepository defines data access operations for bookmarks.
type FavoriteRepository interface {
	Add(fav *domain.Favorite) error
	Remove(userID, eventID uint) error
	Exists(userID, eventID uint) (bool, error)
	ListByUser(userID uint) ([]domain.Favorite, error)
}

// NotificationRepository persists in-app notifications.
type NotificationRepository interface {
	Create(n *domain.Notification) error
	ListByUser(userID uint, unreadOnly bool, limit int) ([]domain.Notification, error)
	MarkRead(id, userID uint) error
	MarkAllRead(userID uint) error
	CountUnread(userID uint) (int64, error)
}

// DeviceTokenRepository stores push notification tokens.
type DeviceTokenRepository interface {
	Upsert(dt *domain.DeviceToken) error
	Delete(userID uint, token string) error
	ListByUser(userID uint) ([]domain.DeviceToken, error)
}

// NotificationSender is an abstraction over push delivery channels.
// Implementations: LogSender (dev), APNsSender (production), EmailSender.
type NotificationSender interface {
	Send(userID uint, title, body string) error
}

// RefreshTokenStore manages refresh token persistence and revocation.
type RefreshTokenStore interface {
	// Save stores a refresh token hash with a TTL, associated with a user.
	Save(ctx context.Context, userID uint, tokenHash string, ttl time.Duration) error
	// Exists checks if a refresh token hash is still valid (not revoked/expired).
	Exists(ctx context.Context, userID uint, tokenHash string) (bool, error)
	// Revoke deletes a specific refresh token hash.
	Revoke(ctx context.Context, userID uint, tokenHash string) error
	// RevokeAll deletes all refresh tokens for a user (e.g. password change).
	RevokeAll(ctx context.Context, userID uint) error
}
