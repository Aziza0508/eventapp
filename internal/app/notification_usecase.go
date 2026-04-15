package app

import (
	"fmt"
	"log"

	"eventapp/internal/domain"
)

// NotificationUsecase creates and delivers notifications through multiple channels.
// It persists every notification in-app (DB) and attempts push delivery via the sender.
type NotificationUsecase struct {
	notifs  NotificationRepository
	devices DeviceTokenRepository
	sender  NotificationSender // push/email — can be a LogSender in dev
}

func NewNotificationUsecase(
	notifs NotificationRepository,
	devices DeviceTokenRepository,
	sender NotificationSender,
) *NotificationUsecase {
	return &NotificationUsecase{notifs: notifs, devices: devices, sender: sender}
}

// Notify creates an in-app notification and fires the push sender.
func (uc *NotificationUsecase) Notify(userID uint, ntype domain.NotificationType, title, body string, eventID *uint) {
	// 1. Persist in-app notification.
	n := &domain.Notification{
		UserID:  userID,
		Type:    ntype,
		Title:   title,
		Body:    body,
		EventID: eventID,
	}
	if err := uc.notifs.Create(n); err != nil {
		log.Printf("[notif] failed to persist notification for user %d: %v", userID, err)
	}

	// 2. Attempt push delivery (non-blocking, best-effort).
	if uc.sender != nil {
		if err := uc.sender.Send(userID, title, body); err != nil {
			log.Printf("[notif] push send failed for user %d: %v", userID, err)
		}
	}
}

// NotifyRegistrationSubmitted fires when a user applies to an event.
func (uc *NotificationUsecase) NotifyRegistrationSubmitted(userID uint, eventTitle string, eventID uint) {
	uc.Notify(
		userID,
		domain.NotifRegistrationSubmitted,
		"Application Submitted",
		fmt.Sprintf("Your application to \"%s\" has been submitted.", eventTitle),
		&eventID,
	)
}

// NotifyOrganizerNewRegistration fires when a student applies to an organizer's event.
func (uc *NotificationUsecase) NotifyOrganizerNewRegistration(userID uint, eventTitle string, eventID uint) {
	uc.Notify(
		userID,
		domain.NotifOrganizerNewRegistration,
		"New Event Application",
		fmt.Sprintf("A student has applied to \"%s\". Review participants to approve or reject.", eventTitle),
		&eventID,
	)
}

// NotifyRegistrationApproved fires when an organizer approves a registration.
func (uc *NotificationUsecase) NotifyRegistrationApproved(userID uint, eventTitle string, eventID uint) {
	uc.Notify(
		userID,
		domain.NotifRegistrationApproved,
		"Application Approved",
		fmt.Sprintf("You have been approved for \"%s\"!", eventTitle),
		&eventID,
	)
}

// NotifyRegistrationRejected fires when an organizer rejects a registration.
func (uc *NotificationUsecase) NotifyRegistrationRejected(userID uint, eventTitle string, eventID uint) {
	uc.Notify(
		userID,
		domain.NotifRegistrationRejected,
		"Application Rejected",
		fmt.Sprintf("Unfortunately, your application to \"%s\" was not accepted.", eventTitle),
		&eventID,
	)
}

// NotifyRegistrationCheckedIn fires when an organizer checks a participant in.
func (uc *NotificationUsecase) NotifyRegistrationCheckedIn(userID uint, eventTitle string, eventID uint) {
	uc.Notify(
		userID,
		domain.NotifRegistrationCheckedIn,
		"Checked In",
		fmt.Sprintf("You have been successfully checked in to \"%s\".", eventTitle),
		&eventID,
	)
}

// NotifyWaitlistPromoted fires when a waitlisted user is auto-promoted.
func (uc *NotificationUsecase) NotifyWaitlistPromoted(userID uint, eventTitle string, eventID uint) {
	uc.Notify(
		userID,
		domain.NotifWaitlistPromoted,
		"You Got a Spot!",
		fmt.Sprintf("A seat opened up — you've been approved for \"%s\"!", eventTitle),
		&eventID,
	)
}

// NotifyOrganizerApprovalPending fires to admins when a new organizer is awaiting approval.
func (uc *NotificationUsecase) NotifyOrganizerApprovalPending(userID uint, organizerName string) {
	uc.Notify(
		userID,
		domain.NotifOrganizerApprovalPending,
		"Organizer Approval Needed",
		fmt.Sprintf("%s registered as an organizer and is waiting for approval.", organizerName),
		nil,
	)
}

// ListNotifications returns recent notifications for a user.
func (uc *NotificationUsecase) ListNotifications(userID uint, unreadOnly bool, limit int) ([]domain.Notification, error) {
	return uc.notifs.ListByUser(userID, unreadOnly, limit)
}

// MarkRead marks a single notification as read.
func (uc *NotificationUsecase) MarkRead(userID, notifID uint) error {
	return uc.notifs.MarkRead(notifID, userID)
}

// MarkAllRead marks all user notifications as read.
func (uc *NotificationUsecase) MarkAllRead(userID uint) error {
	return uc.notifs.MarkAllRead(userID)
}

// CountUnread returns the number of unread notifications.
func (uc *NotificationUsecase) CountUnread(userID uint) (int64, error) {
	return uc.notifs.CountUnread(userID)
}

// RegisterDevice stores or updates a push device token.
func (uc *NotificationUsecase) RegisterDevice(userID uint, token, platform string) error {
	return uc.devices.Upsert(&domain.DeviceToken{
		UserID:   userID,
		Token:    token,
		Platform: platform,
	})
}

// UnregisterDevice removes a push device token.
func (uc *NotificationUsecase) UnregisterDevice(userID uint, token string) error {
	return uc.devices.Delete(userID, token)
}
