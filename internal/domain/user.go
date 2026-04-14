package domain

import (
	"time"

	"github.com/lib/pq"
)

// UserRole defines allowed roles in the system.
type UserRole string

const (
	RoleStudent   UserRole = "student"
	RoleOrganizer UserRole = "organizer"
	RoleAdmin     UserRole = "admin"
)

// IsValid checks if the role is one of the allowed values.
func (r UserRole) IsValid() bool {
	switch r {
	case RoleStudent, RoleOrganizer, RoleAdmin:
		return true
	}
	return false
}

// PrivacySettings controls profile visibility.
type PrivacySettings struct {
	VisibleToOrganizers bool `gorm:"column:privacy_visible_to_organizers;default:true" json:"visible_to_organizers"`
	VisibleToSchool     bool `gorm:"column:privacy_visible_to_school;default:true"     json:"visible_to_school"`
}

// User is the core identity entity.
type User struct {
	ID           uint           `gorm:"primaryKey"            json:"id"`
	Email        string         `gorm:"uniqueIndex;not null"  json:"email"`
	PasswordHash string         `gorm:"column:password_hash"  json:"-"`
	Role         UserRole       `gorm:"default:'student'"     json:"role"`
	Approved     bool           `                             json:"approved"`
	Blocked      bool           `gorm:"default:false"         json:"blocked"`
	FullName     string         `gorm:"not null"              json:"full_name"`
	Phone        string         `                             json:"phone,omitempty"`
	School       string         `                             json:"school,omitempty"`
	City         string         `                             json:"city,omitempty"`
	Grade        int            `                             json:"grade,omitempty"`
	Bio          string         `                             json:"bio,omitempty"`
	AvatarURL    string         `gorm:"column:avatar_url"     json:"avatar_url,omitempty"`
	Interests    pq.StringArray `gorm:"type:text[]"           json:"interests,omitempty"`

	// Privacy (embedded struct maps to flat columns)
	PrivacySettings `gorm:"embedded"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// TableName overrides the GORM table name.
func (User) TableName() string { return "users" }
