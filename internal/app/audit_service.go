package app

import (
	"fmt"
	"log"

	"eventapp/internal/domain"
)

// AuditService provides a simple API for recording audit events.
// It is designed to be injected into any usecase that needs logging.
type AuditService struct {
	repo AuditLogRepository
}

func NewAuditService(repo AuditLogRepository) *AuditService {
	return &AuditService{repo: repo}
}

// Record persists an audit log entry. Failures are logged but never propagated.
func (s *AuditService) Record(actorID uint, action domain.AuditAction, entityType string, entityID uint, summary string, ip string) {
	entry := &domain.AuditLog{
		ActorID:    actorID,
		Action:     action,
		EntityType: entityType,
		EntityID:   entityID,
		Summary:    summary,
		IP:         ip,
	}
	if err := s.repo.Create(entry); err != nil {
		log.Printf("[audit] failed to record: actor=%d action=%s err=%v", actorID, action, err)
	}
}

// Recordf is a convenience wrapper with fmt.Sprintf for the summary.
func (s *AuditService) Recordf(actorID uint, action domain.AuditAction, entityType string, entityID uint, ip string, format string, args ...interface{}) {
	s.Record(actorID, action, entityType, entityID, fmt.Sprintf(format, args...), ip)
}

// RecentLogs returns the most recent audit entries.
func (s *AuditService) RecentLogs(limit int) ([]domain.AuditLog, error) {
	return s.repo.List(limit)
}
