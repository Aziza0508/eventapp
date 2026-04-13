package app_test

import (
	"context"
	"errors"
	"sort"
	"time"

	"eventapp/internal/app"
	"eventapp/internal/domain"
)

// ---- Mock UserRepository ----

type mockUserRepo struct {
	users   map[uint]*domain.User
	byEmail map[string]*domain.User
	nextID  uint
}

func newMockUserRepo() *mockUserRepo {
	return &mockUserRepo{
		users:   make(map[uint]*domain.User),
		byEmail: make(map[string]*domain.User),
		nextID:  1,
	}
}

func (m *mockUserRepo) Create(u *domain.User) error {
	if _, exists := m.byEmail[u.Email]; exists {
		return errors.New("duplicate email")
	}
	u.ID = m.nextID
	m.nextID++
	m.users[u.ID] = u
	m.byEmail[u.Email] = u
	return nil
}

func (m *mockUserRepo) GetByEmail(email string) (*domain.User, error) {
	u, ok := m.byEmail[email]
	if !ok {
		return nil, domain.ErrNotFound
	}
	return u, nil
}

func (m *mockUserRepo) GetByID(id uint) (*domain.User, error) {
	u, ok := m.users[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	return u, nil
}

func (m *mockUserRepo) Update(u *domain.User) error {
	m.users[u.ID] = u
	m.byEmail[u.Email] = u
	return nil
}

func (m *mockUserRepo) ListByRoleAndApproval(role domain.UserRole, approved bool) ([]domain.User, error) {
	var out []domain.User
	for _, u := range m.users {
		if u.Role == role && u.Approved == approved {
			out = append(out, *u)
		}
	}
	return out, nil
}

func (m *mockUserRepo) ListFiltered(f app.UserFilter) ([]domain.User, int64, error) {
	var out []domain.User
	for _, u := range m.users {
		if f.Role != "" && u.Role != f.Role {
			continue
		}
		if f.Approved != nil && u.Approved != *f.Approved {
			continue
		}
		if f.Blocked != nil && u.Blocked != *f.Blocked {
			continue
		}
		out = append(out, *u)
	}
	return out, int64(len(out)), nil
}

func (m *mockUserRepo) CountByRole() (map[domain.UserRole]int64, error) {
	counts := make(map[domain.UserRole]int64)
	for _, u := range m.users {
		counts[u.Role]++
	}
	return counts, nil
}

// ---- Mock AuditLogRepository ----

type mockAuditRepo struct {
	logs []domain.AuditLog
}

func newMockAuditRepo() *mockAuditRepo {
	return &mockAuditRepo{}
}

func (m *mockAuditRepo) Create(entry *domain.AuditLog) error {
	entry.ID = uint(len(m.logs) + 1)
	m.logs = append(m.logs, *entry)
	return nil
}

func (m *mockAuditRepo) List(limit int) ([]domain.AuditLog, error) {
	if limit > len(m.logs) {
		limit = len(m.logs)
	}
	return m.logs[:limit], nil
}

func (m *mockAuditRepo) ListByActor(actorID uint, limit int) ([]domain.AuditLog, error) {
	var out []domain.AuditLog
	for _, l := range m.logs {
		if l.ActorID == actorID {
			out = append(out, l)
		}
	}
	if limit > 0 && limit < len(out) {
		out = out[:limit]
	}
	return out, nil
}

// ---- Mock JWTProvider ----

type mockJWT struct{}

func (mockJWT) Generate(userID uint, role domain.UserRole) (string, error) {
	return "mock-token", nil
}

func (mockJWT) Validate(token string) (uint, domain.UserRole, error) {
	return 1, domain.RoleStudent, nil
}

// ---- Mock RefreshTokenStore ----

type mockRefreshStore struct {
	// tokens maps "userID:hash" → expiry
	tokens map[string]time.Time
}

func newMockRefreshStore() *mockRefreshStore {
	return &mockRefreshStore{tokens: make(map[string]time.Time)}
}

func (m *mockRefreshStore) key(userID uint, hash string) string {
	return string(rune(userID)) + ":" + hash
}

func (m *mockRefreshStore) Save(_ context.Context, userID uint, tokenHash string, ttl time.Duration) error {
	m.tokens[m.key(userID, tokenHash)] = time.Now().Add(ttl)
	return nil
}

func (m *mockRefreshStore) Exists(_ context.Context, userID uint, tokenHash string) (bool, error) {
	exp, ok := m.tokens[m.key(userID, tokenHash)]
	if !ok || time.Now().After(exp) {
		return false, nil
	}
	return true, nil
}

func (m *mockRefreshStore) Revoke(_ context.Context, userID uint, tokenHash string) error {
	delete(m.tokens, m.key(userID, tokenHash))
	return nil
}

func (m *mockRefreshStore) RevokeAll(_ context.Context, userID uint) error {
	prefix := string(rune(userID)) + ":"
	for k := range m.tokens {
		if len(k) > len(prefix) && k[:len(prefix)] == prefix {
			delete(m.tokens, k)
		}
	}
	return nil
}

// ---- Mock refresh token generation (deterministic for tests) ----

var mockRTCounter int

func mockGenerateRT() (string, error) {
	mockRTCounter++
	return "mock-refresh-token-" + string(rune('0'+mockRTCounter)), nil
}

func mockHashRT(token string) string {
	return "hash:" + token
}

// ---- Mock EventRepository ----

type mockEventRepo struct {
	events  map[uint]*domain.Event
	nextID  uint
	regRepo *mockRegRepo // link to count registrations accurately
}

func newMockEventRepo() *mockEventRepo {
	return &mockEventRepo{events: make(map[uint]*domain.Event), nextID: 1}
}

func (m *mockEventRepo) Create(e *domain.Event) error {
	e.ID = m.nextID
	m.nextID++
	m.events[e.ID] = e
	return nil
}

func (m *mockEventRepo) GetByID(id uint) (*domain.Event, error) {
	e, ok := m.events[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	return e, nil
}

func (m *mockEventRepo) List(_ domain.EventFilter) ([]domain.Event, int64, error) {
	var out []domain.Event
	for _, e := range m.events {
		out = append(out, *e)
	}
	return out, int64(len(out)), nil
}

func (m *mockEventRepo) Update(e *domain.Event) error {
	m.events[e.ID] = e
	return nil
}

func (m *mockEventRepo) Delete(id uint) error {
	delete(m.events, id)
	return nil
}

func (m *mockEventRepo) CountRegistrations(eventID uint) (int64, error) {
	if m.regRepo == nil {
		return 0, nil
	}
	var count int64
	for _, r := range m.regRepo.regs {
		if r.EventID == eventID && r.Status.CountsTowardCapacity() {
			count++
		}
	}
	return count, nil
}

// ---- Mock RegistrationRepository ----

type mockRegRepo struct {
	regs   map[uint]*domain.Registration
	nextID uint
}

func newMockRegRepo() *mockRegRepo {
	return &mockRegRepo{regs: make(map[uint]*domain.Registration), nextID: 1}
}

func (m *mockRegRepo) Create(r *domain.Registration) error {
	r.ID = m.nextID
	m.nextID++
	m.regs[r.ID] = r
	return nil
}

func (m *mockRegRepo) GetByID(id uint) (*domain.Registration, error) {
	r, ok := m.regs[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	return r, nil
}

func (m *mockRegRepo) GetByUserAndEvent(userID, eventID uint) (*domain.Registration, error) {
	for _, r := range m.regs {
		if r.UserID == userID && r.EventID == eventID {
			return r, nil
		}
	}
	return nil, nil
}

func (m *mockRegRepo) ListByUser(userID uint) ([]domain.Registration, error) {
	var out []domain.Registration
	for _, r := range m.regs {
		if r.UserID == userID {
			out = append(out, *r)
		}
	}
	// Go map iteration is non-deterministic; sort by insertion order (ID)
	// so tests asserting on positional rows are stable.
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

func (m *mockRegRepo) ListByEvent(eventID uint) ([]domain.Registration, error) {
	var out []domain.Registration
	for _, r := range m.regs {
		if r.EventID == eventID {
			out = append(out, *r)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

func (m *mockRegRepo) Update(r *domain.Registration) error {
	m.regs[r.ID] = r
	return nil
}

func (m *mockRegRepo) CountByEventAndStatus(eventID uint) (map[domain.RegStatus]int64, error) {
	counts := make(map[domain.RegStatus]int64)
	for _, r := range m.regs {
		if r.EventID == eventID {
			counts[r.Status]++
		}
	}
	return counts, nil
}

func (m *mockRegRepo) FirstWaitlisted(eventID uint) (*domain.Registration, error) {
	var oldest *domain.Registration
	for _, r := range m.regs {
		if r.EventID == eventID && r.Status == domain.StatusWaitlisted {
			if oldest == nil || r.CreatedAt.Before(oldest.CreatedAt) {
				cp := *r
				oldest = &cp
			}
		}
	}
	return oldest, nil
}

// ---- Mock FavoriteRepository ----

type mockFavRepo struct {
	favs   map[string]*domain.Favorite // key: "userID:eventID"
	nextID uint
}

func newMockFavRepo() *mockFavRepo {
	return &mockFavRepo{favs: make(map[string]*domain.Favorite), nextID: 1}
}

func favKey(userID, eventID uint) string {
	return string(rune(userID)) + ":" + string(rune(eventID))
}

func (m *mockFavRepo) Add(fav *domain.Favorite) error {
	k := favKey(fav.UserID, fav.EventID)
	if _, exists := m.favs[k]; exists {
		return domain.ErrAlreadyExists
	}
	fav.ID = m.nextID
	m.nextID++
	m.favs[k] = fav
	return nil
}

func (m *mockFavRepo) Remove(userID, eventID uint) error {
	k := favKey(userID, eventID)
	if _, exists := m.favs[k]; !exists {
		return domain.ErrNotFound
	}
	delete(m.favs, k)
	return nil
}

func (m *mockFavRepo) Exists(userID, eventID uint) (bool, error) {
	_, exists := m.favs[favKey(userID, eventID)]
	return exists, nil
}

func (m *mockFavRepo) ListByUser(userID uint) ([]domain.Favorite, error) {
	var out []domain.Favorite
	for _, f := range m.favs {
		if f.UserID == userID {
			out = append(out, *f)
		}
	}
	return out, nil
}
