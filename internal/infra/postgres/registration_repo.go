package postgres

import (
	"errors"

	"eventapp/internal/domain"

	"gorm.io/gorm"
)

// RegistrationRepo implements app.RegistrationRepository using GORM.
type RegistrationRepo struct{ db *gorm.DB }

func NewRegistrationRepo(db *gorm.DB) *RegistrationRepo { return &RegistrationRepo{db: db} }

func (r *RegistrationRepo) Create(reg *domain.Registration) error {
	return r.db.Create(reg).Error
}

func (r *RegistrationRepo) GetByID(id uint) (*domain.Registration, error) {
	var reg domain.Registration
	if err := r.db.Preload("Event").Preload("User").First(&reg, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, domain.ErrNotFound
		}
		return nil, err
	}
	return &reg, nil
}

func (r *RegistrationRepo) GetByUserAndEvent(userID, eventID uint) (*domain.Registration, error) {
	var reg domain.Registration
	err := r.db.Where("user_id = ? AND event_id = ?", userID, eventID).First(&reg).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil // not found is OK here
		}
		return nil, err
	}
	return &reg, nil
}

func (r *RegistrationRepo) ListByUser(userID uint) ([]domain.Registration, error) {
	var regs []domain.Registration
	err := r.db.Preload("Event").Preload("Event.Organizer").
		Where("user_id = ?", userID).
		Order("created_at DESC").
		Find(&regs).Error
	return regs, err
}

func (r *RegistrationRepo) ListByEvent(eventID uint) ([]domain.Registration, error) {
	var regs []domain.Registration
	err := r.db.Preload("User").
		Where("event_id = ?", eventID).
		Order("created_at ASC").
		Find(&regs).Error
	return regs, err
}

func (r *RegistrationRepo) Update(reg *domain.Registration) error {
	return r.db.Save(reg).Error
}

func (r *RegistrationRepo) CountByEventAndStatus(eventID uint) (map[domain.RegStatus]int64, error) {
	type row struct {
		Status domain.RegStatus
		Count  int64
	}
	var rows []row
	err := r.db.Model(&domain.Registration{}).
		Select("status, count(*) as count").
		Where("event_id = ?", eventID).
		Group("status").
		Find(&rows).Error
	if err != nil {
		return nil, err
	}
	m := make(map[domain.RegStatus]int64)
	for _, r := range rows {
		m[r.Status] = r.Count
	}
	return m, nil
}

func (r *RegistrationRepo) FirstWaitlisted(eventID uint) (*domain.Registration, error) {
	var reg domain.Registration
	err := r.db.Where("event_id = ? AND status = ?", eventID, domain.StatusWaitlisted).
		Order("created_at ASC").
		First(&reg).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil // no waitlisted — not an error
		}
		return nil, err
	}
	return &reg, nil
}
