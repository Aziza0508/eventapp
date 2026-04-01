package dto

import "eventapp/internal/domain"

// UpdateProfileRequest is the body for PUT /api/me.
// All fields are optional — omitted fields are not changed.
type UpdateProfileRequest struct {
	FullName  string   `json:"full_name"`
	Phone     string   `json:"phone"`
	School    string   `json:"school"`
	City      string   `json:"city"`
	Grade     int      `json:"grade"`
	Bio       string   `json:"bio"`
	AvatarURL string   `json:"avatar_url"`
	Interests []string `json:"interests"`

	Privacy *PrivacySettingsRequest `json:"privacy,omitempty"`
}

// PrivacySettingsRequest holds privacy toggle values.
type PrivacySettingsRequest struct {
	VisibleToOrganizers *bool `json:"visible_to_organizers,omitempty"`
	VisibleToSchool     *bool `json:"visible_to_school,omitempty"`
}

// PrivacySettingsResponse is the privacy section in the user profile response.
type PrivacySettingsResponse struct {
	VisibleToOrganizers bool `json:"visible_to_organizers"`
	VisibleToSchool     bool `json:"visible_to_school"`
}

// FullUserProfile is the enriched user profile returned from GET/PUT /api/me.
type FullUserProfile struct {
	ID        uint            `json:"id"`
	Email     string          `json:"email"`
	FullName  string          `json:"full_name"`
	Role      domain.UserRole `json:"role"`
	Approved  bool            `json:"approved"`
	Phone     string          `json:"phone,omitempty"`
	City      string          `json:"city,omitempty"`
	School    string          `json:"school,omitempty"`
	Grade     int             `json:"grade,omitempty"`
	Bio       string          `json:"bio,omitempty"`
	AvatarURL string          `json:"avatar_url,omitempty"`
	Interests []string        `json:"interests"`
	Privacy   PrivacySettingsResponse `json:"privacy"`
	CreatedAt string          `json:"created_at"`
}

// FullProfileFromDomain converts a domain.User to FullUserProfile.
func FullProfileFromDomain(u *domain.User) FullUserProfile {
	interests := make([]string, 0)
	if u.Interests != nil {
		interests = u.Interests
	}

	return FullUserProfile{
		ID:        u.ID,
		Email:     u.Email,
		FullName:  u.FullName,
		Role:      u.Role,
		Approved:  u.Approved,
		Phone:     u.Phone,
		City:      u.City,
		School:    u.School,
		Grade:     u.Grade,
		Bio:       u.Bio,
		AvatarURL: u.AvatarURL,
		Interests: interests,
		Privacy: PrivacySettingsResponse{
			VisibleToOrganizers: u.PrivacySettings.VisibleToOrganizers,
			VisibleToSchool:     u.PrivacySettings.VisibleToSchool,
		},
		CreatedAt: u.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}
