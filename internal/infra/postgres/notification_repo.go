package postgres

import (
	"eventapp/internal/domain"

	"gorm.io/gorm"
)

// NotificationRepo implements app.NotificationRepository.
type NotificationRepo struct{ db *gorm.DB }

func NewNotificationRepo(db *gorm.DB) *NotificationRepo {
	return &NotificationRepo{db: db}
}

func (r *NotificationRepo) Create(n *domain.Notification) error {
	return r.db.Create(n).Error
}

func (r *NotificationRepo) ListByUser(userID uint, unreadOnly bool, limit int) ([]domain.Notification, error) {
	q := r.db.Where("user_id = ?", userID)
	if unreadOnly {
		q = q.Where("read = false")
	}
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	var out []domain.Notification
	err := q.Order("created_at DESC").Limit(limit).Find(&out).Error
	return out, err
}

func (r *NotificationRepo) MarkRead(id, userID uint) error {
	return r.db.Model(&domain.Notification{}).
		Where("id = ? AND user_id = ?", id, userID).
		Update("read", true).Error
}

func (r *NotificationRepo) MarkAllRead(userID uint) error {
	return r.db.Model(&domain.Notification{}).
		Where("user_id = ? AND read = false", userID).
		Update("read", true).Error
}

func (r *NotificationRepo) CountUnread(userID uint) (int64, error) {
	var count int64
	err := r.db.Model(&domain.Notification{}).
		Where("user_id = ? AND read = false", userID).
		Count(&count).Error
	return count, err
}

// DeviceTokenRepo implements app.DeviceTokenRepository.
type DeviceTokenRepo struct{ db *gorm.DB }

func NewDeviceTokenRepo(db *gorm.DB) *DeviceTokenRepo {
	return &DeviceTokenRepo{db: db}
}

func (r *DeviceTokenRepo) Upsert(dt *domain.DeviceToken) error {
	// If token exists, update user_id + updated_at; otherwise insert.
	return r.db.Where("token = ?", dt.Token).
		Assign(domain.DeviceToken{UserID: dt.UserID, Platform: dt.Platform}).
		FirstOrCreate(dt).Error
}

func (r *DeviceTokenRepo) Delete(userID uint, token string) error {
	return r.db.Where("user_id = ? AND token = ?", userID, token).
		Delete(&domain.DeviceToken{}).Error
}

func (r *DeviceTokenRepo) ListByUser(userID uint) ([]domain.DeviceToken, error) {
	var out []domain.DeviceToken
	err := r.db.Where("user_id = ?", userID).Find(&out).Error
	return out, err
}
