package dto

import "eventapp/internal/domain"

// RegisterRequest is the body for POST /auth/register.
type RegisterRequest struct {
	Email    string          `json:"email"     binding:"required,email"`
	Password string          `json:"password"  binding:"required,min=6"`
	FullName string          `json:"full_name" binding:"required"`
	Role     domain.UserRole `json:"role"`   // optional, defaults to student
	City     string          `json:"city"`
	School   string          `json:"school"`
	Grade    int             `json:"grade"`
}

// LoginRequest is the body for POST /auth/login.
type LoginRequest struct {
	Email    string `json:"email"    binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// RefreshRequest is the body for POST /auth/refresh.
type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// LogoutRequest is the body for POST /auth/logout.
type LogoutRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// AuthResponse is returned on successful register/login/refresh.
type AuthResponse struct {
	AccessToken  string      `json:"access_token"`
	RefreshToken string      `json:"refresh_token,omitempty"`
	User         UserProfile `json:"user"`
}

// UserProfile is the public view of a user returned to the client.
type UserProfile struct {
	ID       uint            `json:"id"`
	Email    string          `json:"email"`
	FullName string          `json:"full_name"`
	Role     domain.UserRole `json:"role"`
	Approved bool            `json:"approved"`
	Blocked  bool            `json:"blocked"`
	City     string          `json:"city,omitempty"`
	School   string          `json:"school,omitempty"`
	Grade    int             `json:"grade,omitempty"`
}

// UserFromDomain converts a domain.User to UserProfile DTO.
func UserFromDomain(u *domain.User) UserProfile {
	return UserProfile{
		ID:       u.ID,
		Email:    u.Email,
		FullName: u.FullName,
		Role:     u.Role,
		Approved: u.Approved,
		Blocked:  u.Blocked,
		City:     u.City,
		School:   u.School,
		Grade:    u.Grade,
	}
}

// UserListResponse is the paginated response for admin user listing.
type UserListResponse struct {
	Data  []UserProfile `json:"data"`
	Total int64         `json:"total"`
	Page  int           `json:"page"`
	Limit int           `json:"limit"`
}
