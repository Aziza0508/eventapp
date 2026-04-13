package app

import (
	"strings"

	"eventapp/internal/domain"
	"github.com/lib/pq"
)

// ProfileUsecase handles user profile read/update logic.
// Separated from AuthUsecase to prepare for a future User Profile microservice boundary.
type ProfileUsecase struct {
	users UserRepository
}

func NewProfileUsecase(users UserRepository) *ProfileUsecase {
	return &ProfileUsecase{users: users}
}

// GetProfile returns the full profile for the given user ID.
func (uc *ProfileUsecase) GetProfile(userID uint) (*domain.User, error) {
	user, err := uc.users.GetByID(userID)
	if err != nil {
		return nil, domain.ErrNotFound
	}
	return user, nil
}

// UpdateProfileInput holds the fields that can be updated on a profile.
// Zero/empty values mean "do not change" for strings and slices.
// Booleans use pointers so nil = "do not change".
type UpdateProfileInput struct {
	FullName  string
	Phone     string
	School    string
	City      string
	Grade     int
	Bio       string
	AvatarURL string
	Interests []string

	// Privacy — pointers so nil = don't change, non-nil = set value.
	VisibleToOrganizers *bool
	VisibleToSchool     *bool
}

// UpdateProfile applies partial updates to a user's profile.
func (uc *ProfileUsecase) UpdateProfile(userID uint, in UpdateProfileInput) (*domain.User, error) {
	user, err := uc.users.GetByID(userID)
	if err != nil {
		return nil, domain.ErrNotFound
	}

	// Validate and apply fields.
	if v := strings.TrimSpace(in.FullName); v != "" {
		if len(v) < 2 {
			return nil, domain.NewAppError("VALIDATION_ERROR", "full_name must be at least 2 characters", nil)
		}
		if len(v) > 200 {
			return nil, domain.NewAppError("VALIDATION_ERROR", "full_name must not exceed 200 characters", nil)
		}
		user.FullName = v
	}

	if v := strings.TrimSpace(in.Phone); v != "" {
		if len(v) > 20 {
			return nil, domain.NewAppError("VALIDATION_ERROR", "phone must not exceed 20 characters", nil)
		}
		user.Phone = v
	}

	if v := strings.TrimSpace(in.School); v != "" {
		user.School = v
	}

	if v := strings.TrimSpace(in.City); v != "" {
		user.City = v
	}

	if in.Grade != 0 {
		if in.Grade < 1 || in.Grade > 12 {
			return nil, domain.NewAppError("VALIDATION_ERROR", "grade must be between 1 and 12", nil)
		}
		user.Grade = in.Grade
	}

	if v := strings.TrimSpace(in.Bio); v != "" {
		if len(v) > 1000 {
			return nil, domain.NewAppError("VALIDATION_ERROR", "bio must not exceed 1000 characters", nil)
		}
		user.Bio = v
	}

	if v := strings.TrimSpace(in.AvatarURL); v != "" {
		user.AvatarURL = v
	}

	if in.Interests != nil {
		if len(in.Interests) > 20 {
			return nil, domain.NewAppError("VALIDATION_ERROR", "at most 20 interests allowed", nil)
		}
		// Trim and deduplicate.
		seen := make(map[string]bool)
		clean := make([]string, 0, len(in.Interests))
		for _, tag := range in.Interests {
			t := strings.TrimSpace(tag)
			if t != "" && !seen[strings.ToLower(t)] {
				seen[strings.ToLower(t)] = true
				clean = append(clean, t)
			}
		}
		user.Interests = pq.StringArray(clean)
	}

	// Privacy settings — only update if explicitly provided.
	if in.VisibleToOrganizers != nil {
		user.PrivacySettings.VisibleToOrganizers = *in.VisibleToOrganizers
	}
	if in.VisibleToSchool != nil {
		user.PrivacySettings.VisibleToSchool = *in.VisibleToSchool
	}

	if err := uc.users.Update(user); err != nil {
		return nil, err
	}

	return user, nil
}
