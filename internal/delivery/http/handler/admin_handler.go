package handler

import (
	"strconv"

	"eventapp/internal/app"
	"eventapp/internal/delivery/http/dto"
	"eventapp/internal/delivery/http/middleware"
	"eventapp/internal/delivery/http/response"
	"eventapp/internal/domain"

	"github.com/gin-gonic/gin"
)

// AdminHandler handles admin-only endpoints.
type AdminHandler struct {
	uc *app.AdminUsecase
}

func NewAdminHandler(uc *app.AdminUsecase) *AdminHandler {
	return &AdminHandler{uc: uc}
}

// ── User listing ─────────────────────────────────────────────────────────────

// ListUsers godoc
// @Summary      List users (admin)
// @Description  Paginated, filterable user list. Filters: role, approved, blocked, search.
// @Tags         admin
// @Produce      json
// @Security     BearerAuth
// @Param        role      query  string  false  "Filter by role"
// @Param        approved  query  string  false  "true or false"
// @Param        blocked   query  string  false  "true or false"
// @Param        search    query  string  false  "Search name/email"
// @Param        page      query  int     false  "Page"
// @Param        limit     query  int     false  "Limit"
// @Success      200  {object}  dto.UserListResponse
// @Router       /api/admin/users [get]
func (h *AdminHandler) ListUsers(c *gin.Context) {
	filter := app.UserFilter{
		Role:   domain.UserRole(c.Query("role")),
		Search: c.Query("search"),
	}
	if v := c.Query("approved"); v == "true" || v == "false" {
		b := v == "true"
		filter.Approved = &b
	}
	if v := c.Query("blocked"); v == "true" || v == "false" {
		b := v == "true"
		filter.Blocked = &b
	}
	if v, err := strconv.Atoi(c.Query("page")); err == nil {
		filter.Page = v
	}
	if v, err := strconv.Atoi(c.Query("limit")); err == nil {
		filter.Limit = v
	}

	users, total, err := h.uc.ListUsers(filter)
	if err != nil {
		response.Err(c, err)
		return
	}

	profiles := make([]dto.UserProfile, len(users))
	for i, u := range users {
		profiles[i] = dto.UserFromDomain(&u)
	}

	response.OK(c, dto.UserListResponse{
		Data:  profiles,
		Total: total,
		Page:  filter.Page,
		Limit: filter.Limit,
	})
}

// ── Organizer approval ───────────────────────────────────────────────────────

// ListPendingOrganizers godoc
// @Summary      List organizers pending approval
// @Tags         admin
// @Produce      json
// @Security     BearerAuth
// @Success      200  {array}  dto.UserProfile
// @Router       /api/admin/organizers/pending [get]
func (h *AdminHandler) ListPendingOrganizers(c *gin.Context) {
	users, err := h.uc.ListPendingOrganizers()
	if err != nil {
		response.Err(c, err)
		return
	}

	profiles := make([]dto.UserProfile, len(users))
	for i, u := range users {
		profiles[i] = dto.UserFromDomain(&u)
	}

	response.OK(c, profiles)
}

// ApproveOrganizer godoc
// @Summary      Approve an organizer
// @Tags         admin
// @Produce      json
// @Security     BearerAuth
// @Param        id  path  int  true  "User ID"
// @Success      200  {object}  dto.UserProfile
// @Router       /api/admin/organizers/{id}/approve [patch]
func (h *AdminHandler) ApproveOrganizer(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid user id", nil)
		return
	}

	adminID := middleware.UserIDFromCtx(c)
	user, err := h.uc.ApproveOrganizer(adminID, id, c.ClientIP())
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, dto.UserFromDomain(user))
}

// RejectOrganizer godoc
// @Summary      Reject an organizer
// @Tags         admin
// @Produce      json
// @Security     BearerAuth
// @Param        id  path  int  true  "User ID"
// @Success      200  {object}  dto.UserProfile
// @Router       /api/admin/organizers/{id}/reject [patch]
func (h *AdminHandler) RejectOrganizer(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid user id", nil)
		return
	}

	adminID := middleware.UserIDFromCtx(c)
	user, err := h.uc.RejectOrganizer(adminID, id, c.ClientIP())
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, dto.UserFromDomain(user))
}

// ── Block / unblock ──────────────────────────────────────────────────────────

// BlockUser godoc
// @Summary      Block a user
// @Description  Prevents the user from logging in. Cannot block admins.
// @Tags         admin
// @Produce      json
// @Security     BearerAuth
// @Param        id  path  int  true  "User ID"
// @Success      200  {object}  dto.UserProfile
// @Router       /api/admin/users/{id}/block [patch]
func (h *AdminHandler) BlockUser(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid user id", nil)
		return
	}

	adminID := middleware.UserIDFromCtx(c)
	user, err := h.uc.BlockUser(adminID, id, c.ClientIP())
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, dto.UserFromDomain(user))
}

// UnblockUser godoc
// @Summary      Unblock a user
// @Tags         admin
// @Produce      json
// @Security     BearerAuth
// @Param        id  path  int  true  "User ID"
// @Success      200  {object}  dto.UserProfile
// @Router       /api/admin/users/{id}/unblock [patch]
func (h *AdminHandler) UnblockUser(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid user id", nil)
		return
	}

	adminID := middleware.UserIDFromCtx(c)
	user, err := h.uc.UnblockUser(adminID, id, c.ClientIP())
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, dto.UserFromDomain(user))
}

// ── Change role ──────────────────────────────────────────────────────────────

// ChangeRole godoc
// @Summary      Change user role
// @Description  Changes a user's role. Cannot promote to admin.
// @Tags         admin
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        id    path  int               true  "User ID"
// @Param        body  body  changeRoleRequest  true  "New role"
// @Success      200  {object}  dto.UserProfile
// @Router       /api/admin/users/{id}/role [patch]
func (h *AdminHandler) ChangeRole(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid user id", nil)
		return
	}

	var req changeRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, "role is required", nil)
		return
	}

	adminID := middleware.UserIDFromCtx(c)
	user, err := h.uc.ChangeUserRole(adminID, id, req.Role, c.ClientIP())
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, dto.UserFromDomain(user))
}

type changeRoleRequest struct {
	Role domain.UserRole `json:"role" binding:"required"`
}

// ── Dashboard ────────────────────────────────────────────────────────────────

// Dashboard godoc
// @Summary      Admin dashboard metrics
// @Description  Returns aggregated stats: total users, events, registrations, pending organizers, recent audit actions.
// @Tags         admin
// @Produce      json
// @Security     BearerAuth
// @Success      200  {object}  app.DashboardStats
// @Router       /api/admin/dashboard [get]
func (h *AdminHandler) Dashboard(c *gin.Context) {
	stats, err := h.uc.GetDashboard()
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, stats)
}

// ── Audit logs ───────────────────────────────────────────────────────────────

// AuditLogs godoc
// @Summary      List recent audit logs
// @Tags         admin
// @Produce      json
// @Security     BearerAuth
// @Param        limit  query  int  false  "Max results (default 50)"
// @Success      200  {array}  domain.AuditLog
// @Router       /api/admin/audit [get]
func (h *AdminHandler) AuditLogs(c *gin.Context) {
	limit := 50
	if v, err := strconv.Atoi(c.Query("limit")); err == nil && v > 0 {
		limit = v
	}

	// Access the audit service via the usecase isn't ideal architecturally,
	// but pragmatic for this admin handler. The audit is exposed only to admins.
	stats, err := h.uc.GetDashboard()
	if err != nil {
		response.Err(c, err)
		return
	}
	logs := stats.RecentActions
	if limit < len(logs) {
		logs = logs[:limit]
	}

	response.OK(c, logs)
}
