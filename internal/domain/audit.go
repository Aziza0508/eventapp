package domain

import "time"

// AuditAction categorizes the type of audited action.
type AuditAction string

const (
	AuditLogin              AuditAction = "login"
	AuditRegister           AuditAction = "register"
	AuditOrganizerApproved  AuditAction = "organizer_approved"
	AuditOrganizerRejected  AuditAction = "organizer_rejected"
	AuditUserBlocked        AuditAction = "user_blocked"
	AuditUserUnblocked      AuditAction = "user_unblocked"
	AuditUserRoleChanged    AuditAction = "user_role_changed"
	AuditEventCreated       AuditAction = "event_created"
	AuditEventUpdated       AuditAction = "event_updated"
	AuditEventDeleted       AuditAction = "event_deleted"
	AuditRegistrationApply  AuditAction = "registration_apply"
	AuditRegistrationStatus AuditAction = "registration_status_change"
	AuditCheckin            AuditAction = "checkin"
)

// AuditLog records a single audited action.
type AuditLog struct {
	ID         uint        `gorm:"primaryKey"      json:"id"`
	ActorID    uint        `gorm:"not null;index"  json:"actor_id"`
	Action     AuditAction `gorm:"not null;index"  json:"action"`
	EntityType string      `gorm:"not null"        json:"entity_type"` // "user", "event", "registration"
	EntityID   uint        `                       json:"entity_id"`
	Summary    string      `gorm:"type:text"       json:"summary"`
	IP         string      `                       json:"ip,omitempty"`
	CreatedAt  time.Time   `                       json:"created_at"`
}

func (AuditLog) TableName() string { return "audit_logs" }
