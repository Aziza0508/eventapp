package postgres

import (
	"errors"

	"eventapp/internal/domain"

	"gorm.io/gorm"
)

// EventRepo implements app.EventRepository using GORM.
type EventRepo struct{ db *gorm.DB }

func NewEventRepo(db *gorm.DB) *EventRepo { return &EventRepo{db: db} }

func (r *EventRepo) Create(event *domain.Event) error {
	return r.db.Create(event).Error
}

func (r *EventRepo) GetByID(id uint) (*domain.Event, error) {
	var e domain.Event
	if err := r.db.Preload("Organizer").First(&e, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, domain.ErrNotFound
		}
		return nil, err
	}
	return &e, nil
}

// List returns paginated events with optional filters.
func (r *EventRepo) List(f domain.EventFilter) ([]domain.Event, int64, error) {
	q := r.db.Model(&domain.Event{})

	if f.City != "" {
		q = q.Where("city ILIKE ?", "%"+f.City+"%")
	}
	if f.Category != "" {
		q = q.Where("category ILIKE ?", "%"+f.Category+"%")
	}
	if f.Format != "" {
		q = q.Where("format = ?", string(f.Format))
	}
	if f.Search != "" {
		pattern := "%" + f.Search + "%"
		q = q.Where("(title ILIKE ? OR description ILIKE ?)", pattern, pattern)
	}
	if f.IsFree != nil {
		q = q.Where("is_free = ?", *f.IsFree)
	}
	if f.DateFrom != nil {
		q = q.Where("date_start >= ?", *f.DateFrom)
	}
	if f.DateTo != nil {
		q = q.Where("date_start <= ?", *f.DateTo)
	}
	if len(f.Tags) > 0 {
		// Postgres array overlap: tags && ARRAY[...]
		q = q.Where("tags && ?::text[]", "{"+joinTags(f.Tags)+"}")
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (f.Page - 1) * f.Limit
	var events []domain.Event
	err := q.Preload("Organizer").
		Order("date_start DESC").
		Offset(offset).
		Limit(f.Limit).
		Find(&events).Error

	return events, total, err
}

func (r *EventRepo) Update(event *domain.Event) error {
	return r.db.Save(event).Error
}

func (r *EventRepo) Delete(id uint) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("event_id = ?", id).Delete(&domain.Favorite{}).Error; err != nil {
			return err
		}
		if err := tx.Where("event_id = ?", id).Delete(&domain.Registration{}).Error; err != nil {
			return err
		}
		return tx.Delete(&domain.Event{}, id).Error
	})
}

func (r *EventRepo) CountRegistrations(eventID uint) (int64, error) {
	var count int64
	err := r.db.Model(&domain.Registration{}).
		Where("event_id = ? AND status != ?", eventID, domain.StatusRejected).
		Count(&count).Error
	return count, err
}

// joinTags formats a Go slice for Postgres array literal.
func joinTags(tags []string) string {
	var s string
	for i, t := range tags {
		if i > 0 {
			s += ","
		}
		s += t
	}
	return s
}
