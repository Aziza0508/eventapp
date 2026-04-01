package handler

import (
	"encoding/csv"
	"fmt"
	"net/http"
	"time"

	"eventapp/internal/app"
	"eventapp/internal/delivery/http/dto"
	"eventapp/internal/delivery/http/middleware"
	"eventapp/internal/delivery/http/response"

	"github.com/gin-gonic/gin"
)

// RegistrationHandler handles event registration endpoints.
type RegistrationHandler struct {
	uc *app.RegistrationUsecase
}

func NewRegistrationHandler(uc *app.RegistrationUsecase) *RegistrationHandler {
	return &RegistrationHandler{uc: uc}
}

// Apply godoc
// @Summary      Apply to an event
// @Description  Creates a registration. If seats available → pending. If full → waitlisted. Duplicate → 409.
// @Tags         registrations
// @Produce      json
// @Security     BearerAuth
// @Param        id  path  int  true  "Event ID"
// @Success      201  {object}  domain.Registration
// @Failure      400  {object}  response.ErrorBody
// @Failure      409  {object}  response.ErrorBody
// @Router       /api/events/{id}/apply [post]
func (h *RegistrationHandler) Apply(c *gin.Context) {
	eventID, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid event id", nil)
		return
	}

	userID := middleware.UserIDFromCtx(c)

	reg, err := h.uc.ApplyToEvent(userID, eventID)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.Created(c, reg)
}

// Cancel godoc
// @Summary      Cancel own registration
// @Description  User cancels their own pending/approved/waitlisted registration. If an approved seat is freed, the next waitlisted user is auto-promoted.
// @Tags         registrations
// @Produce      json
// @Security     BearerAuth
// @Param        id  path  int  true  "Registration ID"
// @Success      200  {object}  domain.Registration
// @Failure      400  {object}  response.ErrorBody
// @Failure      403  {object}  response.ErrorBody
// @Failure      404  {object}  response.ErrorBody
// @Router       /api/registrations/{id} [delete]
func (h *RegistrationHandler) Cancel(c *gin.Context) {
	regID, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid registration id", nil)
		return
	}

	userID := middleware.UserIDFromCtx(c)

	reg, err := h.uc.CancelRegistration(userID, regID)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, reg)
}

// MyRegistrations godoc
// @Summary      Get my registrations
// @Description  Returns all event registrations for the current user with event details
// @Tags         registrations
// @Produce      json
// @Security     BearerAuth
// @Success      200  {array}  domain.Registration
// @Router       /api/my/events [get]
func (h *RegistrationHandler) MyRegistrations(c *gin.Context) {
	userID := middleware.UserIDFromCtx(c)

	regs, err := h.uc.GetMyRegistrations(userID)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, regs)
}

// Participants godoc
// @Summary      List participants for an event
// @Description  Returns all registrations. Caller must be the event organizer.
// @Tags         registrations
// @Produce      json
// @Security     BearerAuth
// @Param        id  path  int  true  "Event ID"
// @Success      200  {array}  domain.Registration
// @Failure      403  {object}  response.ErrorBody
// @Router       /api/events/{id}/participants [get]
func (h *RegistrationHandler) Participants(c *gin.Context) {
	eventID, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid event id", nil)
		return
	}

	callerID := middleware.UserIDFromCtx(c)

	regs, err := h.uc.GetParticipants(callerID, eventID)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, regs)
}

// ExportCSV godoc
// @Summary      Export participants as CSV
// @Description  Downloads participant list as CSV. Organizer/admin only.
// @Tags         registrations
// @Produce      text/csv
// @Security     BearerAuth
// @Param        id  path  int  true  "Event ID"
// @Success      200  {file}  file
// @Failure      403  {object}  response.ErrorBody
// @Router       /api/events/{id}/participants/export.csv [get]
func (h *RegistrationHandler) ExportCSV(c *gin.Context) {
	eventID, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid event id", nil)
		return
	}

	callerID := middleware.UserIDFromCtx(c)

	regs, err := h.uc.GetParticipants(callerID, eventID)
	if err != nil {
		response.Err(c, err)
		return
	}

	filename := fmt.Sprintf("participants_event_%d_%s.csv", eventID, time.Now().Format("20060102"))
	c.Header("Content-Type", "text/csv")
	c.Header("Content-Disposition", "attachment; filename="+filename)

	w := csv.NewWriter(c.Writer)
	defer w.Flush()

	// Header row
	w.Write([]string{"Name", "Email", "School", "City", "Grade", "Status", "Checked In", "Applied At"})

	for _, reg := range regs {
		name := ""
		email := ""
		school := ""
		city := ""
		grade := ""
		if reg.User != nil {
			name = reg.User.FullName
			email = reg.User.Email
			school = reg.User.School
			city = reg.User.City
			if reg.User.Grade > 0 {
				grade = fmt.Sprintf("%d", reg.User.Grade)
			}
		}

		checkedIn := ""
		if reg.CheckedInAt != nil {
			checkedIn = reg.CheckedInAt.Format(time.RFC3339)
		}

		w.Write([]string{
			name, email, school, city, grade,
			string(reg.Status), checkedIn,
			reg.CreatedAt.Format(time.RFC3339),
		})
	}

	c.Status(http.StatusOK)
}

// UpdateStatus godoc
// @Summary      Update registration status
// @Description  Organizer changes registration status. Enforces state-machine transitions.
// @Tags         registrations
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        id    path  int                        true  "Registration ID"
// @Param        body  body  dto.UpdateStatusRequest    true  "New status"
// @Success      200  {object}  domain.Registration
// @Failure      400  {object}  response.ErrorBody
// @Failure      403  {object}  response.ErrorBody
// @Router       /api/registrations/{id}/status [patch]
func (h *RegistrationHandler) UpdateStatus(c *gin.Context) {
	regID, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid registration id", nil)
		return
	}

	var req dto.UpdateStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, "status is required", nil)
		return
	}

	callerID := middleware.UserIDFromCtx(c)

	reg, err := h.uc.UpdateStatus(callerID, regID, req.Status)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, reg)
}

// CheckinByQR godoc
// @Summary      Check in a participant via QR code
// @Description  Validates the QR HMAC and transitions approved → checked_in. Organizer only.
// @Tags         registrations
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        id    path  int                 true  "Registration ID"
// @Param        body  body  dto.CheckinRequest  true  "QR HMAC payload"
// @Success      200  {object}  domain.Registration
// @Failure      400  {object}  response.ErrorBody
// @Failure      403  {object}  response.ErrorBody
// @Router       /api/registrations/{id}/checkin [patch]
func (h *RegistrationHandler) CheckinByQR(c *gin.Context) {
	regID, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid registration id", nil)
		return
	}

	var req dto.CheckinRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, "qr_hmac is required", nil)
		return
	}

	callerID := middleware.UserIDFromCtx(c)

	reg, err := h.uc.CheckinByQR(callerID, regID, req.QRHMAC)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, reg)
}

// GetQRPayload godoc
// @Summary      Get QR payload for a registration
// @Description  Returns the QR payload string for the user's approved registration. Used by iOS to generate QR code.
// @Tags         registrations
// @Produce      json
// @Security     BearerAuth
// @Param        id  path  int  true  "Registration ID"
// @Success      200  {object}  map[string]string
// @Failure      400  {object}  response.ErrorBody
// @Failure      403  {object}  response.ErrorBody
// @Router       /api/registrations/{id}/qr [get]
func (h *RegistrationHandler) GetQRPayload(c *gin.Context) {
	regID, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid registration id", nil)
		return
	}

	userID := middleware.UserIDFromCtx(c)

	payload, err := h.uc.GetQRPayload(userID, regID)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, gin.H{"qr_payload": payload})
}
