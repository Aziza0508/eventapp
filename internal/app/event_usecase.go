package app

import (
	"crypto/rand"
	"encoding/hex"
	"strings"
	"time"

	"eventapp/internal/domain"
	"github.com/lib/pq"
)

// EventUsecase handles business logic for events.
type EventUsecase struct {
	events EventRepository
	users  UserRepository
}

func NewEventUsecase(events EventRepository, users UserRepository) *EventUsecase {
	return &EventUsecase{events: events, users: users}
}

// CreateEventInput holds validated fields for new event creation.
type CreateEventInput struct {
	Title            string
	Description      string
	Category         string
	Tags             []string
	Format           domain.EventFormat
	City             string
	Address          string
	Latitude         *float64
	Longitude        *float64
	OrganizerContact string
	AdditionalInfo   string
	DateStart        time.Time
	DateEnd          *time.Time
	RegDeadline      *time.Time
	Capacity         int
	IsFree           bool
	Price            float64
	PosterURL        string
	OrganizerID      uint
}

// CreateEvent creates a new event. Only approved organizers may call this.
func (uc *EventUsecase) CreateEvent(in CreateEventInput) (*domain.Event, error) {
	if err := uc.requireApproved(in.OrganizerID); err != nil {
		return nil, err
	}

	if strings.TrimSpace(in.Title) == "" {
		return nil, domain.NewAppError("VALIDATION_ERROR", "title is required", nil)
	}
	if in.DateStart.IsZero() {
		return nil, domain.NewAppError("VALIDATION_ERROR", "date_start is required", nil)
	}
	if in.Format != "" && !in.Format.IsValid() {
		return nil, domain.NewAppError("VALIDATION_ERROR", "invalid format value", nil)
	}

	token, err := generateCheckinToken()
	if err != nil {
		return nil, err
	}

	event := &domain.Event{
		Title:            strings.TrimSpace(in.Title),
		Description:      in.Description,
		Category:         in.Category,
		Tags:             pq.StringArray(cleanTags(in.Tags)),
		Format:           in.Format,
		City:             in.City,
		Address:          in.Address,
		Latitude:         in.Latitude,
		Longitude:        in.Longitude,
		OrganizerContact: in.OrganizerContact,
		AdditionalInfo:   in.AdditionalInfo,
		DateStart:        in.DateStart,
		DateEnd:          in.DateEnd,
		RegDeadline:      in.RegDeadline,
		Capacity:         in.Capacity,
		IsFree:           in.IsFree,
		Price:            in.Price,
		PosterURL:        in.PosterURL,
		CheckinToken:     token,
		OrganizerID:      in.OrganizerID,
	}

	if err := uc.events.Create(event); err != nil {
		return nil, err
	}
	return event, nil
}

// ListEvents returns a paginated, filtered list of events.
func (uc *EventUsecase) ListEvents(filter domain.EventFilter) ([]domain.Event, int64, error) {
	if filter.Limit <= 0 || filter.Limit > 100 {
		filter.Limit = 20
	}
	if filter.Page <= 0 {
		filter.Page = 1
	}
	return uc.events.List(filter)
}

// GetEvent returns a single event by ID.
func (uc *EventUsecase) GetEvent(id uint) (*domain.Event, error) {
	event, err := uc.events.GetByID(id)
	if err != nil {
		return nil, domain.ErrNotFound
	}
	return event, nil
}

// GetEventFreeSeats returns how many seats remain (0 = unlimited).
func (uc *EventUsecase) GetEventFreeSeats(eventID uint) (int, error) {
	event, err := uc.events.GetByID(eventID)
	if err != nil {
		return 0, err
	}
	if event.Capacity == 0 {
		return 0, nil // unlimited
	}
	count, err := uc.events.CountRegistrations(eventID)
	if err != nil {
		return 0, err
	}
	free := event.Capacity - int(count)
	if free < 0 {
		free = 0
	}
	return free, nil
}

// UpdateEventInput holds fields that can be updated.
type UpdateEventInput struct {
	Title            string
	Description      string
	Category         string
	Tags             []string
	Format           domain.EventFormat
	City             string
	Address          string
	Latitude         *float64
	Longitude        *float64
	OrganizerContact string
	AdditionalInfo   string
	DateStart        time.Time
	DateEnd          *time.Time
	RegDeadline      *time.Time
	Capacity         int
	IsFree           *bool
	Price            *float64
	PosterURL        string
}

// UpdateEvent updates an event. Verifies caller is the approved organizer.
func (uc *EventUsecase) UpdateEvent(callerID, eventID uint, in UpdateEventInput) (*domain.Event, error) {
	if err := uc.requireApproved(callerID); err != nil {
		return nil, err
	}

	event, err := uc.events.GetByID(eventID)
	if err != nil {
		return nil, domain.ErrNotFound
	}
	if event.OrganizerID != callerID {
		return nil, domain.ErrForbidden
	}

	if strings.TrimSpace(in.Title) != "" {
		event.Title = strings.TrimSpace(in.Title)
	}
	if in.Description != "" {
		event.Description = in.Description
	}
	if in.Category != "" {
		event.Category = in.Category
	}
	if in.Tags != nil {
		event.Tags = pq.StringArray(cleanTags(in.Tags))
	}
	if in.Format != "" {
		if !in.Format.IsValid() {
			return nil, domain.NewAppError("VALIDATION_ERROR", "invalid format value", nil)
		}
		event.Format = in.Format
	}
	if in.City != "" {
		event.City = in.City
	}
	if in.Address != "" {
		event.Address = in.Address
	}
	if in.Latitude != nil {
		event.Latitude = in.Latitude
	}
	if in.Longitude != nil {
		event.Longitude = in.Longitude
	}
	if in.OrganizerContact != "" {
		event.OrganizerContact = in.OrganizerContact
	}
	if in.AdditionalInfo != "" {
		event.AdditionalInfo = in.AdditionalInfo
	}
	if !in.DateStart.IsZero() {
		event.DateStart = in.DateStart
	}
	if in.DateEnd != nil {
		event.DateEnd = in.DateEnd
	}
	if in.RegDeadline != nil {
		event.RegDeadline = in.RegDeadline
	}
	if in.Capacity >= 0 {
		event.Capacity = in.Capacity
	}
	if in.IsFree != nil {
		event.IsFree = *in.IsFree
	}
	if in.Price != nil {
		event.Price = *in.Price
	}
	if in.PosterURL != "" {
		event.PosterURL = in.PosterURL
	}

	if err := uc.events.Update(event); err != nil {
		return nil, err
	}
	return event, nil
}

// DeleteEvent soft-deletes an event. Verifies caller is the approved organizer.
func (uc *EventUsecase) DeleteEvent(callerID, eventID uint) error {
	if err := uc.requireApproved(callerID); err != nil {
		return err
	}

	event, err := uc.events.GetByID(eventID)
	if err != nil {
		return domain.ErrNotFound
	}
	if event.OrganizerID != callerID {
		return domain.ErrForbidden
	}
	return uc.events.Delete(eventID)
}

// requireApproved checks that the given user has been approved.
func (uc *EventUsecase) requireApproved(userID uint) error {
	user, err := uc.users.GetByID(userID)
	if err != nil {
		return domain.ErrNotFound
	}
	if !user.Approved {
		return domain.ErrAccountPending
	}
	return nil
}

// generateCheckinToken creates a random 32-byte hex token for QR check-in.
func generateCheckinToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// cleanTags trims and deduplicates tags.
func cleanTags(tags []string) []string {
	if tags == nil {
		return nil
	}
	seen := make(map[string]bool)
	out := make([]string, 0, len(tags))
	for _, t := range tags {
		t = strings.TrimSpace(t)
		if t != "" && !seen[strings.ToLower(t)] {
			seen[strings.ToLower(t)] = true
			out = append(out, t)
		}
	}
	return out
}
