package app_test

import (
	"context"
	"fmt"
	"testing"

	"eventapp/internal/app"
	"eventapp/internal/domain"
)

// newAuthUC is a test helper that constructs an AuthUsecase with mocks.
func newAuthUC(repo *mockUserRepo) (*app.AuthUsecase, *mockRefreshStore) {
	store := newMockRefreshStore()
	mockRTCounter = 0
	uc := app.NewAuthUsecase(repo, mockJWT{}, store, mockGenerateRT, mockHashRT, nil)
	return uc, store
}

// ---------- Register tests ----------

func TestRegister_Success(t *testing.T) {
	uc, _ := newAuthUC(newMockUserRepo())

	user, tokens, err := uc.Register(app.RegisterInput{
		Email:    "student@example.com",
		Password: "secret123",
		FullName: "Asel Bekova",
	})

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if user.Email != "student@example.com" {
		t.Errorf("unexpected email: %s", user.Email)
	}
	if user.Role != domain.RoleStudent {
		t.Errorf("expected role student, got %s", user.Role)
	}
	if !user.Approved {
		t.Error("student should be approved immediately")
	}
	if tokens.AccessToken == "" {
		t.Error("expected non-empty access token")
	}
	if tokens.RefreshToken == "" {
		t.Error("expected non-empty refresh token")
	}
}

func TestRegister_DefaultsToStudent(t *testing.T) {
	uc, _ := newAuthUC(newMockUserRepo())

	user, _, err := uc.Register(app.RegisterInput{
		Email:    "org@example.com",
		Password: "secret123",
		FullName: "Bekzat Org",
		Role:     "", // no role provided
	})

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if user.Role != domain.RoleStudent {
		t.Errorf("expected student, got %s", user.Role)
	}
}

func TestRegister_OrganizerRolePreserved(t *testing.T) {
	uc, _ := newAuthUC(newMockUserRepo())

	user, _, err := uc.Register(app.RegisterInput{
		Email:    "org@example.com",
		Password: "secret123",
		FullName: "Bekzat Org",
		Role:     domain.RoleOrganizer,
	})

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if user.Role != domain.RoleOrganizer {
		t.Errorf("expected organizer, got %s", user.Role)
	}
}

func TestRegister_OrganizerNotApprovedByDefault(t *testing.T) {
	uc, _ := newAuthUC(newMockUserRepo())

	user, _, err := uc.Register(app.RegisterInput{
		Email:    "org@example.com",
		Password: "secret123",
		FullName: "Bekzat Org",
		Role:     domain.RoleOrganizer,
	})

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if user.Approved {
		t.Error("organizer should NOT be approved by default")
	}
}

func TestRegister_AdminRoleDowngradedToStudent(t *testing.T) {
	uc, _ := newAuthUC(newMockUserRepo())

	user, _, err := uc.Register(app.RegisterInput{
		Email:    "evil@example.com",
		Password: "secret123",
		FullName: "Evil Admin",
		Role:     domain.RoleAdmin,
	})

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if user.Role != domain.RoleStudent {
		t.Errorf("admin role should be downgraded to student, got %s", user.Role)
	}
}

func TestRegister_DuplicateEmail(t *testing.T) {
	repo := newMockUserRepo()
	uc, _ := newAuthUC(repo)

	input := app.RegisterInput{
		Email:    "dup@example.com",
		Password: "secret123",
		FullName: "Duplicate",
	}

	if _, _, err := uc.Register(input); err != nil {
		t.Fatalf("first register failed: %v", err)
	}

	_, _, err := uc.Register(input)
	if err == nil {
		t.Fatal("expected error for duplicate email, got nil")
	}

	var appErr *domain.AppError
	if !isAppError(err, &appErr) || appErr.Code != "ALREADY_EXISTS" {
		t.Errorf("expected ALREADY_EXISTS error, got %v", err)
	}
}

func TestRegister_ShortPassword(t *testing.T) {
	uc, _ := newAuthUC(newMockUserRepo())

	_, _, err := uc.Register(app.RegisterInput{
		Email:    "x@x.com",
		Password: "12",
		FullName: "X",
	})

	if err == nil {
		t.Fatal("expected validation error for short password")
	}
}

// ---------- Login tests ----------

func TestLogin_Success(t *testing.T) {
	repo := newMockUserRepo()
	uc, _ := newAuthUC(repo)

	_, _, _ = uc.Register(app.RegisterInput{
		Email:    "login@example.com",
		Password: "mypassword",
		FullName: "Login User",
	})

	user, tokens, err := uc.Login(app.LoginInput{
		Email:    "login@example.com",
		Password: "mypassword",
	})

	if err != nil {
		t.Fatalf("login failed: %v", err)
	}
	if user == nil || user.Email != "login@example.com" {
		t.Error("unexpected user")
	}
	if tokens.AccessToken == "" {
		t.Error("expected non-empty access token")
	}
	if tokens.RefreshToken == "" {
		t.Error("expected non-empty refresh token")
	}
}

func TestLogin_WrongPassword(t *testing.T) {
	repo := newMockUserRepo()
	uc, _ := newAuthUC(repo)

	_, _, _ = uc.Register(app.RegisterInput{
		Email:    "p@example.com",
		Password: "correct",
		FullName: "P",
	})

	_, _, err := uc.Login(app.LoginInput{Email: "p@example.com", Password: "wrong"})
	if err == nil {
		t.Fatal("expected error for wrong password")
	}
}

func TestLogin_UnknownEmail(t *testing.T) {
	uc, _ := newAuthUC(newMockUserRepo())
	_, _, err := uc.Login(app.LoginInput{Email: "ghost@x.com", Password: "any"})
	if err == nil {
		t.Fatal("expected error for unknown user")
	}
}

// ---------- Refresh token tests ----------

func TestRefresh_Success(t *testing.T) {
	repo := newMockUserRepo()
	uc, _ := newAuthUC(repo)

	_, tokens, _ := uc.Register(app.RegisterInput{
		Email:    "r@example.com",
		Password: "secret123",
		FullName: "Refresh User",
	})

	user, newTokens, err := uc.RefreshWithUserID(context.Background(), 1, tokens.RefreshToken)
	if err != nil {
		t.Fatalf("refresh failed: %v", err)
	}
	if user == nil {
		t.Fatal("expected user")
	}
	if newTokens.AccessToken == "" || newTokens.RefreshToken == "" {
		t.Error("expected non-empty tokens")
	}
	// Old token should be different from new (rotation)
	if tokens.RefreshToken == newTokens.RefreshToken {
		t.Error("expected rotated refresh token")
	}
}

func TestRefresh_OldTokenRevoked(t *testing.T) {
	repo := newMockUserRepo()
	uc, _ := newAuthUC(repo)

	_, tokens, _ := uc.Register(app.RegisterInput{
		Email:    "r@example.com",
		Password: "secret123",
		FullName: "Refresh User",
	})

	// First refresh succeeds
	_, _, err := uc.RefreshWithUserID(context.Background(), 1, tokens.RefreshToken)
	if err != nil {
		t.Fatalf("first refresh failed: %v", err)
	}

	// Second refresh with same token should fail (revoked after rotation)
	_, _, err = uc.RefreshWithUserID(context.Background(), 1, tokens.RefreshToken)
	if err == nil {
		t.Fatal("expected error when reusing revoked refresh token")
	}
	var appErr *domain.AppError
	if !isAppError(err, &appErr) || appErr.Code != "TOKEN_REVOKED" {
		t.Errorf("expected TOKEN_REVOKED, got %v", err)
	}
}

func TestRefresh_EmptyToken(t *testing.T) {
	uc, _ := newAuthUC(newMockUserRepo())

	_, _, err := uc.RefreshWithUserID(context.Background(), 1, "")
	if err == nil {
		t.Fatal("expected validation error for empty refresh token")
	}
}

func TestRefresh_InvalidToken(t *testing.T) {
	uc, _ := newAuthUC(newMockUserRepo())

	_, _, err := uc.RefreshWithUserID(context.Background(), 1, "does-not-exist")
	if err == nil {
		t.Fatal("expected error for invalid refresh token")
	}
}

// ---------- Logout tests ----------

func TestLogout_RevokesRefreshToken(t *testing.T) {
	repo := newMockUserRepo()
	uc, store := newAuthUC(repo)

	_, tokens, _ := uc.Register(app.RegisterInput{
		Email:    "lo@example.com",
		Password: "secret123",
		FullName: "Logout User",
	})

	// Verify token exists
	hash := mockHashRT(tokens.RefreshToken)
	exists, _ := store.Exists(context.Background(), 1, hash)
	if !exists {
		t.Fatal("refresh token should exist before logout")
	}

	// Logout
	err := uc.Logout(context.Background(), 1, tokens.RefreshToken)
	if err != nil {
		t.Fatalf("logout failed: %v", err)
	}

	// Verify token is revoked
	exists, _ = store.Exists(context.Background(), 1, hash)
	if exists {
		t.Error("refresh token should be revoked after logout")
	}
}

func TestLogout_EmptyTokenIsNoop(t *testing.T) {
	uc, _ := newAuthUC(newMockUserRepo())
	err := uc.Logout(context.Background(), 1, "")
	if err != nil {
		t.Fatalf("empty logout should not error, got %v", err)
	}
}

// ---------- Helpers ----------

// isAppError is a helper to unwrap *domain.AppError.
func isAppError(err error, target **domain.AppError) bool {
	if appErr, ok := err.(*domain.AppError); ok {
		*target = appErr
		return true
	}
	return false
}

// Ensure mockRTCounter produces unique tokens across tests.
func init() {
	_ = fmt.Sprintf // avoid unused import if needed
}
