package app

import "eventapp/internal/domain"

// AdminUsecase handles admin-only business logic: user management, dashboard, audit.
type AdminUsecase struct {
	users  UserRepository
	events EventRepository
	regs   RegistrationRepository
	audit  *AuditService
}

func NewAdminUsecase(
	users UserRepository,
	events EventRepository,
	regs RegistrationRepository,
	audit *AuditService,
) *AdminUsecase {
	return &AdminUsecase{users: users, events: events, regs: regs, audit: audit}
}

// ── User listing ─────────────────────────────────────────────────────────────

// ListUsers returns a filtered, paginated list of users (admin only).
func (uc *AdminUsecase) ListUsers(filter UserFilter) ([]domain.User, int64, error) {
	return uc.users.ListFiltered(filter)
}

// ListPendingOrganizers returns all organizer accounts awaiting approval.
func (uc *AdminUsecase) ListPendingOrganizers() ([]domain.User, error) {
	return uc.users.ListByRoleAndApproval(domain.RoleOrganizer, false)
}

// ── Organizer approval ───────────────────────────────────────────────────────

// ApproveOrganizer sets approved=true for the given organizer.
func (uc *AdminUsecase) ApproveOrganizer(adminID, userID uint, ip string) (*domain.User, error) {
	user, err := uc.users.GetByID(userID)
	if err != nil {
		return nil, domain.ErrNotFound
	}
	if user.Role != domain.RoleOrganizer {
		return nil, domain.NewAppError("VALIDATION_ERROR", "user is not an organizer", nil)
	}
	if user.Approved {
		return nil, domain.NewAppError("CONFLICT", "organizer is already approved", nil)
	}

	user.Approved = true
	if err := uc.users.Update(user); err != nil {
		return nil, err
	}

	if uc.audit != nil {
		uc.audit.Recordf(adminID, domain.AuditOrganizerApproved, "user", userID, ip,
			"Approved organizer %s (%s)", user.FullName, user.Email)
	}

	return user, nil
}

// RejectOrganizer sets approved=false for the given organizer.
func (uc *AdminUsecase) RejectOrganizer(adminID, userID uint, ip string) (*domain.User, error) {
	user, err := uc.users.GetByID(userID)
	if err != nil {
		return nil, domain.ErrNotFound
	}
	if user.Role != domain.RoleOrganizer {
		return nil, domain.NewAppError("VALIDATION_ERROR", "user is not an organizer", nil)
	}

	user.Approved = false
	if err := uc.users.Update(user); err != nil {
		return nil, err
	}

	if uc.audit != nil {
		uc.audit.Recordf(adminID, domain.AuditOrganizerRejected, "user", userID, ip,
			"Rejected organizer %s (%s)", user.FullName, user.Email)
	}

	return user, nil
}

// ── Block / unblock ──────────────────────────────────────────────────────────

// BlockUser sets blocked=true. Blocked users cannot log in (enforced at auth layer).
func (uc *AdminUsecase) BlockUser(adminID, userID uint, ip string) (*domain.User, error) {
	user, err := uc.users.GetByID(userID)
	if err != nil {
		return nil, domain.ErrNotFound
	}
	if user.Role == domain.RoleAdmin {
		return nil, domain.NewAppError("FORBIDDEN", "cannot block another admin", nil)
	}
	if user.Blocked {
		return nil, domain.NewAppError("CONFLICT", "user is already blocked", nil)
	}

	user.Blocked = true
	if err := uc.users.Update(user); err != nil {
		return nil, err
	}

	if uc.audit != nil {
		uc.audit.Recordf(adminID, domain.AuditUserBlocked, "user", userID, ip,
			"Blocked user %s (%s)", user.FullName, user.Email)
	}

	return user, nil
}

// UnblockUser sets blocked=false.
func (uc *AdminUsecase) UnblockUser(adminID, userID uint, ip string) (*domain.User, error) {
	user, err := uc.users.GetByID(userID)
	if err != nil {
		return nil, domain.ErrNotFound
	}
	if !user.Blocked {
		return nil, domain.NewAppError("CONFLICT", "user is not blocked", nil)
	}

	user.Blocked = false
	if err := uc.users.Update(user); err != nil {
		return nil, err
	}

	if uc.audit != nil {
		uc.audit.Recordf(adminID, domain.AuditUserUnblocked, "user", userID, ip,
			"Unblocked user %s (%s)", user.FullName, user.Email)
	}

	return user, nil
}

// ── Change role ──────────────────────────────────────────────────────────────

// ChangeUserRole updates a user's role. Cannot promote to admin.
func (uc *AdminUsecase) ChangeUserRole(adminID, userID uint, newRole domain.UserRole, ip string) (*domain.User, error) {
	if !newRole.IsValid() {
		return nil, domain.NewAppError("VALIDATION_ERROR", "invalid role", nil)
	}
	if newRole == domain.RoleAdmin {
		return nil, domain.NewAppError("FORBIDDEN", "cannot promote to admin via API", nil)
	}

	user, err := uc.users.GetByID(userID)
	if err != nil {
		return nil, domain.ErrNotFound
	}
	if user.Role == domain.RoleAdmin {
		return nil, domain.NewAppError("FORBIDDEN", "cannot change admin role", nil)
	}

	oldRole := user.Role
	user.Role = newRole

	// Organizers need approval; students are auto-approved.
	if newRole == domain.RoleOrganizer {
		user.Approved = false
	} else {
		user.Approved = true
	}

	if err := uc.users.Update(user); err != nil {
		return nil, err
	}

	if uc.audit != nil {
		uc.audit.Recordf(adminID, domain.AuditUserRoleChanged, "user", userID, ip,
			"Changed role %s → %s for %s", oldRole, newRole, user.Email)
	}

	return user, nil
}

// ── Dashboard ────────────────────────────────────────────────────────────────

// DashboardStats holds summary metrics for the admin dashboard.
type DashboardStats struct {
	TotalUsers         int64                      `json:"total_users"`
	UsersByRole        map[domain.UserRole]int64   `json:"users_by_role"`
	PendingOrganizers  int64                      `json:"pending_organizers"`
	TotalEvents        int64                      `json:"total_events"`
	TotalRegistrations int64                      `json:"total_registrations"`
	RecentActions      []domain.AuditLog          `json:"recent_actions"`
}

// GetDashboard returns aggregated statistics for the admin panel.
func (uc *AdminUsecase) GetDashboard() (*DashboardStats, error) {
	usersByRole, err := uc.users.CountByRole()
	if err != nil {
		return nil, err
	}

	var totalUsers int64
	for _, c := range usersByRole {
		totalUsers += c
	}

	pendingOrgs, err := uc.users.ListByRoleAndApproval(domain.RoleOrganizer, false)
	if err != nil {
		return nil, err
	}

	// Count events via List with a large limit (pragmatic for diploma demo).
	_, totalEvents, err := uc.events.List(domain.EventFilter{Page: 1, Limit: 1})
	if err != nil {
		return nil, err
	}

	// Count registrations — use a simple count across all events.
	// For a proper implementation we'd add a CountAll method, but this works for demo.
	totalRegs := int64(0)
	events, _, _ := uc.events.List(domain.EventFilter{Page: 1, Limit: 1000})
	for _, e := range events {
		c, _ := uc.events.CountRegistrations(e.ID)
		totalRegs += c
	}

	var recent []domain.AuditLog
	if uc.audit != nil {
		recent, _ = uc.audit.RecentLogs(20)
	}

	return &DashboardStats{
		TotalUsers:         totalUsers,
		UsersByRole:        usersByRole,
		PendingOrganizers:  int64(len(pendingOrgs)),
		TotalEvents:        totalEvents,
		TotalRegistrations: totalRegs,
		RecentActions:      recent,
	}, nil
}
