package handler

import (
	"eventapp/internal/app"
	"eventapp/internal/delivery/http/middleware"
	"eventapp/internal/delivery/http/response"
	"eventapp/internal/domain"

	"github.com/gin-gonic/gin"
)

// FavoriteHandler handles bookmark/favorite endpoints.
type FavoriteHandler struct {
	uc *app.FavoriteUsecase
}

func NewFavoriteHandler(uc *app.FavoriteUsecase) *FavoriteHandler {
	return &FavoriteHandler{uc: uc}
}

// Add godoc
// @Summary      Bookmark an event
// @Tags         favorites
// @Security     BearerAuth
// @Param        id  path  int  true  "Event ID"
// @Success      201  {object}  map[string]string
// @Failure      404  {object}  response.ErrorBody
// @Failure      409  {object}  response.ErrorBody
// @Router       /api/events/{id}/favorite [post]
func (h *FavoriteHandler) Add(c *gin.Context) {
	eventID, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid event id", nil)
		return
	}

	userID := middleware.UserIDFromCtx(c)
	if err := h.uc.AddFavorite(userID, eventID); err != nil {
		if appErr, ok := err.(*domain.AppError); ok && appErr.Code == "ALREADY_EXISTS" {
			response.OK(c, gin.H{"message": "already bookmarked"})
			return
		}
		response.Err(c, err)
		return
	}

	response.Created(c, gin.H{"message": "bookmarked"})
}

// Remove godoc
// @Summary      Remove bookmark from event
// @Tags         favorites
// @Security     BearerAuth
// @Param        id  path  int  true  "Event ID"
// @Success      200  {object}  map[string]string
// @Failure      404  {object}  response.ErrorBody
// @Router       /api/events/{id}/favorite [delete]
func (h *FavoriteHandler) Remove(c *gin.Context) {
	eventID, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid event id", nil)
		return
	}

	userID := middleware.UserIDFromCtx(c)
	if err := h.uc.RemoveFavorite(userID, eventID); err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, gin.H{"message": "bookmark removed"})
}

// ListMy godoc
// @Summary      List my bookmarked events
// @Tags         favorites
// @Security     BearerAuth
// @Success      200  {array}  domain.Favorite
// @Router       /api/me/favorites [get]
func (h *FavoriteHandler) ListMy(c *gin.Context) {
	userID := middleware.UserIDFromCtx(c)
	favs, err := h.uc.ListFavorites(userID)
	if err != nil {
		response.Err(c, err)
		return
	}
	if favs == nil {
		favs = []domain.Favorite{}
	}
	response.OK(c, favs)
}
