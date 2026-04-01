package app_test

import (
	"testing"
	"time"

	"eventapp/internal/app"
	"eventapp/internal/domain"
)

func setupReportTest() (*app.ReportUsecase, *mockEventRepo, *mockRegRepo) {
	regRepo := newMockRegRepo()
	eventRepo := newMockEventRepo()
	eventRepo.regRepo = regRepo
	return app.NewReportUsecase(eventRepo, regRepo), eventRepo, regRepo
}

// ── Attendance report ────────────────────────────────────────────────────────

func TestAttendanceReport_Success(t *testing.T) {
	uc, eventRepo, regRepo := setupReportTest()
	orgID := uint(10)

	eventRepo.Create(&domain.Event{
		Title: "Test Event", DateStart: time.Now(), Capacity: 50, OrganizerID: orgID,
	})

	// Add some registrations with different statuses.
	regRepo.Create(&domain.Registration{UserID: 1, EventID: 1, Status: domain.StatusApproved,
		User: &domain.User{FullName: "Alice", Email: "alice@x.com", School: "School 1", City: "Almaty", Grade: 10}})
	regRepo.Create(&domain.Registration{UserID: 2, EventID: 1, Status: domain.StatusCheckedIn,
		User: &domain.User{FullName: "Bob", Email: "bob@x.com"}})
	regRepo.Create(&domain.Registration{UserID: 3, EventID: 1, Status: domain.StatusRejected,
		User: &domain.User{FullName: "Charlie", Email: "charlie@x.com"}})

	report, err := uc.GetAttendanceReport(orgID, 1)
	if err != nil {
		t.Fatalf("attendance report failed: %v", err)
	}

	if report.EventTitle != "Test Event" {
		t.Errorf("expected title Test Event, got %s", report.EventTitle)
	}
	if report.Capacity != 50 {
		t.Errorf("expected capacity 50, got %d", report.Capacity)
	}
	if report.TotalRows != 3 {
		t.Errorf("expected 3 rows, got %d", report.TotalRows)
	}
	if report.StatusCount["approved"] != 1 {
		t.Errorf("expected 1 approved, got %d", report.StatusCount["approved"])
	}
	if report.StatusCount["checked_in"] != 1 {
		t.Errorf("expected 1 checked_in, got %d", report.StatusCount["checked_in"])
	}

	// Verify row data.
	if report.Rows[0].UserName != "Alice" {
		t.Errorf("expected Alice, got %s", report.Rows[0].UserName)
	}
}

func TestAttendanceReport_Forbidden(t *testing.T) {
	uc, eventRepo, _ := setupReportTest()

	eventRepo.Create(&domain.Event{
		Title: "Test", DateStart: time.Now(), OrganizerID: 10,
	})

	_, err := uc.GetAttendanceReport(999, 1) // wrong organizer
	if err == nil {
		t.Fatal("expected FORBIDDEN error")
	}
}

func TestAttendanceReport_EventNotFound(t *testing.T) {
	uc, _, _ := setupReportTest()

	_, err := uc.GetAttendanceReport(10, 999)
	if err == nil {
		t.Fatal("expected NOT_FOUND error")
	}
}

func TestAttendanceReport_EmptyEvent(t *testing.T) {
	uc, eventRepo, _ := setupReportTest()

	eventRepo.Create(&domain.Event{
		Title: "Empty Event", DateStart: time.Now(), Capacity: 20, OrganizerID: 10,
	})

	report, err := uc.GetAttendanceReport(10, 1)
	if err != nil {
		t.Fatalf("report failed: %v", err)
	}
	if report.TotalRows != 0 {
		t.Errorf("expected 0 rows for empty event, got %d", report.TotalRows)
	}
}

// ── Organizer summary ────────────────────────────────────────────────────────

func TestOrganizerSummary_Success(t *testing.T) {
	uc, eventRepo, regRepo := setupReportTest()
	orgID := uint(10)

	eventRepo.Create(&domain.Event{
		Title: "Event A", DateStart: time.Now(), Capacity: 10, OrganizerID: orgID,
	})
	eventRepo.Create(&domain.Event{
		Title: "Event B", DateStart: time.Now(), Capacity: 0, OrganizerID: orgID, // unlimited
	})
	eventRepo.Create(&domain.Event{
		Title: "Other Org Event", DateStart: time.Now(), Capacity: 5, OrganizerID: 99,
	})

	// Event A: 2 approved, 1 checked in.
	regRepo.Create(&domain.Registration{UserID: 1, EventID: 1, Status: domain.StatusApproved})
	regRepo.Create(&domain.Registration{UserID: 2, EventID: 1, Status: domain.StatusApproved})
	regRepo.Create(&domain.Registration{UserID: 3, EventID: 1, Status: domain.StatusCheckedIn})

	// Event B: 1 pending.
	regRepo.Create(&domain.Registration{UserID: 4, EventID: 2, Status: domain.StatusPending})

	summary, err := uc.GetOrganizerSummary(orgID, nil, nil)
	if err != nil {
		t.Fatalf("organizer summary failed: %v", err)
	}

	if summary.TotalEvents != 2 {
		t.Errorf("expected 2 events (only mine), got %d", summary.TotalEvents)
	}
	if summary.TotalRegistered != 4 {
		t.Errorf("expected 4 total registered, got %d", summary.TotalRegistered)
	}
	if summary.TotalCheckedIn != 1 {
		t.Errorf("expected 1 checked in, got %d", summary.TotalCheckedIn)
	}

	// Event A: capacity=10, 3 active (approved+checked_in) → fill rate = 30%
	var eventA *app.EventSummaryRow
	for i := range summary.Events {
		if summary.Events[i].Title == "Event A" {
			eventA = &summary.Events[i]
		}
	}
	if eventA == nil {
		t.Fatal("Event A not found in summary")
	}
	if eventA.FillRate < 29.9 || eventA.FillRate > 30.1 {
		t.Errorf("expected ~30%% fill rate, got %.1f%%", eventA.FillRate)
	}
	if eventA.Approved != 2 {
		t.Errorf("expected 2 approved, got %d", eventA.Approved)
	}
	if eventA.CheckedIn != 1 {
		t.Errorf("expected 1 checked in, got %d", eventA.CheckedIn)
	}
}

func TestOrganizerSummary_NoEvents(t *testing.T) {
	uc, _, _ := setupReportTest()

	summary, err := uc.GetOrganizerSummary(10, nil, nil)
	if err != nil {
		t.Fatalf("summary failed: %v", err)
	}
	if summary.TotalEvents != 0 {
		t.Errorf("expected 0 events, got %d", summary.TotalEvents)
	}
	if len(summary.Events) != 0 {
		t.Errorf("expected empty events list, got %d", len(summary.Events))
	}
}
