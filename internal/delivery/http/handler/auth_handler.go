package handler

import (
	"net/http"
	"strings"

	"eventapp/internal/app"
	"eventapp/internal/delivery/http/dto"
	"eventapp/internal/delivery/http/middleware"
	"eventapp/internal/delivery/http/response"
	"eventapp/internal/domain"

	"github.com/gin-gonic/gin"
)

// JWTExpiredParser can extract userID from an expired-but-signed JWT.
type JWTExpiredParser interface {
	ValidateIgnoringExpiry(tokenString string) (uint, domain.UserRole, error)
}

// AuthHandler handles authentication and profile endpoints.
type AuthHandler struct {
	uc           *app.AuthUsecase
	users        app.UserRepository
	jwtParser    JWTExpiredParser
}

// NewAuthHandler creates a new auth handler.
func NewAuthHandler(uc *app.AuthUsecase, users app.UserRepository, jwtParser JWTExpiredParser) *AuthHandler {
	return &AuthHandler{uc: uc, users: users, jwtParser: jwtParser}
}

// Register godoc
// @Summary      Register a new user
// @Description  Creates a student or organizer account and returns access + refresh tokens.
// @Description  Organizer accounts require admin approval before they can create events.
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body  body      dto.RegisterRequest  true  "Registration payload"
// @Success      201   {object}  dto.AuthResponse
// @Failure      400   {object}  response.ErrorBody
// @Failure      409   {object}  response.ErrorBody
// @Router       /auth/register [post]
func (h *AuthHandler) Register(c *gin.Context) {
	var req dto.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, err.Error(), nil)
		return
	}

	user, tokens, err := h.uc.Register(app.RegisterInput{
		Email:    req.Email,
		Password: req.Password,
		FullName: req.FullName,
		Role:     req.Role,
		City:     req.City,
		School:   req.School,
		Grade:    req.Grade,
	})
	if err != nil {
		response.Err(c, err)
		return
	}

	c.JSON(http.StatusCreated, dto.AuthResponse{
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
		User:         dto.UserFromDomain(user),
	})
}

// Login godoc
// @Summary      Login
// @Description  Authenticates a user and returns access + refresh tokens
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body  body      dto.LoginRequest  true  "Login credentials"
// @Success      200   {object}  dto.AuthResponse
// @Failure      400   {object}  response.ErrorBody
// @Failure      401   {object}  response.ErrorBody
// @Router       /auth/login [post]
func (h *AuthHandler) Login(c *gin.Context) {
	var req dto.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, err.Error(), nil)
		return
	}

	user, tokens, err := h.uc.Login(app.LoginInput{
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, dto.AuthResponse{
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
		User:         dto.UserFromDomain(user),
	})
}

// Refresh godoc
// @Summary      Refresh access token
// @Description  Exchanges a valid refresh token for a new access + refresh token pair (rotation).
// @Description  The old refresh token is revoked. Send the current access token in the Authorization header
// @Description  (even if expired) so the server can identify the user.
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        Authorization  header  string              true  "Bearer {access_token} (may be expired)"
// @Param        body           body    dto.RefreshRequest  true  "Refresh token"
// @Success      200  {object}  dto.AuthResponse
// @Failure      400  {object}  response.ErrorBody
// @Failure      401  {object}  response.ErrorBody
// @Router       /auth/refresh [post]
func (h *AuthHandler) Refresh(c *gin.Context) {
	var req dto.RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, err.Error(), nil)
		return
	}

	// Extract userID from the (possibly expired) access token.
	header := c.GetHeader("Authorization")
	tokenStr := strings.TrimPrefix(header, "Bearer ")
	tokenStr = strings.TrimSpace(tokenStr)
	if tokenStr == "" {
		response.Err(c, domain.NewAppError("UNAUTHORIZED", "Authorization header with access token is required for refresh", nil))
		return
	}

	userID, _, err := h.jwtParser.ValidateIgnoringExpiry(tokenStr)
	if err != nil {
		response.Err(c, err)
		return
	}

	user, tokens, err := h.uc.RefreshWithUserID(c.Request.Context(), userID, req.RefreshToken)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, dto.AuthResponse{
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
		User:         dto.UserFromDomain(user),
	})
}

// Logout godoc
// @Summary      Logout
// @Description  Revokes the given refresh token. The access token remains valid until it expires.
// @Tags         auth
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body  body  dto.LogoutRequest  true  "Refresh token to revoke"
// @Success      200   {object}  map[string]string
// @Failure      400   {object}  response.ErrorBody
// @Failure      401   {object}  response.ErrorBody
// @Router       /auth/logout [post]
func (h *AuthHandler) Logout(c *gin.Context) {
	var req dto.LogoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, err.Error(), nil)
		return
	}

	userID := middleware.UserIDFromCtx(c)
	if err := h.uc.Logout(c.Request.Context(), userID, req.RefreshToken); err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, gin.H{"message": "logged out"})
}

// NOTE: GET /api/me is now handled by ProfileHandler.GetProfile
