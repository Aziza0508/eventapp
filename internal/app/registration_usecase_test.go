package app_test

import (
	"testing"
	"time"

	"eventapp/internal/app"
	"eventapp/internal/domain"
)

func seedEvent(t *testing.T, eventRepo *mockEventRepo, organizerID uint, capacity int) uint {
	t.Helper()
	e := &domain.Event{
		OrganizerID:  organizerID,
		Title:        "Test Event",
		DateStart:    time.Now().Add(24 * time.Hour),
		Capacity:     capacity,
		CheckinToken: "test-checkin-token",
	}
	if err := eventRepo.Create(e); err != nil {
		t.Fatalf("seed event: %v", err)
	}
	return e.ID
}

func linkedRepos() (*mockRegRepo, *mockEventRepo) {
	regRepo := newMockRegRepo()
	eventRepo := newMockEventRepo()
	eventRepo.regRepo = regRepo
	return regRepo, eventRepo
}

func newRegUC(regRepo *mockRegRepo, eventRepo *mockEventRepo) *app.RegistrationUsecase {
	return app.NewRegistrationUsecase(regRepo, eventRepo, nil)
}

// ── Apply tests ──────────────────────────────────────────────────────────────

func TestApplyToEvent_Success(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	eventID := seedEvent(t, eventRepo, 99, 0)

	reg, err := uc.ApplyToEvent(1, eventID)
	if err != nil {
		t.Fatalf("apply failed: %v", err)
	}
	if reg.Status != domain.StatusPending {
		t.Errorf("expected pending, got %s", reg.Status)
	}
}

func TestApplyToEvent_DuplicateApply(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	eventID := seedEvent(t, eventRepo, 99, 0)

	if _, err := uc.ApplyToEvent(1, eventID); err != nil {
		t.Fatalf("first apply failed: %v", err)
	}

	_, err := uc.ApplyToEvent(1, eventID)
	if err == nil {
		t.Fatal("expected error on duplicate apply")
	}
	var appErr *domain.AppError
	if !isAppError(err, &appErr) || appErr.Code != "ALREADY_EXISTS" {
		t.Errorf("expected ALREADY_EXISTS, got %v", err)
	}
}

func TestApplyToEvent_EventNotFound(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)

	_, err := uc.ApplyToEvent(1, 999)
	if err == nil {
		t.Fatal("expected error for missing event")
	}
}

// ── Waitlist tests ───────────────────────────────────────────────────────────

func TestApplyToEvent_WaitlistedWhenFull(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	eventID := seedEvent(t, eventRepo, 99, 1) // capacity=1

	// First student → pending (occupies the seat)
	reg1, err := uc.ApplyToEvent(1, eventID)
	if err != nil {
		t.Fatalf("first apply failed: %v", err)
	}
	if reg1.Status != domain.StatusPending {
		t.Errorf("expected pending, got %s", reg1.Status)
	}

	// Second student → waitlisted (no seats)
	reg2, err := uc.ApplyToEvent(2, eventID)
	if err != nil {
		t.Fatalf("second apply failed: %v", err)
	}
	if reg2.Status != domain.StatusWaitlisted {
		t.Errorf("expected waitlisted, got %s", reg2.Status)
	}
}

func TestCancelApproved_PromotesWaitlisted(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(99)
	eventID := seedEvent(t, eventRepo, organizerID, 1)

	// Student 1 applies → pending, approve it
	reg1, _ := uc.ApplyToEvent(10, eventID)
	reg1, _ = uc.UpdateStatus(organizerID, reg1.ID, domain.StatusApproved)

	// Student 2 applies → waitlisted
	reg2, _ := uc.ApplyToEvent(20, eventID)
	if reg2.Status != domain.StatusWaitlisted {
		t.Fatalf("expected waitlisted, got %s", reg2.Status)
	}

	// Student 1 cancels → frees seat, student 2 promoted
	_, err := uc.CancelRegistration(10, reg1.ID)
	if err != nil {
		t.Fatalf("cancel failed: %v", err)
	}

	// Verify student 2 is now approved
	promoted := regRepo.regs[reg2.ID]
	if promoted.Status != domain.StatusApproved {
		t.Errorf("expected waitlisted→approved promotion, got %s", promoted.Status)
	}
}

// ── Cancel tests ─────────────────────────────────────────────────────────────

func TestCancelRegistration_Success(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	eventID := seedEvent(t, eventRepo, 99, 0)

	reg, _ := uc.ApplyToEvent(1, eventID)

	cancelled, err := uc.CancelRegistration(1, reg.ID)
	if err != nil {
		t.Fatalf("cancel failed: %v", err)
	}
	if cancelled.Status != domain.StatusCancelled {
		t.Errorf("expected cancelled, got %s", cancelled.Status)
	}
}

func TestCancelRegistration_NotOwner(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	eventID := seedEvent(t, eventRepo, 99, 0)

	reg, _ := uc.ApplyToEvent(1, eventID)

	_, err := uc.CancelRegistration(999, reg.ID)
	if err == nil {
		t.Fatal("expected FORBIDDEN error")
	}
	var appErr *domain.AppError
	if !isAppError(err, &appErr) || appErr.Code != "FORBIDDEN" {
		t.Errorf("expected FORBIDDEN, got %v", err)
	}
}

func TestCancelRegistration_NotCancellable(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(99)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(1, eventID)
	// Approve then check in
	uc.UpdateStatus(organizerID, reg.ID, domain.StatusApproved)
	uc.UpdateStatus(organizerID, reg.ID, domain.StatusCheckedIn)

	// Trying to cancel a checked-in registration should fail.
	_, err := uc.CancelRegistration(1, reg.ID)
	if err == nil {
		t.Fatal("expected error cancelling checked-in registration")
	}
}

func TestReapplyAfterCancel(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	eventID := seedEvent(t, eventRepo, 99, 0)

	reg, _ := uc.ApplyToEvent(1, eventID)
	uc.CancelRegistration(1, reg.ID)

	// Re-apply should work (reactivate)
	reg2, err := uc.ApplyToEvent(1, eventID)
	if err != nil {
		t.Fatalf("re-apply failed: %v", err)
	}
	if reg2.Status != domain.StatusPending {
		t.Errorf("expected pending on re-apply, got %s", reg2.Status)
	}
}

// ── Status transitions ───────────────────────────────────────────────────────

func TestUpdateStatus_ApproveSuccess(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	studentID := uint(20)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(studentID, eventID)

	updated, err := uc.UpdateStatus(organizerID, reg.ID, domain.StatusApproved)
	if err != nil {
		t.Fatalf("update status failed: %v", err)
	}
	if updated.Status != domain.StatusApproved {
		t.Errorf("expected approved, got %s", updated.Status)
	}
}

func TestUpdateStatus_CheckIn(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(20, eventID)
	uc.UpdateStatus(organizerID, reg.ID, domain.StatusApproved)

	checked, err := uc.UpdateStatus(organizerID, reg.ID, domain.StatusCheckedIn)
	if err != nil {
		t.Fatalf("checkin failed: %v", err)
	}
	if checked.Status != domain.StatusCheckedIn {
		t.Errorf("expected checked_in, got %s", checked.Status)
	}
	if checked.CheckedInAt == nil {
		t.Error("expected checked_in_at to be set")
	}
}

func TestUpdateStatus_Complete(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(20, eventID)
	uc.UpdateStatus(organizerID, reg.ID, domain.StatusApproved)
	uc.UpdateStatus(organizerID, reg.ID, domain.StatusCheckedIn)

	completed, err := uc.UpdateStatus(organizerID, reg.ID, domain.StatusCompleted)
	if err != nil {
		t.Fatalf("complete failed: %v", err)
	}
	if completed.Status != domain.StatusCompleted {
		t.Errorf("expected completed, got %s", completed.Status)
	}
}

func TestUpdateStatus_ForbiddenForNonOrganizer(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(20, eventID)

	_, err := uc.UpdateStatus(999, reg.ID, domain.StatusApproved)
	if err == nil {
		t.Fatal("expected FORBIDDEN error")
	}
}

func TestUpdateStatus_InvalidTransition(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(20, eventID)

	// pending → completed is invalid (must go through approved + checked_in)
	_, err := uc.UpdateStatus(organizerID, reg.ID, domain.StatusCompleted)
	if err == nil {
		t.Fatal("expected error for invalid transition pending→completed")
	}
}

func TestUpdateStatus_InvalidStatusValue(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(20, eventID)

	_, err := uc.UpdateStatus(organizerID, reg.ID, "invalid_status")
	if err == nil {
		t.Fatal("expected validation error for invalid status")
	}
}

// ── QR check-in tests ────────────────────────────────────────────────────────

func TestCheckinByQR_Success(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(20, eventID)
	uc.UpdateStatus(organizerID, reg.ID, domain.StatusApproved)

	// Generate the correct HMAC
	hmacStr := app.ComputeCheckinHMAC(reg.ID, "test-checkin-token")

	checked, err := uc.CheckinByQR(organizerID, reg.ID, hmacStr)
	if err != nil {
		t.Fatalf("checkin failed: %v", err)
	}
	if checked.Status != domain.StatusCheckedIn {
		t.Errorf("expected checked_in, got %s", checked.Status)
	}
}

func TestCheckinByQR_InvalidHMAC(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(20, eventID)
	uc.UpdateStatus(organizerID, reg.ID, domain.StatusApproved)

	_, err := uc.CheckinByQR(organizerID, reg.ID, "bad-hmac")
	if err == nil {
		t.Fatal("expected error for invalid QR HMAC")
	}
}

func TestCheckinByQR_NotApproved(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(20, eventID)
	// Still pending — not approved

	hmacStr := app.ComputeCheckinHMAC(reg.ID, "test-checkin-token")
	_, err := uc.CheckinByQR(organizerID, reg.ID, hmacStr)
	if err == nil {
		t.Fatal("expected error — only approved can be checked in")
	}
}

func TestCheckinByQR_NotOrganizer(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(20, eventID)
	uc.UpdateStatus(organizerID, reg.ID, domain.StatusApproved)

	hmacStr := app.ComputeCheckinHMAC(reg.ID, "test-checkin-token")
	_, err := uc.CheckinByQR(999, reg.ID, hmacStr) // wrong organizer
	if err == nil {
		t.Fatal("expected FORBIDDEN for non-organizer")
	}
}

// ── QR payload test ──────────────────────────────────────────────────────────

func TestGetQRPayload_Success(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(20, eventID)
	uc.UpdateStatus(organizerID, reg.ID, domain.StatusApproved)

	payload, err := uc.GetQRPayload(20, reg.ID)
	if err != nil {
		t.Fatalf("get QR failed: %v", err)
	}
	if payload == "" {
		t.Error("expected non-empty QR payload")
	}
}

func TestGetQRPayload_NotOwner(t *testing.T) {
	regRepo, eventRepo := linkedRepos()
	uc := newRegUC(regRepo, eventRepo)
	organizerID := uint(10)
	eventID := seedEvent(t, eventRepo, organizerID, 0)

	reg, _ := uc.ApplyToEvent(20, eventID)
	uc.UpdateStatus(organizerID, reg.ID, domain.StatusApproved)

	_, err := uc.GetQRPayload(999, reg.ID)
	if err == nil {
		t.Fatal("expected FORBIDDEN for non-owner")
	}
}

// ── Transition table ─────────────────────────────────────────────────────────

func TestStatusTransitionTable(t *testing.T) {
	cases := []struct {
		from    domain.RegStatus
		to      domain.RegStatus
		allowed bool
	}{
		// pending →
		{domain.StatusPending, domain.StatusApproved, true},
		{domain.StatusPending, domain.StatusRejected, true},
		{domain.StatusPending, domain.StatusWaitlisted, true},
		{domain.StatusPending, domain.StatusCancelled, true},
		{domain.StatusPending, domain.StatusPending, false},
		{domain.StatusPending, domain.StatusCheckedIn, false},
		{domain.StatusPending, domain.StatusCompleted, false},
		// approved →
		{domain.StatusApproved, domain.StatusRejected, true},
		{domain.StatusApproved, domain.StatusCheckedIn, true},
		{domain.StatusApproved, domain.StatusCancelled, true},
		{domain.StatusApproved, domain.StatusApproved, false},
		{domain.StatusApproved, domain.StatusCompleted, false},
		// rejected →
		{domain.StatusRejected, domain.StatusApproved, true},
		{domain.StatusRejected, domain.StatusRejected, false},
		// waitlisted →
		{domain.StatusWaitlisted, domain.StatusApproved, true},
		{domain.StatusWaitlisted, domain.StatusRejected, true},
		{domain.StatusWaitlisted, domain.StatusCancelled, true},
		{domain.StatusWaitlisted, domain.StatusWaitlisted, false},
		// checked_in →
		{domain.StatusCheckedIn, domain.StatusCompleted, true},
		{domain.StatusCheckedIn, domain.StatusCheckedIn, false},
		// completed → (terminal)
		{domain.StatusCompleted, domain.StatusApproved, false},
		// cancelled → (terminal)
		{domain.StatusCancelled, domain.StatusApproved, false},
	}

	for _, tc := range cases {
		got := tc.from.CanTransitionTo(tc.to)
		if got != tc.allowed {
			t.Errorf("transition %s→%s: expected allowed=%v, got=%v",
				tc.from, tc.to, tc.allowed, got)
		}
	}
}
