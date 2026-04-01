package handler

import (
	"eventapp/internal/app"
	"eventapp/internal/delivery/http/dto"
	"eventapp/internal/delivery/http/middleware"
	"eventapp/internal/delivery/http/response"

	"github.com/gin-gonic/gin"
)

// ProfileHandler handles user profile endpoints.
type ProfileHandler struct {
	uc *app.ProfileUsecase
}

func NewProfileHandler(uc *app.ProfileUsecase) *ProfileHandler {
	return &ProfileHandler{uc: uc}
}

// GetProfile godoc
// @Summary      Get current user profile
// @Description  Returns the full enriched profile of the authenticated user, including interests and privacy settings
// @Tags         profile
// @Produce      json
// @Security     BearerAuth
// @Success      200  {object}  dto.FullUserProfile
// @Failure      401  {object}  response.ErrorBody
// @Failure      404  {object}  response.ErrorBody
// @Router       /api/me [get]
func (h *ProfileHandler) GetProfile(c *gin.Context) {
	userID := middleware.UserIDFromCtx(c)

	user, err := h.uc.GetProfile(userID)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, dto.FullProfileFromDomain(user))
}

// UpdateProfile godoc
// @Summary      Update current user profile
// @Description  Partially updates the authenticated user's profile. Only provided fields are changed.
// @Tags         profile
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body  body      dto.UpdateProfileRequest  true  "Profile fields to update"
// @Success      200   {object}  dto.FullUserProfile
// @Failure      400   {object}  response.ErrorBody
// @Failure      401   {object}  response.ErrorBody
// @Router       /api/me [put]
func (h *ProfileHandler) UpdateProfile(c *gin.Context) {
	var req dto.UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, err.Error(), nil)
		return
	}

	userID := middleware.UserIDFromCtx(c)

	input := app.UpdateProfileInput{
		FullName:  req.FullName,
		Phone:     req.Phone,
		School:    req.School,
		City:      req.City,
		Grade:     req.Grade,
		Bio:       req.Bio,
		AvatarURL: req.AvatarURL,
		Interests: req.Interests,
	}

	if req.Privacy != nil {
		input.VisibleToOrganizers = req.Privacy.VisibleToOrganizers
		input.VisibleToSchool = req.Privacy.VisibleToSchool
	}

	user, err := h.uc.UpdateProfile(userID, input)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, dto.FullProfileFromDomain(user))
}
