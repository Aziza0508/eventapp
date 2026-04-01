package postgres

import (
	"errors"

	"eventapp/internal/domain"

	"gorm.io/gorm"
)

// FavoriteRepo implements app.FavoriteRepository using GORM.
type FavoriteRepo struct{ db *gorm.DB }

func NewFavoriteRepo(db *gorm.DB) *FavoriteRepo { return &FavoriteRepo{db: db} }

func (r *FavoriteRepo) Add(fav *domain.Favorite) error {
	return r.db.Create(fav).Error
}

func (r *FavoriteRepo) Remove(userID, eventID uint) error {
	result := r.db.Where("user_id = ? AND event_id = ?", userID, eventID).
		Delete(&domain.Favorite{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *FavoriteRepo) Exists(userID, eventID uint) (bool, error) {
	var count int64
	err := r.db.Model(&domain.Favorite{}).
		Where("user_id = ? AND event_id = ?", userID, eventID).
		Count(&count).Error
	return count > 0, err
}

func (r *FavoriteRepo) ListByUser(userID uint) ([]domain.Favorite, error) {
	var favs []domain.Favorite
	err := r.db.Where("user_id = ?", userID).
		Preload("Event").Preload("Event.Organizer").
		Order("created_at DESC").
		Find(&favs).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return favs, err
}
