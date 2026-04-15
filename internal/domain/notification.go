package domain

import "time"

// NotificationType categorizes the notification trigger.
type NotificationType string

const (
	NotifRegistrationSubmitted NotificationType = "registration_submitted"
	NotifOrganizerNewRegistration NotificationType = "organizer_new_registration"
	NotifRegistrationApproved  NotificationType = "registration_approved"
	NotifRegistrationRejected  NotificationType = "registration_rejected"
	NotifRegistrationCheckedIn NotificationType = "registration_checked_in"
	NotifWaitlistPromoted      NotificationType = "waitlist_promoted"
	NotifOrganizerApprovalPending NotificationType = "organizer_approval_pending"
	NotifEventReminder         NotificationType = "event_reminder"
	NotifEventUpdated          NotificationType = "event_updated"
)

// Notification is a persistent in-app notification for a user.
type Notification struct {
	ID        uint             `gorm:"primaryKey"         json:"id"`
	UserID    uint             `gorm:"not null;index"     json:"user_id"`
	Type      NotificationType `gorm:"not null"           json:"type"`
	Title     string           `gorm:"not null"           json:"title"`
	Body      string           `gorm:"not null"           json:"body"`
	EventID   *uint            `                          json:"event_id,omitempty"`
	Read      bool             `gorm:"default:false"      json:"read"`
	CreatedAt time.Time        `                          json:"created_at"`
}

func (Notification) TableName() string { return "notifications" }

// DeviceToken stores an APNs push token for a user.
type DeviceToken struct {
	ID        uint      `gorm:"primaryKey"  json:"id"`
	UserID    uint      `gorm:"not null;index" json:"user_id"`
	Token     string    `gorm:"not null;uniqueIndex" json:"token"`
	Platform  string    `gorm:"default:'ios'" json:"platform"` // ios | android (future)
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (DeviceToken) TableName() string { return "device_tokens" }
