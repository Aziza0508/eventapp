package notify

import "log"

// LogSender is a development NotificationSender that logs to stdout.
// Replace with APNsSender or FCMSender in production.
type LogSender struct{}

func NewLogSender() *LogSender { return &LogSender{} }

func (s *LogSender) Send(userID uint, title, body string) error {
	log.Printf("[push/dev] → user=%d title=%q body=%q", userID, title, body)
	return nil
}
