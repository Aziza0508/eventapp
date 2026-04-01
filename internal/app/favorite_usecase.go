package app

import "eventapp/internal/domain"

// FavoriteUsecase handles bookmark/favorite business logic.
type FavoriteUsecase struct {
	favs   FavoriteRepository
	events EventRepository
}

func NewFavoriteUsecase(favs FavoriteRepository, events EventRepository) *FavoriteUsecase {
	return &FavoriteUsecase{favs: favs, events: events}
}

// AddFavorite bookmarks an event for the user.
func (uc *FavoriteUsecase) AddFavorite(userID, eventID uint) error {
	// Verify event exists.
	if _, err := uc.events.GetByID(eventID); err != nil {
		return domain.ErrNotFound
	}
	exists, err := uc.favs.Exists(userID, eventID)
	if err != nil {
		return err
	}
	if exists {
		return domain.ErrAlreadyExists
	}
	return uc.favs.Add(&domain.Favorite{UserID: userID, EventID: eventID})
}

// RemoveFavorite removes a bookmark.
func (uc *FavoriteUsecase) RemoveFavorite(userID, eventID uint) error {
	return uc.favs.Remove(userID, eventID)
}

// IsFavorite checks if user has bookmarked the event.
func (uc *FavoriteUsecase) IsFavorite(userID, eventID uint) (bool, error) {
	return uc.favs.Exists(userID, eventID)
}

// ListFavorites returns all bookmarked events for the user.
func (uc *FavoriteUsecase) ListFavorites(userID uint) ([]domain.Favorite, error) {
	return uc.favs.ListByUser(userID)
}
