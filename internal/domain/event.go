package domain

import (
	"time"

	//"github.com/lib/pq"
)

// EventFormat is the delivery format of an event.
type EventFormat string

const (
	FormatOnline  EventFormat = "online"
	FormatOffline EventFormat = "offline"
	FormatHybrid  EventFormat = "hybrid"
)

func (f EventFormat) IsValid() bool {
	switch f {
	case FormatOnline, FormatOffline, FormatHybrid:
		return true
	}
	return false
}

// Event represents a school IT/robotics competition or workshop.
type Event struct {
	ID               uint           `gorm:"primaryKey"              json:"id"`
	Title            string         `gorm:"not null"                json:"title"`
	Description      string         `                               json:"description"`
	Category         string         `                               json:"category"`
	Tags             []string		`gorm:"type:text[]"             json:"tags,omitempty"`
	Format           EventFormat    `                               json:"format"`
	City             string         `                               json:"city"`
	Address          string         `                               json:"address,omitempty"`
	Latitude         *float64       `                               json:"latitude,omitempty"`
	Longitude        *float64       `                               json:"longitude,omitempty"`
	OrganizerContact string         `gorm:"column:organizer_contact" json:"organizer_contact,omitempty"`
	AdditionalInfo   string         `gorm:"column:additional_info"  json:"additional_info,omitempty"`
	DateStart        time.Time      `gorm:"not null"                json:"date_start"`
	DateEnd          *time.Time     `                               json:"date_end,omitempty"`
	RegDeadline      *time.Time     `gorm:"column:reg_deadline"     json:"reg_deadline,omitempty"`
	Capacity         int            `gorm:"default:0"               json:"capacity"`
	IsFree           bool           `gorm:"default:true"            json:"is_free"`
	Price            float64        `gorm:"default:0"               json:"price"`
	PosterURL        string         `gorm:"column:poster_url"       json:"poster_url,omitempty"`
	CheckinToken     string         `gorm:"column:checkin_token"    json:"checkin_token,omitempty"`
	OrganizerID      uint           `gorm:"not null"                json:"organizer_id"`
	Organizer        *User          `gorm:"foreignKey:OrganizerID"  json:"organizer,omitempty"`
	CreatedAt        time.Time      `                               json:"created_at"`
	UpdatedAt        time.Time      `                               json:"updated_at"`
}

func (Event) TableName() string { return "events" }

// EventFilter holds query parameters for listing events.
type EventFilter struct {
	City     string
	Category string
	Format   EventFormat
	Search   string
	Tags     []string
	IsFree   *bool
	DateFrom *time.Time
	DateTo   *time.Time
	Page     int
	Limit    int
}

// Favorite links a user bookmark to an event.
type Favorite struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	UserID    uint      `gorm:"not null;uniqueIndex:uq_favorite_user_event" json:"user_id"`
	EventID   uint      `gorm:"not null;uniqueIndex:uq_favorite_user_event" json:"event_id"`
	Event     *Event    `gorm:"foreignKey:EventID" json:"event,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

func (Favorite) TableName() string { return "favorites" }
