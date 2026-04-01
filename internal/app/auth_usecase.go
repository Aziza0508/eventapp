package app

import (
	"context"
	"errors"
	"strings"
	"time"

	"eventapp/internal/domain"

	"golang.org/x/crypto/bcrypt"
)

const refreshTokenTTL = 30 * 24 * time.Hour // 30 days

// AuthUsecase handles registration, login, token refresh, and logout business logic.
type AuthUsecase struct {
	users         UserRepository
	jwt           JWTProvider
	refreshStore  RefreshTokenStore
	generateRT    func() (string, error)
	hashRT        func(string) string
}

// NewAuthUsecase creates a new auth usecase.
// generateRT and hashRT are injected to allow testing without crypto.
func NewAuthUsecase(
	users UserRepository,
	jwt JWTProvider,
	refreshStore RefreshTokenStore,
	generateRT func() (string, error),
	hashRT func(string) string,
) *AuthUsecase {
	return &AuthUsecase{
		users:        users,
		jwt:          jwt,
		refreshStore: refreshStore,
		generateRT:   generateRT,
		hashRT:       hashRT,
	}
}

// RegisterInput holds validated user registration data.
type RegisterInput struct {
	Email    string
	Password string
	FullName string
	Role     domain.UserRole // optional; defaults to student
	City     string
	School   string
	Grade    int
}

// TokenPair holds the issued tokens on login/register.
type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

// Register creates a new user account. Returns access + refresh tokens on success.
func (uc *AuthUsecase) Register(in RegisterInput) (*domain.User, *TokenPair, error) {
	// Validate
	if strings.TrimSpace(in.Email) == "" || strings.TrimSpace(in.Password) == "" {
		return nil, nil, domain.ErrValidation
	}
	if len(in.Password) < 6 {
		return nil, nil, domain.NewAppError("VALIDATION_ERROR", "password must be at least 6 characters", nil)
	}

	// Default role
	role := in.Role
	if role == "" {
		role = domain.RoleStudent
	}
	if !role.IsValid() {
		return nil, nil, domain.NewAppError("VALIDATION_ERROR", "invalid role", nil)
	}
	// Prevent privilege escalation via API — admin can only be set manually
	if role == domain.RoleAdmin {
		role = domain.RoleStudent
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, nil, err
	}

	// Organizers require admin approval; students are approved immediately.
	approved := role != domain.RoleOrganizer

	user := &domain.User{
		Email:        strings.ToLower(strings.TrimSpace(in.Email)),
		PasswordHash: string(hash),
		FullName:     strings.TrimSpace(in.FullName),
		Role:         role,
		Approved:     approved,
		City:         in.City,
		School:       in.School,
		Grade:        in.Grade,
	}

	if err := uc.users.Create(user); err != nil {
		// Treat unique violation as conflict
		return nil, nil, domain.ErrAlreadyExists
	}

	tokens, err := uc.issueTokens(user)
	if err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

// LoginInput holds login credentials.
type LoginInput struct {
	Email    string
	Password string
}

// Login validates credentials and returns access + refresh tokens.
func (uc *AuthUsecase) Login(in LoginInput) (*domain.User, *TokenPair, error) {
	user, err := uc.users.GetByEmail(strings.ToLower(strings.TrimSpace(in.Email)))
	if err != nil {
		// Don't leak "email not found" — always say "invalid credentials"
		return nil, nil, domain.NewAppError("UNAUTHORIZED", "invalid credentials", nil)
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(in.Password)); err != nil {
		if errors.Is(err, bcrypt.ErrMismatchedHashAndPassword) {
			return nil, nil, domain.NewAppError("UNAUTHORIZED", "invalid credentials", nil)
		}
		return nil, nil, err
	}

	tokens, err := uc.issueTokens(user)
	if err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

// RefreshWithUserID rotates refresh tokens for a known user.
func (uc *AuthUsecase) RefreshWithUserID(ctx context.Context, userID uint, oldRefreshToken string) (*domain.User, *TokenPair, error) {
	if strings.TrimSpace(oldRefreshToken) == "" {
		return nil, nil, domain.NewAppError("VALIDATION_ERROR", "refresh_token is required", nil)
	}

	oldHash := uc.hashRT(oldRefreshToken)

	// Verify the old refresh token exists in Redis.
	exists, err := uc.refreshStore.Exists(ctx, userID, oldHash)
	if err != nil {
		return nil, nil, err
	}
	if !exists {
		return nil, nil, domain.ErrTokenRevoked
	}

	// Revoke the old token (rotation: one-time use).
	if err := uc.refreshStore.Revoke(ctx, userID, oldHash); err != nil {
		return nil, nil, err
	}

	// Fetch current user state (role may have changed, account may be deleted).
	user, err := uc.users.GetByID(userID)
	if err != nil {
		return nil, nil, domain.NewAppError("UNAUTHORIZED", "user not found", nil)
	}

	tokens, err := uc.issueTokens(user)
	if err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

// Logout revokes the given refresh token.
func (uc *AuthUsecase) Logout(ctx context.Context, userID uint, refreshToken string) error {
	if strings.TrimSpace(refreshToken) == "" {
		return nil // nothing to revoke
	}
	hash := uc.hashRT(refreshToken)
	return uc.refreshStore.Revoke(ctx, userID, hash)
}

// issueTokens generates a new access + refresh token pair and stores the refresh token.
func (uc *AuthUsecase) issueTokens(user *domain.User) (*TokenPair, error) {
	accessToken, err := uc.jwt.Generate(user.ID, user.Role)
	if err != nil {
		return nil, err
	}

	refreshToken, err := uc.generateRT()
	if err != nil {
		return nil, err
	}

	hash := uc.hashRT(refreshToken)
	ctx := context.Background()
	if err := uc.refreshStore.Save(ctx, user.ID, hash, refreshTokenTTL); err != nil {
		return nil, err
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	}, nil
}
