package app_test

import (
	"testing"
	"time"

	"eventapp/internal/app"
	"eventapp/internal/domain"
)

func approvedOrganizer(repo *mockUserRepo) uint {
	repo.Create(&domain.User{
		Email: "org@test.com", FullName: "Test Org",
		Role: domain.RoleOrganizer, Approved: true,
	})
	return 1
}

func TestCreateEvent_WithNewFields(t *testing.T) {
	userRepo := newMockUserRepo()
	eventRepo := newMockEventRepo()
	orgID := approvedOrganizer(userRepo)
	uc := app.NewEventUsecase(eventRepo, userRepo)

	lat := 43.238949
	lng := 76.945465

	event, err := uc.CreateEvent(app.CreateEventInput{
		Title:            "Robotics Workshop",
		Description:      "Learn robotics",
		Category:         "Robotics",
		Tags:             []string{"STEM", "Robotics", " stem "}, // duplicate check
		Format:           domain.FormatOffline,
		City:             "Almaty",
		Address:          "123 Main St",
		Latitude:         &lat,
		Longitude:        &lng,
		OrganizerContact: "org@test.com",
		AdditionalInfo:   "Bring a laptop",
		DateStart:        time.Now().Add(24 * time.Hour),
		RegDeadline:      ptrTime(time.Now().Add(12 * time.Hour)),
		Capacity:         50,
		IsFree:           false,
		Price:            5000,
		OrganizerID:      orgID,
	})
	if err != nil {
		t.Fatalf("create event failed: %v", err)
	}

	if event.Address != "123 Main St" {
		t.Errorf("expected address, got %s", event.Address)
	}
	if event.Latitude == nil || *event.Latitude != lat {
		t.Error("expected latitude")
	}
	if event.IsFree {
		t.Error("expected is_free=false")
	}
	if event.Price != 5000 {
		t.Errorf("expected price 5000, got %f", event.Price)
	}
	if event.CheckinToken == "" {
		t.Error("expected non-empty checkin_token")
	}
	if event.RegDeadline == nil {
		t.Error("expected reg_deadline")
	}
	// Tags should be deduplicated
	if len(event.Tags) != 2 {
		t.Errorf("expected 2 tags (deduped), got %d: %v", len(event.Tags), event.Tags)
	}
}

func TestCreateEvent_CheckinTokenUnique(t *testing.T) {
	userRepo := newMockUserRepo()
	eventRepo := newMockEventRepo()
	orgID := approvedOrganizer(userRepo)
	uc := app.NewEventUsecase(eventRepo, userRepo)

	e1, _ := uc.CreateEvent(app.CreateEventInput{
		Title: "E1", DateStart: time.Now().Add(24 * time.Hour), OrganizerID: orgID,
	})
	e2, _ := uc.CreateEvent(app.CreateEventInput{
		Title: "E2", DateStart: time.Now().Add(48 * time.Hour), OrganizerID: orgID,
	})

	if e1.CheckinToken == e2.CheckinToken {
		t.Error("checkin tokens should be unique per event")
	}
}

func TestUpdateEvent_NewFields(t *testing.T) {
	userRepo := newMockUserRepo()
	eventRepo := newMockEventRepo()
	orgID := approvedOrganizer(userRepo)
	uc := app.NewEventUsecase(eventRepo, userRepo)

	event, _ := uc.CreateEvent(app.CreateEventInput{
		Title: "Original", DateStart: time.Now().Add(24 * time.Hour), OrganizerID: orgID, IsFree: true,
	})

	isFree := false
	price := 1500.0
	updated, err := uc.UpdateEvent(orgID, event.ID, app.UpdateEventInput{
		Address: "456 New St",
		IsFree:  &isFree,
		Price:   &price,
		Tags:    []string{"Science", "STEM"},
	})
	if err != nil {
		t.Fatalf("update failed: %v", err)
	}
	if updated.Address != "456 New St" {
		t.Errorf("expected address update, got %s", updated.Address)
	}
	if updated.IsFree {
		t.Error("expected is_free=false")
	}
	if updated.Price != 1500 {
		t.Errorf("expected price 1500, got %f", updated.Price)
	}
	if len(updated.Tags) != 2 {
		t.Errorf("expected 2 tags, got %v", updated.Tags)
	}
}

func ptrTime(t time.Time) *time.Time { return &t }
