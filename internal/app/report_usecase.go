package app

import (
	"time"

	"eventapp/internal/domain"
)

// ReportUsecase generates structured reports from existing data.
// It composes existing repositories without duplicating business logic.
type ReportUsecase struct {
	events EventRepository
	regs   RegistrationRepository
}

func NewReportUsecase(events EventRepository, regs RegistrationRepository) *ReportUsecase {
	return &ReportUsecase{events: events, regs: regs}
}

// ── Event Attendance Report (REP-1) ──────────────────────────────────────────

// AttendanceRow is one row of the attendance report.
type AttendanceRow struct {
	UserName    string     `json:"user_name"`
	UserEmail   string     `json:"user_email"`
	School      string     `json:"school"`
	City        string     `json:"city"`
	Grade       int        `json:"grade,omitempty"`
	Status      string     `json:"status"`
	CheckedInAt *time.Time `json:"checked_in_at,omitempty"`
	AppliedAt   time.Time  `json:"applied_at"`
}

// AttendanceReport is the full attendance report for one event.
type AttendanceReport struct {
	EventID     uint             `json:"event_id"`
	EventTitle  string           `json:"event_title"`
	EventDate   time.Time        `json:"event_date"`
	Capacity    int              `json:"capacity"`
	StatusCount map[string]int64 `json:"status_count"`
	TotalRows   int              `json:"total_rows"`
	Rows        []AttendanceRow  `json:"rows"`
}

// GetAttendanceReport builds the attendance report for a single event.
// The caller must be the event organizer or an admin (enforced at handler level via the callerID check).
func (uc *ReportUsecase) GetAttendanceReport(callerID, eventID uint) (*AttendanceReport, error) {
	event, err := uc.events.GetByID(eventID)
	if err != nil {
		return nil, domain.ErrNotFound
	}
	if event.OrganizerID != callerID {
		return nil, domain.ErrForbidden
	}

	regs, err := uc.regs.ListByEvent(eventID)
	if err != nil {
		return nil, err
	}

	statusCounts, _ := uc.regs.CountByEventAndStatus(eventID)
	sc := make(map[string]int64)
	for k, v := range statusCounts {
		sc[string(k)] = v
	}

	rows := make([]AttendanceRow, 0, len(regs))
	for _, r := range regs {
		row := AttendanceRow{
			Status:      string(r.Status),
			CheckedInAt: r.CheckedInAt,
			AppliedAt:   r.CreatedAt,
		}
		if r.User != nil {
			row.UserName = r.User.FullName
			row.UserEmail = r.User.Email
			row.School = r.User.School
			row.City = r.User.City
			row.Grade = r.User.Grade
		}
		rows = append(rows, row)
	}

	return &AttendanceReport{
		EventID:     event.ID,
		EventTitle:  event.Title,
		EventDate:   event.DateStart,
		Capacity:    event.Capacity,
		StatusCount: sc,
		TotalRows:   len(rows),
		Rows:        rows,
	}, nil
}

// ── Organizer Summary Report (REP-2) ─────────────────────────────────────────

// EventSummaryRow is one event in the organizer summary.
type EventSummaryRow struct {
	EventID       uint      `json:"event_id"`
	Title         string    `json:"title"`
	DateStart     time.Time `json:"date_start"`
	Capacity      int       `json:"capacity"`
	Registered    int64     `json:"registered"`
	Approved      int64     `json:"approved"`
	CheckedIn     int64     `json:"checked_in"`
	Completed     int64     `json:"completed"`
	Rejected      int64     `json:"rejected"`
	Waitlisted    int64     `json:"waitlisted"`
	Cancelled     int64     `json:"cancelled"`
	FillRate      float64   `json:"fill_rate_pct"`
	CheckinRate   float64   `json:"checkin_rate_pct"`
}

// OrganizerSummary is the aggregated report for one organizer.
type OrganizerSummary struct {
	OrganizerID       uint              `json:"organizer_id"`
	TotalEvents       int               `json:"total_events"`
	TotalRegistered   int64             `json:"total_registered"`
	TotalCheckedIn    int64             `json:"total_checked_in"`
	AvgFillRate       float64           `json:"avg_fill_rate_pct"`
	Events            []EventSummaryRow `json:"events"`
}

// GetOrganizerSummary builds an aggregated report for the organizer's events.
// dateFrom/dateTo are optional date range filters.
func (uc *ReportUsecase) GetOrganizerSummary(organizerID uint, dateFrom, dateTo *time.Time) (*OrganizerSummary, error) {
	filter := domain.EventFilter{Page: 1, Limit: 1000}
	if dateFrom != nil {
		filter.DateFrom = dateFrom
	}
	if dateTo != nil {
		filter.DateTo = dateTo
	}

	allEvents, _, err := uc.events.List(filter)
	if err != nil {
		return nil, err
	}

	// Filter to only this organizer's events.
	var myEvents []domain.Event
	for _, e := range allEvents {
		if e.OrganizerID == organizerID {
			myEvents = append(myEvents, e)
		}
	}

	summary := &OrganizerSummary{
		OrganizerID: organizerID,
		TotalEvents: len(myEvents),
		Events:      make([]EventSummaryRow, 0, len(myEvents)),
	}

	var totalFillRateSum float64
	var fillRateCount int

	for _, e := range myEvents {
		counts, _ := uc.regs.CountByEventAndStatus(e.ID)

		registered := int64(0)
		for _, c := range counts {
			registered += c
		}

		row := EventSummaryRow{
			EventID:    e.ID,
			Title:      e.Title,
			DateStart:  e.DateStart,
			Capacity:   e.Capacity,
			Registered: registered,
			Approved:   counts[domain.StatusApproved],
			CheckedIn:  counts[domain.StatusCheckedIn],
			Completed:  counts[domain.StatusCompleted],
			Rejected:   counts[domain.StatusRejected],
			Waitlisted: counts[domain.StatusWaitlisted],
			Cancelled:  counts[domain.StatusCancelled],
		}

		if e.Capacity > 0 {
			active := counts[domain.StatusPending] + counts[domain.StatusApproved] +
				counts[domain.StatusCheckedIn] + counts[domain.StatusCompleted]
			row.FillRate = float64(active) / float64(e.Capacity) * 100
			totalFillRateSum += row.FillRate
			fillRateCount++
		}

		confirmed := counts[domain.StatusApproved] + counts[domain.StatusCheckedIn] + counts[domain.StatusCompleted]
		if confirmed > 0 {
			row.CheckinRate = float64(counts[domain.StatusCheckedIn]+counts[domain.StatusCompleted]) / float64(confirmed) * 100
		}

		summary.TotalRegistered += registered
		summary.TotalCheckedIn += counts[domain.StatusCheckedIn] + counts[domain.StatusCompleted]
		summary.Events = append(summary.Events, row)
	}

	if fillRateCount > 0 {
		summary.AvgFillRate = totalFillRateSum / float64(fillRateCount)
	}

	return summary, nil
}
