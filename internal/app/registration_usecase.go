package app

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"eventapp/internal/domain"
)

// RegistrationUsecase handles event registration business logic.
type RegistrationUsecase struct {
	regs    RegistrationRepository
	events  EventRepository
	notifUC *NotificationUsecase // nil-safe — notifications are optional
}

func NewRegistrationUsecase(regs RegistrationRepository, events EventRepository, notifUC *NotificationUsecase) *RegistrationUsecase {
	return &RegistrationUsecase{regs: regs, events: events, notifUC: notifUC}
}

// ApplyToEvent registers a student for an event.
// If seats are available → pending. If full → waitlisted.
func (uc *RegistrationUsecase) ApplyToEvent(userID, eventID uint) (*domain.Registration, error) {
	event, err := uc.events.GetByID(eventID)
	if err != nil {
		return nil, domain.ErrNotFound
	}

	// Check registration deadline.
	if event.RegDeadline != nil && time.Now().After(*event.RegDeadline) {
		return nil, domain.NewAppError("VALIDATION_ERROR", "registration deadline has passed", nil)
	}

	// Prevent duplicate (DB unique constraint also enforces this).
	existing, _ := uc.regs.GetByUserAndEvent(userID, eventID)
	if existing != nil && existing.ID != 0 {
		// Allow re-apply if previously cancelled.
		if existing.Status != domain.StatusCancelled {
			return nil, domain.ErrAlreadyExists
		}
		// Reactivate cancelled registration.
		return uc.reactivateRegistration(existing, event)
	}

	// Determine initial status based on capacity.
	status := domain.StatusPending
	if event.Capacity > 0 {
		count, err := uc.events.CountRegistrations(eventID)
		if err != nil {
			return nil, err
		}
		if int(count) >= event.Capacity {
			status = domain.StatusWaitlisted
		}
	}

	reg := &domain.Registration{
		UserID:  userID,
		EventID: eventID,
		Status:  status,
	}

	if err := uc.regs.Create(reg); err != nil {
		return nil, domain.ErrAlreadyExists
	}

	// Notify user of submission.
	if uc.notifUC != nil {
		uc.notifUC.NotifyRegistrationSubmitted(userID, event.Title, eventID)
		uc.notifUC.NotifyOrganizerNewRegistration(event.OrganizerID, event.Title, eventID)
	}

	return reg, nil
}

// reactivateRegistration re-opens a cancelled registration.
func (uc *RegistrationUsecase) reactivateRegistration(reg *domain.Registration, event *domain.Event) (*domain.Registration, error) {
	status := domain.StatusPending
	if event.Capacity > 0 {
		count, _ := uc.events.CountRegistrations(event.ID)
		if int(count) >= event.Capacity {
			status = domain.StatusWaitlisted
		}
	}
	reg.Status = status
	reg.CheckedInAt = nil
	if err := uc.regs.Update(reg); err != nil {
		return nil, err
	}
	return reg, nil
}

// CancelRegistration allows a user to cancel their own registration.
// If a seat opens up, the first waitlisted user is auto-promoted.
func (uc *RegistrationUsecase) CancelRegistration(userID, regID uint) (*domain.Registration, error) {
	reg, err := uc.regs.GetByID(regID)
	if err != nil {
		return nil, domain.ErrNotFound
	}

	// Must be the owner.
	if reg.UserID != userID {
		return nil, domain.ErrForbidden
	}

	if !reg.Status.IsCancellableByUser() {
		return nil, domain.NewAppError(
			"INVALID_STATUS_TRANSITION",
			"cannot cancel registration in status "+string(reg.Status),
			nil,
		)
	}

	wasApproved := reg.Status == domain.StatusApproved

	reg.Status = domain.StatusCancelled
	if err := uc.regs.Update(reg); err != nil {
		return nil, err
	}

	// Auto-promote next waitlisted if a confirmed seat was freed.
	if wasApproved {
		uc.promoteNextWaitlisted(reg.EventID)
	}

	return reg, nil
}

// promoteNextWaitlisted promotes the oldest waitlisted registration to approved.
func (uc *RegistrationUsecase) promoteNextWaitlisted(eventID uint) {
	next, err := uc.regs.FirstWaitlisted(eventID)
	if err != nil || next == nil {
		return
	}
	next.Status = domain.StatusApproved
	uc.regs.Update(next)

	// Notify the promoted user.
	if uc.notifUC != nil {
		event, err := uc.events.GetByID(eventID)
		if err == nil {
			uc.notifUC.NotifyWaitlistPromoted(next.UserID, event.Title, eventID)
		}
	}
}

// GetMyRegistrations returns all event registrations for a student.
func (uc *RegistrationUsecase) GetMyRegistrations(userID uint) ([]domain.Registration, error) {
	return uc.regs.ListByUser(userID)
}

// GetParticipants returns all registrations for an event. Caller must be the organizer.
func (uc *RegistrationUsecase) GetParticipants(callerID, eventID uint) ([]domain.Registration, error) {
	event, err := uc.events.GetByID(eventID)
	if err != nil {
		return nil, domain.ErrNotFound
	}
	if event.OrganizerID != callerID {
		return nil, domain.ErrForbidden
	}
	return uc.regs.ListByEvent(eventID)
}

// UpdateStatus changes a registration status. Enforces state-machine rules.
// Caller must be the organizer of the event.
func (uc *RegistrationUsecase) UpdateStatus(callerID, regID uint, newStatus domain.RegStatus) (*domain.Registration, error) {
	if !newStatus.IsValid() {
		return nil, domain.NewAppError("VALIDATION_ERROR", "invalid status value", nil)
	}

	reg, err := uc.regs.GetByID(regID)
	if err != nil {
		return nil, domain.ErrNotFound
	}

	event, err := uc.events.GetByID(reg.EventID)
	if err != nil {
		return nil, domain.ErrNotFound
	}
	if event.OrganizerID != callerID {
		return nil, domain.ErrForbidden
	}

	if !reg.Status.CanTransitionTo(newStatus) {
		return nil, domain.NewAppError(
			"INVALID_STATUS_TRANSITION",
			"cannot transition from "+string(reg.Status)+" to "+string(newStatus),
			nil,
		)
	}

	reg.Status = newStatus

	// Record check-in timestamp.
	if newStatus == domain.StatusCheckedIn {
		now := time.Now()
		reg.CheckedInAt = &now
	}

	if err := uc.regs.Update(reg); err != nil {
		return nil, err
	}

	// Fire notification for status changes the user cares about.
	if uc.notifUC != nil {
		switch newStatus {
		case domain.StatusApproved:
			uc.notifUC.NotifyRegistrationApproved(reg.UserID, event.Title, event.ID)
		case domain.StatusRejected:
			uc.notifUC.NotifyRegistrationRejected(reg.UserID, event.Title, event.ID)
		}
	}

	return reg, nil
}

// CheckinByQR validates a QR payload and checks in the registration.
// QR payload format: "eventapp://checkin/{regID}/{hmac}"
// The HMAC is computed over the registration ID using the event's checkin_token as key.
func (uc *RegistrationUsecase) CheckinByQR(callerID uint, regID uint, qrHMAC string) (*domain.Registration, error) {
	reg, err := uc.regs.GetByID(regID)
	if err != nil {
		return nil, domain.ErrNotFound
	}

	event, err := uc.events.GetByID(reg.EventID)
	if err != nil {
		return nil, domain.ErrNotFound
	}

	// Only the event organizer can check in.
	if event.OrganizerID != callerID {
		return nil, domain.ErrForbidden
	}

	// Verify HMAC signature.
	expectedMAC := ComputeCheckinHMAC(reg.ID, event.CheckinToken)
	if !hmac.Equal([]byte(qrHMAC), []byte(expectedMAC)) {
		return nil, domain.NewAppError("VALIDATION_ERROR", "invalid QR code", nil)
	}

	// Must be in approved status to check in.
	if reg.Status != domain.StatusApproved {
		return nil, domain.NewAppError(
			"INVALID_STATUS_TRANSITION",
			"only approved registrations can be checked in, current: "+string(reg.Status),
			nil,
		)
	}

	now := time.Now()
	reg.Status = domain.StatusCheckedIn
	reg.CheckedInAt = &now

	if err := uc.regs.Update(reg); err != nil {
		return nil, err
	}

	if uc.notifUC != nil {
		uc.notifUC.NotifyRegistrationCheckedIn(reg.UserID, event.Title, event.ID)
	}

	return reg, nil
}

// ComputeCheckinHMAC generates the HMAC for a registration's QR code.
func ComputeCheckinHMAC(regID uint, eventToken string) string {
	mac := hmac.New(sha256.New, []byte(eventToken))
	mac.Write([]byte(fmt.Sprintf("%d", regID)))
	return hex.EncodeToString(mac.Sum(nil))
}

// GetQRPayload returns the QR payload string for a registration.
// Only the registration owner can request this.
func (uc *RegistrationUsecase) GetQRPayload(userID, regID uint) (string, error) {
	reg, err := uc.regs.GetByID(regID)
	if err != nil {
		return "", domain.ErrNotFound
	}
	if reg.UserID != userID {
		return "", domain.ErrForbidden
	}
	if reg.Status != domain.StatusApproved {
		return "", domain.NewAppError("VALIDATION_ERROR", "QR code only available for approved registrations", nil)
	}

	event, err := uc.events.GetByID(reg.EventID)
	if err != nil {
		return "", domain.ErrNotFound
	}

	hmacStr := ComputeCheckinHMAC(reg.ID, event.CheckinToken)
	payload := fmt.Sprintf("eventapp://checkin/%d/%s", reg.ID, hmacStr)
	return payload, nil
}
