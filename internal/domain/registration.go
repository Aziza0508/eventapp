package domain

import "time"

// RegStatus represents the lifecycle state of a registration.
//
// State diagram:
//
//	                    ┌──────────┐
//	  apply ──────────► │ pending  │
//	                    └────┬─────┘
//	                ┌────────┼────────────┐
//	                ▼        ▼            ▼
//	         ┌──────────┐ ┌──────────┐ ┌──────────┐
//	         │ approved │ │ rejected │ │waitlisted│
//	         └────┬─────┘ └──────────┘ └────┬─────┘
//	              │                          │ (auto-promote)
//	              │    ┌────────────┐        │
//	              │    │ cancelled  │◄───────┘ (user cancel)
//	              │    └────────────┘
//	              ▼
//	         ┌──────────┐
//	         │checked_in│
//	         └────┬─────┘
//	              ▼
//	         ┌──────────┐
//	         │completed │
//	         └──────────┘
//
// NOTE: "draft" is intentionally omitted — the current UX submits immediately on apply.
// The model is extensible: adding "draft" later only requires a new constant + transitions.
type RegStatus string

const (
	StatusPending    RegStatus = "pending"
	StatusApproved   RegStatus = "approved"
	StatusRejected   RegStatus = "rejected"
	StatusWaitlisted RegStatus = "waitlisted"
	StatusCheckedIn  RegStatus = "checked_in"
	StatusCompleted  RegStatus = "completed"
	StatusCancelled  RegStatus = "cancelled"
)

func (s RegStatus) IsValid() bool {
	switch s {
	case StatusPending, StatusApproved, StatusRejected,
		StatusWaitlisted, StatusCheckedIn, StatusCompleted, StatusCancelled:
		return true
	}
	return false
}

// AllowedTransitions defines the valid state machine transitions.
//
// Organizer-driven:
//
//	pending    → approved, rejected, waitlisted
//	approved   → rejected, checked_in
//	rejected   → approved
//	waitlisted → approved, rejected
//	checked_in → completed
//
// User-driven (via Cancel endpoint):
//
//	pending    → cancelled
//	approved   → cancelled
//	waitlisted → cancelled
var AllowedTransitions = map[RegStatus][]RegStatus{
	StatusPending:    {StatusApproved, StatusRejected, StatusWaitlisted, StatusCancelled},
	StatusApproved:   {StatusRejected, StatusCheckedIn, StatusCancelled},
	StatusRejected:   {StatusApproved},
	StatusWaitlisted: {StatusApproved, StatusRejected, StatusCancelled},
	StatusCheckedIn:  {StatusCompleted},
	// completed and cancelled are terminal states
}

// CanTransitionTo checks whether transitioning from current to next is valid.
func (s RegStatus) CanTransitionTo(next RegStatus) bool {
	allowed, ok := AllowedTransitions[s]
	if !ok {
		return false
	}
	for _, a := range allowed {
		if a == next {
			return true
		}
	}
	return false
}

// IsCancellableByUser returns true if the user (not organizer) can cancel this registration.
func (s RegStatus) IsCancellableByUser() bool {
	switch s {
	case StatusPending, StatusApproved, StatusWaitlisted:
		return true
	}
	return false
}

// CountsTowardCapacity returns true if this registration occupies a seat.
func (s RegStatus) CountsTowardCapacity() bool {
	switch s {
	case StatusPending, StatusApproved, StatusCheckedIn, StatusCompleted:
		return true
	}
	return false
}

// Registration links a student to an event with a status.
type Registration struct {
	ID          uint       `gorm:"primaryKey"                                      json:"id"`
	UserID      uint       `gorm:"not null;uniqueIndex:idx_reg_user_event"         json:"user_id"`
	User        *User      `gorm:"foreignKey:UserID"                               json:"user,omitempty"`
	EventID     uint       `gorm:"not null;uniqueIndex:idx_reg_user_event"         json:"event_id"`
	Event       *Event     `gorm:"foreignKey:EventID"                              json:"event,omitempty"`
	Status      RegStatus  `gorm:"default:'pending'"                               json:"status"`
	CheckedInAt *time.Time `gorm:"column:checked_in_at"                            json:"checked_in_at,omitempty"`
	CreatedAt   time.Time  `                                                        json:"created_at"`
	UpdatedAt   time.Time  `                                                        json:"updated_at"`
}

func (Registration) TableName() string { return "registrations" }
