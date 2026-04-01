package app_test

import (
	"testing"
	"time"

	"eventapp/internal/app"
	"eventapp/internal/domain"
)

func newAdminUC() (*app.AdminUsecase, *mockUserRepo, *mockAuditRepo) {
	userRepo := newMockUserRepo()
	eventRepo := newMockEventRepo()
	regRepo := newMockRegRepo()
	auditRepo := newMockAuditRepo()
	auditSvc := app.NewAuditService(auditRepo)
	uc := app.NewAdminUsecase(userRepo, eventRepo, regRepo, auditSvc)
	return uc, userRepo, auditRepo
}

// ── Organizer approval ───────────────────────────────────────────────────────

func TestAdminApproveOrganizer_Success(t *testing.T) {
	uc, repo, auditRepo := newAdminUC()

	repo.Create(&domain.User{
		Email: "org@example.com", FullName: "Pending Org",
		Role: domain.RoleOrganizer, Approved: false,
	})

	user, err := uc.ApproveOrganizer(100, 1, "127.0.0.1")
	if err != nil {
		t.Fatalf("approve failed: %v", err)
	}
	if !user.Approved {
		t.Error("user should be approved")
	}

	// Verify audit log was created.
	if len(auditRepo.logs) != 1 {
		t.Fatalf("expected 1 audit entry, got %d", len(auditRepo.logs))
	}
	if auditRepo.logs[0].Action != domain.AuditOrganizerApproved {
		t.Errorf("expected action organizer_approved, got %s", auditRepo.logs[0].Action)
	}
}

func TestAdminApproveOrganizer_AlreadyApproved(t *testing.T) {
	uc, repo, _ := newAdminUC()

	repo.Create(&domain.User{
		Email: "org@example.com", FullName: "Approved Org",
		Role: domain.RoleOrganizer, Approved: true,
	})

	_, err := uc.ApproveOrganizer(100, 1, "")
	if err == nil {
		t.Fatal("expected CONFLICT error")
	}
	var appErr *domain.AppError
	if !isAppError(err, &appErr) || appErr.Code != "CONFLICT" {
		t.Errorf("expected CONFLICT, got %v", err)
	}
}

func TestAdminApproveOrganizer_NotAnOrganizer(t *testing.T) {
	uc, repo, _ := newAdminUC()

	repo.Create(&domain.User{
		Email: "student@example.com", FullName: "Student",
		Role: domain.RoleStudent, Approved: true,
	})

	_, err := uc.ApproveOrganizer(100, 1, "")
	if err == nil {
		t.Fatal("expected VALIDATION_ERROR")
	}
}

func TestAdminRejectOrganizer_Success(t *testing.T) {
	uc, repo, auditRepo := newAdminUC()

	repo.Create(&domain.User{
		Email: "org@example.com", FullName: "Org",
		Role: domain.RoleOrganizer, Approved: true,
	})

	user, err := uc.RejectOrganizer(100, 1, "10.0.0.1")
	if err != nil {
		t.Fatalf("reject failed: %v", err)
	}
	if user.Approved {
		t.Error("user should not be approved after rejection")
	}
	if len(auditRepo.logs) != 1 {
		t.Errorf("expected 1 audit entry, got %d", len(auditRepo.logs))
	}
}

func TestAdminListPendingOrganizers(t *testing.T) {
	uc, repo, _ := newAdminUC()

	repo.Create(&domain.User{Email: "org1@x.com", FullName: "O1", Role: domain.RoleOrganizer, Approved: false})
	repo.Create(&domain.User{Email: "org2@x.com", FullName: "O2", Role: domain.RoleOrganizer, Approved: true})
	repo.Create(&domain.User{Email: "stu@x.com", FullName: "S1", Role: domain.RoleStudent, Approved: true})

	pending, err := uc.ListPendingOrganizers()
	if err != nil {
		t.Fatalf("list pending failed: %v", err)
	}
	if len(pending) != 1 {
		t.Errorf("expected 1 pending organizer, got %d", len(pending))
	}
}

func TestAdminApproveOrganizer_NotFound(t *testing.T) {
	uc, _, _ := newAdminUC()
	_, err := uc.ApproveOrganizer(100, 999, "")
	if err == nil {
		t.Fatal("expected NOT_FOUND error")
	}
}

// ── Block / unblock ──────────────────────────────────────────────────────────

func TestAdminBlockUser_Success(t *testing.T) {
	uc, repo, auditRepo := newAdminUC()

	repo.Create(&domain.User{
		Email: "stu@example.com", FullName: "Student",
		Role: domain.RoleStudent, Approved: true,
	})

	user, err := uc.BlockUser(100, 1, "127.0.0.1")
	if err != nil {
		t.Fatalf("block failed: %v", err)
	}
	if !user.Blocked {
		t.Error("user should be blocked")
	}
	if len(auditRepo.logs) != 1 || auditRepo.logs[0].Action != domain.AuditUserBlocked {
		t.Error("expected user_blocked audit entry")
	}
}

func TestAdminBlockUser_CannotBlockAdmin(t *testing.T) {
	uc, repo, _ := newAdminUC()

	repo.Create(&domain.User{
		Email: "admin@example.com", FullName: "Admin",
		Role: domain.RoleAdmin, Approved: true,
	})

	_, err := uc.BlockUser(100, 1, "")
	if err == nil {
		t.Fatal("expected FORBIDDEN error — cannot block admin")
	}
	var appErr *domain.AppError
	if !isAppError(err, &appErr) || appErr.Code != "FORBIDDEN" {
		t.Errorf("expected FORBIDDEN, got %v", err)
	}
}

func TestAdminBlockUser_AlreadyBlocked(t *testing.T) {
	uc, repo, _ := newAdminUC()

	repo.Create(&domain.User{
		Email: "stu@example.com", FullName: "Student",
		Role: domain.RoleStudent, Blocked: true,
	})

	_, err := uc.BlockUser(100, 1, "")
	if err == nil {
		t.Fatal("expected CONFLICT error")
	}
}

func TestAdminUnblockUser_Success(t *testing.T) {
	uc, repo, _ := newAdminUC()

	repo.Create(&domain.User{
		Email: "stu@example.com", FullName: "Student",
		Role: domain.RoleStudent, Blocked: true,
	})

	user, err := uc.UnblockUser(100, 1, "")
	if err != nil {
		t.Fatalf("unblock failed: %v", err)
	}
	if user.Blocked {
		t.Error("user should not be blocked")
	}
}

// ── Change role ──────────────────────────────────────────────────────────────

func TestAdminChangeRole_Success(t *testing.T) {
	uc, repo, auditRepo := newAdminUC()

	repo.Create(&domain.User{
		Email: "stu@example.com", FullName: "Student",
		Role: domain.RoleStudent, Approved: true,
	})

	user, err := uc.ChangeUserRole(100, 1, domain.RoleOrganizer, "127.0.0.1")
	if err != nil {
		t.Fatalf("change role failed: %v", err)
	}
	if user.Role != domain.RoleOrganizer {
		t.Errorf("expected organizer, got %s", user.Role)
	}
	// Organizer should need approval.
	if user.Approved {
		t.Error("new organizer should be unapproved")
	}
	if len(auditRepo.logs) != 1 || auditRepo.logs[0].Action != domain.AuditUserRoleChanged {
		t.Error("expected user_role_changed audit entry")
	}
}

func TestAdminChangeRole_CannotPromoteToAdmin(t *testing.T) {
	uc, repo, _ := newAdminUC()

	repo.Create(&domain.User{
		Email: "stu@example.com", FullName: "Student",
		Role: domain.RoleStudent,
	})

	_, err := uc.ChangeUserRole(100, 1, domain.RoleAdmin, "")
	if err == nil {
		t.Fatal("expected FORBIDDEN — cannot promote to admin via API")
	}
}

func TestAdminChangeRole_CannotChangeAdminRole(t *testing.T) {
	uc, repo, _ := newAdminUC()

	repo.Create(&domain.User{
		Email: "admin@example.com", FullName: "Admin",
		Role: domain.RoleAdmin,
	})

	_, err := uc.ChangeUserRole(100, 1, domain.RoleStudent, "")
	if err == nil {
		t.Fatal("expected FORBIDDEN — cannot change admin role")
	}
}

// ── List users ───────────────────────────────────────────────────────────────

func TestAdminListUsers_FilterByRole(t *testing.T) {
	uc, repo, _ := newAdminUC()

	repo.Create(&domain.User{Email: "s1@x.com", FullName: "S1", Role: domain.RoleStudent})
	repo.Create(&domain.User{Email: "s2@x.com", FullName: "S2", Role: domain.RoleStudent})
	repo.Create(&domain.User{Email: "o1@x.com", FullName: "O1", Role: domain.RoleOrganizer})

	users, total, err := uc.ListUsers(app.UserFilter{Role: domain.RoleStudent})
	if err != nil {
		t.Fatalf("list failed: %v", err)
	}
	if total != 2 {
		t.Errorf("expected 2 students, got %d", total)
	}
	if len(users) != 2 {
		t.Errorf("expected 2 users, got %d", len(users))
	}
}

// ── Dashboard ────────────────────────────────────────────────────────────────

func TestAdminDashboard(t *testing.T) {
	uc, repo, _ := newAdminUC()

	repo.Create(&domain.User{Email: "s1@x.com", FullName: "S1", Role: domain.RoleStudent, Approved: true})
	repo.Create(&domain.User{Email: "o1@x.com", FullName: "O1", Role: domain.RoleOrganizer, Approved: false})

	stats, err := uc.GetDashboard()
	if err != nil {
		t.Fatalf("dashboard failed: %v", err)
	}
	if stats.TotalUsers != 2 {
		t.Errorf("expected 2 total users, got %d", stats.TotalUsers)
	}
	if stats.PendingOrganizers != 1 {
		t.Errorf("expected 1 pending organizer, got %d", stats.PendingOrganizers)
	}
	if stats.UsersByRole[domain.RoleStudent] != 1 {
		t.Errorf("expected 1 student, got %d", stats.UsersByRole[domain.RoleStudent])
	}
}

// ── Organizer approval blocks event creation ─────────────────────────────────

func TestCreateEvent_UnapprovedOrganizerBlocked(t *testing.T) {
	userRepo := newMockUserRepo()
	eventRepo := newMockEventRepo()

	userRepo.Create(&domain.User{
		Email: "org@example.com", FullName: "Unapproved Org",
		Role: domain.RoleOrganizer, Approved: false,
	})

	eventUC := app.NewEventUsecase(eventRepo, userRepo)

	_, err := eventUC.CreateEvent(app.CreateEventInput{
		Title: "Test Event", DateStart: time.Now().Add(24 * time.Hour), OrganizerID: 1,
	})
	if err == nil {
		t.Fatal("expected ACCOUNT_PENDING error")
	}
	var appErr *domain.AppError
	if !isAppError(err, &appErr) || appErr.Code != "ACCOUNT_PENDING" {
		t.Errorf("expected ACCOUNT_PENDING, got %v", err)
	}
}

func TestCreateEvent_ApprovedOrganizerAllowed(t *testing.T) {
	userRepo := newMockUserRepo()
	eventRepo := newMockEventRepo()

	userRepo.Create(&domain.User{
		Email: "org@example.com", FullName: "Approved Org",
		Role: domain.RoleOrganizer, Approved: true,
	})

	eventUC := app.NewEventUsecase(eventRepo, userRepo)

	event, err := eventUC.CreateEvent(app.CreateEventInput{
		Title: "Test Event", DateStart: time.Now().Add(24 * time.Hour), OrganizerID: 1,
	})
	if err != nil {
		t.Fatalf("create event failed: %v", err)
	}
	if event.Title != "Test Event" {
		t.Errorf("unexpected title: %s", event.Title)
	}
}

func TestUpdateEvent_UnapprovedOrganizerBlocked(t *testing.T) {
	userRepo := newMockUserRepo()
	eventRepo := newMockEventRepo()

	userRepo.Create(&domain.User{
		Email: "org@example.com", FullName: "Org",
		Role: domain.RoleOrganizer, Approved: false,
	})

	eventUC := app.NewEventUsecase(eventRepo, userRepo)
	eventRepo.Create(&domain.Event{
		Title: "Existing", DateStart: time.Now().Add(24 * time.Hour), OrganizerID: 1,
	})

	_, err := eventUC.UpdateEvent(1, 1, app.UpdateEventInput{Title: "Updated"})
	if err == nil {
		t.Fatal("expected ACCOUNT_PENDING error")
	}
}

func TestDeleteEvent_UnapprovedOrganizerBlocked(t *testing.T) {
	userRepo := newMockUserRepo()
	eventRepo := newMockEventRepo()

	userRepo.Create(&domain.User{
		Email: "org@example.com", FullName: "Org",
		Role: domain.RoleOrganizer, Approved: false,
	})

	eventUC := app.NewEventUsecase(eventRepo, userRepo)
	eventRepo.Create(&domain.Event{
		Title: "Existing", DateStart: time.Now().Add(24 * time.Hour), OrganizerID: 1,
	})

	err := eventUC.DeleteEvent(1, 1)
	if err == nil {
		t.Fatal("expected ACCOUNT_PENDING error")
	}
}

// ── Audit log recording ─────────────────────────────────────────────────────

func TestAuditService_Records(t *testing.T) {
	auditRepo := newMockAuditRepo()
	svc := app.NewAuditService(auditRepo)

	svc.Record(1, domain.AuditLogin, "user", 1, "User logged in", "192.168.1.1")

	logs, err := svc.RecentLogs(10)
	if err != nil {
		t.Fatalf("recent logs failed: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("expected 1 log, got %d", len(logs))
	}
	if logs[0].Action != domain.AuditLogin {
		t.Errorf("expected login action, got %s", logs[0].Action)
	}
	if logs[0].IP != "192.168.1.1" {
		t.Errorf("expected IP 192.168.1.1, got %s", logs[0].IP)
	}
}
