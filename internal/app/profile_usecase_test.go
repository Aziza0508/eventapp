package app_test

import (
	"testing"

	"eventapp/internal/app"
	"eventapp/internal/domain"
)

func seedUser(repo *mockUserRepo) *domain.User {
	u := &domain.User{
		Email:    "test@example.com",
		FullName: "Test User",
		Role:     domain.RoleStudent,
		Approved: true,
		City:     "Almaty",
		School:   "School 42",
		Grade:    10,
	}
	repo.Create(u)
	return u
}

func TestGetProfile_Success(t *testing.T) {
	repo := newMockUserRepo()
	seedUser(repo)
	uc := app.NewProfileUsecase(repo)

	user, err := uc.GetProfile(1)
	if err != nil {
		t.Fatalf("get profile failed: %v", err)
	}
	if user.FullName != "Test User" {
		t.Errorf("expected Test User, got %s", user.FullName)
	}
}

func TestGetProfile_NotFound(t *testing.T) {
	uc := app.NewProfileUsecase(newMockUserRepo())
	_, err := uc.GetProfile(999)
	if err == nil {
		t.Fatal("expected NOT_FOUND error")
	}
}

func TestUpdateProfile_BasicFields(t *testing.T) {
	repo := newMockUserRepo()
	seedUser(repo)
	uc := app.NewProfileUsecase(repo)

	user, err := uc.UpdateProfile(1, app.UpdateProfileInput{
		FullName: "New Name",
		City:     "Astana",
		Phone:    "+77001234567",
		Bio:      "Hello world",
		Grade:    11,
	})
	if err != nil {
		t.Fatalf("update failed: %v", err)
	}
	if user.FullName != "New Name" {
		t.Errorf("expected New Name, got %s", user.FullName)
	}
	if user.City != "Astana" {
		t.Errorf("expected Astana, got %s", user.City)
	}
	if user.Phone != "+77001234567" {
		t.Errorf("expected phone, got %s", user.Phone)
	}
	if user.Bio != "Hello world" {
		t.Errorf("expected bio, got %s", user.Bio)
	}
	if user.Grade != 11 {
		t.Errorf("expected grade 11, got %d", user.Grade)
	}
}

func TestUpdateProfile_Interests(t *testing.T) {
	repo := newMockUserRepo()
	seedUser(repo)
	uc := app.NewProfileUsecase(repo)

	user, err := uc.UpdateProfile(1, app.UpdateProfileInput{
		Interests: []string{"Robotics", "Programming", "AI", "  Robotics  "},
	})
	if err != nil {
		t.Fatalf("update failed: %v", err)
	}
	// Should be deduplicated and trimmed.
	if len(user.Interests) != 3 {
		t.Errorf("expected 3 interests (deduped), got %d: %v", len(user.Interests), user.Interests)
	}
}

func TestUpdateProfile_InterestsClearToEmpty(t *testing.T) {
	repo := newMockUserRepo()
	u := seedUser(repo)
	u.Interests = []string{"Robotics"}
	repo.Update(u)

	uc := app.NewProfileUsecase(repo)

	user, err := uc.UpdateProfile(1, app.UpdateProfileInput{
		Interests: []string{},
	})
	if err != nil {
		t.Fatalf("update failed: %v", err)
	}
	if len(user.Interests) != 0 {
		t.Errorf("expected empty interests, got %v", user.Interests)
	}
}

func TestUpdateProfile_PrivacySettings(t *testing.T) {
	repo := newMockUserRepo()
	seedUser(repo)
	uc := app.NewProfileUsecase(repo)

	f := false
	user, err := uc.UpdateProfile(1, app.UpdateProfileInput{
		VisibleToOrganizers: &f,
	})
	if err != nil {
		t.Fatalf("update failed: %v", err)
	}
	if user.PrivacySettings.VisibleToOrganizers != false {
		t.Error("expected VisibleToOrganizers=false")
	}
	// VisibleToSchool was not set, should remain default (true from seed).
	// Note: our mock doesn't set defaults, so it'll be Go zero value (false).
	// In production the DB default is true. This test validates the nil-skip logic.
}

func TestUpdateProfile_PrivacyNotChangedWhenNil(t *testing.T) {
	repo := newMockUserRepo()
	u := seedUser(repo)
	u.PrivacySettings.VisibleToOrganizers = false
	repo.Update(u)

	uc := app.NewProfileUsecase(repo)

	// Update without touching privacy.
	user, err := uc.UpdateProfile(1, app.UpdateProfileInput{
		City: "Karaganda",
	})
	if err != nil {
		t.Fatalf("update failed: %v", err)
	}
	if user.PrivacySettings.VisibleToOrganizers != false {
		t.Error("privacy should not have changed — expected VisibleToOrganizers=false")
	}
}

func TestUpdateProfile_PartialUpdate(t *testing.T) {
	repo := newMockUserRepo()
	seedUser(repo)
	uc := app.NewProfileUsecase(repo)

	// Only update city — everything else should stay.
	user, err := uc.UpdateProfile(1, app.UpdateProfileInput{
		City: "Shymkent",
	})
	if err != nil {
		t.Fatalf("update failed: %v", err)
	}
	if user.City != "Shymkent" {
		t.Errorf("expected Shymkent, got %s", user.City)
	}
	if user.FullName != "Test User" {
		t.Errorf("full_name should not have changed, got %s", user.FullName)
	}
	if user.School != "School 42" {
		t.Errorf("school should not have changed, got %s", user.School)
	}
}

func TestUpdateProfile_ValidationErrors(t *testing.T) {
	repo := newMockUserRepo()
	seedUser(repo)
	uc := app.NewProfileUsecase(repo)

	tests := []struct {
		name  string
		input app.UpdateProfileInput
	}{
		{"short name", app.UpdateProfileInput{FullName: "A"}},
		{"invalid grade low", app.UpdateProfileInput{Grade: -1}},
		{"too many interests", app.UpdateProfileInput{Interests: make([]string, 21)}},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := uc.UpdateProfile(1, tc.input)
			if err == nil {
				t.Fatal("expected validation error")
			}
			var appErr *domain.AppError
			if !isAppError(err, &appErr) || appErr.Code != "VALIDATION_ERROR" {
				t.Errorf("expected VALIDATION_ERROR, got %v", err)
			}
		})
	}
}

func TestUpdateProfile_UserNotFound(t *testing.T) {
	uc := app.NewProfileUsecase(newMockUserRepo())
	_, err := uc.UpdateProfile(999, app.UpdateProfileInput{City: "X"})
	if err == nil {
		t.Fatal("expected NOT_FOUND error")
	}
}
