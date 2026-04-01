package postgres

import (
	"eventapp/internal/domain"

	"gorm.io/gorm"
)

// AuditLogRepo implements app.AuditLogRepository using GORM.
type AuditLogRepo struct{ db *gorm.DB }

func NewAuditLogRepo(db *gorm.DB) *AuditLogRepo { return &AuditLogRepo{db: db} }

func (r *AuditLogRepo) Create(entry *domain.AuditLog) error {
	return r.db.Create(entry).Error
}

func (r *AuditLogRepo) List(limit int) ([]domain.AuditLog, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	var out []domain.AuditLog
	err := r.db.Order("created_at DESC").Limit(limit).Find(&out).Error
	return out, err
}

func (r *AuditLogRepo) ListByActor(actorID uint, limit int) ([]domain.AuditLog, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	var out []domain.AuditLog
	err := r.db.Where("actor_id = ?", actorID).
		Order("created_at DESC").Limit(limit).Find(&out).Error
	return out, err
}
