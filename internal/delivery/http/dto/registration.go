package dto

import "eventapp/internal/domain"

// UpdateStatusRequest is the body for PATCH /api/registrations/:id/status.
type UpdateStatusRequest struct {
	Status domain.RegStatus `json:"status" binding:"required"`
}

// CheckinRequest is the body for PATCH /api/registrations/:id/checkin.
type CheckinRequest struct {
	QRHMAC string `json:"qr_hmac" binding:"required"`
}
