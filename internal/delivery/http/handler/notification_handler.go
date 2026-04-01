package handler

import (
	"strconv"

	"eventapp/internal/app"
	"eventapp/internal/delivery/http/middleware"
	"eventapp/internal/delivery/http/response"

	"github.com/gin-gonic/gin"
)

// NotificationHandler handles notification and device token endpoints.
type NotificationHandler struct {
	uc *app.NotificationUsecase
}

func NewNotificationHandler(uc *app.NotificationUsecase) *NotificationHandler {
	return &NotificationHandler{uc: uc}
}

// List godoc
// @Summary      List notifications
// @Description  Returns recent notifications for the authenticated user
// @Tags         notifications
// @Produce      json
// @Security     BearerAuth
// @Param        unread_only  query  bool  false  "Only unread"
// @Param        limit        query  int   false  "Max results (default 50)"
// @Success      200  {array}  domain.Notification
// @Router       /api/notifications [get]
func (h *NotificationHandler) List(c *gin.Context) {
	userID := middleware.UserIDFromCtx(c)
	unreadOnly := c.Query("unread_only") == "true"
	limit := 50
	if v, err := strconv.Atoi(c.Query("limit")); err == nil && v > 0 {
		limit = v
	}

	notifs, err := h.uc.ListNotifications(userID, unreadOnly, limit)
	if err != nil {
		response.Err(c, err)
		return
	}
	response.OK(c, notifs)
}

// UnreadCount godoc
// @Summary      Get unread notification count
// @Tags         notifications
// @Produce      json
// @Security     BearerAuth
// @Success      200  {object}  map[string]int64
// @Router       /api/notifications/unread-count [get]
func (h *NotificationHandler) UnreadCount(c *gin.Context) {
	userID := middleware.UserIDFromCtx(c)
	count, err := h.uc.CountUnread(userID)
	if err != nil {
		response.Err(c, err)
		return
	}
	response.OK(c, gin.H{"unread_count": count})
}

// MarkRead godoc
// @Summary      Mark a notification as read
// @Tags         notifications
// @Security     BearerAuth
// @Param        id  path  int  true  "Notification ID"
// @Success      200  {object}  map[string]string
// @Router       /api/notifications/{id}/read [patch]
func (h *NotificationHandler) MarkRead(c *gin.Context) {
	userID := middleware.UserIDFromCtx(c)
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid notification id", nil)
		return
	}
	if err := h.uc.MarkRead(userID, id); err != nil {
		response.Err(c, err)
		return
	}
	response.OK(c, gin.H{"message": "marked as read"})
}

// MarkAllRead godoc
// @Summary      Mark all notifications as read
// @Tags         notifications
// @Security     BearerAuth
// @Success      200  {object}  map[string]string
// @Router       /api/notifications/read-all [post]
func (h *NotificationHandler) MarkAllRead(c *gin.Context) {
	userID := middleware.UserIDFromCtx(c)
	if err := h.uc.MarkAllRead(userID); err != nil {
		response.Err(c, err)
		return
	}
	response.OK(c, gin.H{"message": "all marked as read"})
}

// RegisterDevice godoc
// @Summary      Register APNs device token
// @Tags         notifications
// @Accept       json
// @Security     BearerAuth
// @Param        body  body  registerDeviceRequest  true  "Device token"
// @Success      200  {object}  map[string]string
// @Router       /api/devices [post]
func (h *NotificationHandler) RegisterDevice(c *gin.Context) {
	var req registerDeviceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, "token is required", nil)
		return
	}
	userID := middleware.UserIDFromCtx(c)
	platform := req.Platform
	if platform == "" {
		platform = "ios"
	}
	if err := h.uc.RegisterDevice(userID, req.Token, platform); err != nil {
		response.Err(c, err)
		return
	}
	response.OK(c, gin.H{"message": "device registered"})
}

// UnregisterDevice godoc
// @Summary      Unregister APNs device token
// @Tags         notifications
// @Accept       json
// @Security     BearerAuth
// @Param        body  body  registerDeviceRequest  true  "Device token to remove"
// @Success      200  {object}  map[string]string
// @Router       /api/devices [delete]
func (h *NotificationHandler) UnregisterDevice(c *gin.Context) {
	var req registerDeviceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, "token is required", nil)
		return
	}
	userID := middleware.UserIDFromCtx(c)
	if err := h.uc.UnregisterDevice(userID, req.Token); err != nil {
		response.Err(c, err)
		return
	}
	response.OK(c, gin.H{"message": "device unregistered"})
}

type registerDeviceRequest struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform"` // "ios" (default) or "android"
}
