package app_test

import (
	"testing"
	"time"

	"eventapp/internal/app"
	"eventapp/internal/domain"
)

func seedEventForFav(eventRepo *mockEventRepo) uint {
	e := &domain.Event{
		Title:     "Test Event",
		DateStart: time.Now().Add(24 * time.Hour),
	}
	eventRepo.Create(e)
	return e.ID
}

func TestFavorite_AddAndList(t *testing.T) {
	favRepo := newMockFavRepo()
	eventRepo := newMockEventRepo()
	uc := app.NewFavoriteUsecase(favRepo, eventRepo)

	eventID := seedEventForFav(eventRepo)

	if err := uc.AddFavorite(1, eventID); err != nil {
		t.Fatalf("add favorite failed: %v", err)
	}

	// Check exists
	exists, _ := uc.IsFavorite(1, eventID)
	if !exists {
		t.Error("expected favorite to exist")
	}

	// List
	favs, err := uc.ListFavorites(1)
	if err != nil {
		t.Fatalf("list favorites failed: %v", err)
	}
	if len(favs) != 1 {
		t.Errorf("expected 1 favorite, got %d", len(favs))
	}
}

func TestFavorite_DuplicateAdd(t *testing.T) {
	favRepo := newMockFavRepo()
	eventRepo := newMockEventRepo()
	uc := app.NewFavoriteUsecase(favRepo, eventRepo)

	eventID := seedEventForFav(eventRepo)

	uc.AddFavorite(1, eventID)
	err := uc.AddFavorite(1, eventID)
	if err == nil {
		t.Fatal("expected ALREADY_EXISTS error")
	}
	var appErr *domain.AppError
	if !isAppError(err, &appErr) || appErr.Code != "ALREADY_EXISTS" {
		t.Errorf("expected ALREADY_EXISTS, got %v", err)
	}
}

func TestFavorite_Remove(t *testing.T) {
	favRepo := newMockFavRepo()
	eventRepo := newMockEventRepo()
	uc := app.NewFavoriteUsecase(favRepo, eventRepo)

	eventID := seedEventForFav(eventRepo)

	uc.AddFavorite(1, eventID)
	if err := uc.RemoveFavorite(1, eventID); err != nil {
		t.Fatalf("remove failed: %v", err)
	}

	exists, _ := uc.IsFavorite(1, eventID)
	if exists {
		t.Error("favorite should not exist after removal")
	}
}

func TestFavorite_RemoveNonExistent(t *testing.T) {
	favRepo := newMockFavRepo()
	eventRepo := newMockEventRepo()
	uc := app.NewFavoriteUsecase(favRepo, eventRepo)

	err := uc.RemoveFavorite(1, 999)
	if err == nil {
		t.Fatal("expected NOT_FOUND error")
	}
}

func TestFavorite_AddEventNotFound(t *testing.T) {
	favRepo := newMockFavRepo()
	eventRepo := newMockEventRepo()
	uc := app.NewFavoriteUsecase(favRepo, eventRepo)

	err := uc.AddFavorite(1, 999)
	if err == nil {
		t.Fatal("expected NOT_FOUND error")
	}
}
