package app_test

import (
	"testing"

	"eventapp/internal/app"
	"eventapp/internal/domain"
)

// ── Mock NotificationRepository ──

type mockNotifRepo struct {
	notifs []domain.Notification
	nextID uint
}

func newMockNotifRepo() *mockNotifRepo {
	return &mockNotifRepo{nextID: 1}
}

func (m *mockNotifRepo) Create(n *domain.Notification) error {
	n.ID = m.nextID
	m.nextID++
	m.notifs = append(m.notifs, *n)
	return nil
}

func (m *mockNotifRepo) ListByUser(userID uint, unreadOnly bool, limit int) ([]domain.Notification, error) {
	var out []domain.Notification
	for _, n := range m.notifs {
		if n.UserID == userID {
			if unreadOnly && n.Read {
				continue
			}
			out = append(out, n)
		}
	}
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func (m *mockNotifRepo) MarkRead(id, userID uint) error {
	for i := range m.notifs {
		if m.notifs[i].ID == id && m.notifs[i].UserID == userID {
			m.notifs[i].Read = true
		}
	}
	return nil
}

func (m *mockNotifRepo) MarkAllRead(userID uint) error {
	for i := range m.notifs {
		if m.notifs[i].UserID == userID {
			m.notifs[i].Read = true
		}
	}
	return nil
}

func (m *mockNotifRepo) CountUnread(userID uint) (int64, error) {
	var count int64
	for _, n := range m.notifs {
		if n.UserID == userID && !n.Read {
			count++
		}
	}
	return count, nil
}

// ── Mock DeviceTokenRepository ──

type mockDeviceRepo struct {
	tokens []domain.DeviceToken
}

func newMockDeviceRepo() *mockDeviceRepo {
	return &mockDeviceRepo{}
}

func (m *mockDeviceRepo) Upsert(dt *domain.DeviceToken) error {
	for i := range m.tokens {
		if m.tokens[i].Token == dt.Token {
			m.tokens[i].UserID = dt.UserID
			return nil
		}
	}
	m.tokens = append(m.tokens, *dt)
	return nil
}

func (m *mockDeviceRepo) Delete(userID uint, token string) error {
	for i := range m.tokens {
		if m.tokens[i].UserID == userID && m.tokens[i].Token == token {
			m.tokens = append(m.tokens[:i], m.tokens[i+1:]...)
			return nil
		}
	}
	return nil
}

func (m *mockDeviceRepo) ListByUser(userID uint) ([]domain.DeviceToken, error) {
	var out []domain.DeviceToken
	for _, dt := range m.tokens {
		if dt.UserID == userID {
			out = append(out, dt)
		}
	}
	return out, nil
}

// ── Mock Sender ──

type mockSender struct {
	sent []struct{ userID uint; title, body string }
}

func (m *mockSender) Send(userID uint, title, body string) error {
	m.sent = append(m.sent, struct{ userID uint; title, body string }{userID, title, body})
	return nil
}

// ── Tests ──

func TestNotify_PersistsAndSends(t *testing.T) {
	notifRepo := newMockNotifRepo()
	deviceRepo := newMockDeviceRepo()
	sender := &mockSender{}
	uc := app.NewNotificationUsecase(notifRepo, deviceRepo, sender)

	eventID := uint(42)
	uc.NotifyRegistrationApproved(1, "Robotics Workshop", eventID)

	// Check persisted.
	notifs, _ := uc.ListNotifications(1, false, 10)
	if len(notifs) != 1 {
		t.Fatalf("expected 1 notification, got %d", len(notifs))
	}
	if notifs[0].Type != domain.NotifRegistrationApproved {
		t.Errorf("expected type approved, got %s", notifs[0].Type)
	}
	if notifs[0].EventID == nil || *notifs[0].EventID != 42 {
		t.Error("expected event_id=42")
	}

	// Check push sent.
	if len(sender.sent) != 1 {
		t.Fatalf("expected 1 push, got %d", len(sender.sent))
	}
}

func TestNotify_UnreadCount(t *testing.T) {
	notifRepo := newMockNotifRepo()
	uc := app.NewNotificationUsecase(notifRepo, newMockDeviceRepo(), &mockSender{})

	uc.NotifyRegistrationSubmitted(1, "E1", 1)
	uc.NotifyRegistrationApproved(1, "E2", 2)

	count, _ := uc.CountUnread(1)
	if count != 2 {
		t.Errorf("expected 2 unread, got %d", count)
	}
}

func TestNotify_MarkRead(t *testing.T) {
	notifRepo := newMockNotifRepo()
	uc := app.NewNotificationUsecase(notifRepo, newMockDeviceRepo(), &mockSender{})

	uc.NotifyRegistrationSubmitted(1, "E1", 1)

	notifs, _ := uc.ListNotifications(1, false, 10)
	uc.MarkRead(1, notifs[0].ID)

	count, _ := uc.CountUnread(1)
	if count != 0 {
		t.Errorf("expected 0 unread after mark read, got %d", count)
	}
}

func TestNotify_MarkAllRead(t *testing.T) {
	notifRepo := newMockNotifRepo()
	uc := app.NewNotificationUsecase(notifRepo, newMockDeviceRepo(), &mockSender{})

	uc.NotifyRegistrationSubmitted(1, "E1", 1)
	uc.NotifyRegistrationApproved(1, "E2", 2)
	uc.NotifyWaitlistPromoted(1, "E3", 3)

	uc.MarkAllRead(1)

	count, _ := uc.CountUnread(1)
	if count != 0 {
		t.Errorf("expected 0 unread after mark all, got %d", count)
	}
}

func TestDeviceToken_RegisterAndUnregister(t *testing.T) {
	notifRepo := newMockNotifRepo()
	deviceRepo := newMockDeviceRepo()
	uc := app.NewNotificationUsecase(notifRepo, deviceRepo, &mockSender{})

	uc.RegisterDevice(1, "apns-token-abc", "ios")

	tokens, _ := deviceRepo.ListByUser(1)
	if len(tokens) != 1 {
		t.Fatalf("expected 1 token, got %d", len(tokens))
	}

	uc.UnregisterDevice(1, "apns-token-abc")

	tokens, _ = deviceRepo.ListByUser(1)
	if len(tokens) != 0 {
		t.Errorf("expected 0 tokens after unregister, got %d", len(tokens))
	}
}

func TestNotify_RegistrationLifecycleIntegration(t *testing.T) {
	// Integration test: apply → waitlist promotion triggers notification.
	regRepo, eventRepo := linkedRepos()
	notifRepo := newMockNotifRepo()
	sender := &mockSender{}
	notifUC := app.NewNotificationUsecase(notifRepo, newMockDeviceRepo(), sender)
	regUC := app.NewRegistrationUsecase(regRepo, eventRepo, notifUC)

	organizerID := uint(99)
	eventID := seedEvent(t, eventRepo, organizerID, 1)

	// Student 1 applies, approve.
	reg1, _ := regUC.ApplyToEvent(10, eventID)
	regUC.UpdateStatus(organizerID, reg1.ID, domain.StatusApproved)

	// Student 2 applies → waitlisted.
	regUC.ApplyToEvent(20, eventID)

	// Clear notifications from apply/approve to isolate promotion notification.
	initialSent := len(sender.sent)

	// Student 1 cancels → student 2 promoted → notification fires.
	regUC.CancelRegistration(10, reg1.ID)

	if len(sender.sent) <= initialSent {
		t.Error("expected push notification for waitlist promotion")
	}

	// Verify notification was persisted for student 2.
	notifs, _ := notifUC.ListNotifications(20, false, 10)
	found := false
	for _, n := range notifs {
		if n.Type == domain.NotifWaitlistPromoted {
			found = true
		}
	}
	if !found {
		t.Error("expected waitlist_promoted notification for student 20")
	}
}
