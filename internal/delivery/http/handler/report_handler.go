package handler

import (
	"encoding/csv"
	"fmt"
	"net/http"
	"time"

	"eventapp/internal/app"
	"eventapp/internal/delivery/http/middleware"
	"eventapp/internal/delivery/http/response"

	"github.com/gin-gonic/gin"
)

// ReportHandler handles report generation endpoints.
type ReportHandler struct {
	uc *app.ReportUsecase
}

func NewReportHandler(uc *app.ReportUsecase) *ReportHandler {
	return &ReportHandler{uc: uc}
}

// AttendanceJSON godoc
// @Summary      Event attendance report (JSON)
// @Description  Returns a structured attendance report with status breakdown. Organizer/admin only.
// @Tags         reports
// @Produce      json
// @Security     BearerAuth
// @Param        id  path  int  true  "Event ID"
// @Success      200  {object}  app.AttendanceReport
// @Failure      403  {object}  response.ErrorBody
// @Failure      404  {object}  response.ErrorBody
// @Router       /api/reports/events/{id}/attendance [get]
func (h *ReportHandler) AttendanceJSON(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid event id", nil)
		return
	}

	callerID := middleware.UserIDFromCtx(c)

	report, err := h.uc.GetAttendanceReport(callerID, id)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, report)
}

// AttendanceCSV godoc
// @Summary      Event attendance report (CSV)
// @Description  Downloads attendance as CSV with participant details and status. Organizer/admin only.
// @Tags         reports
// @Produce      text/csv
// @Security     BearerAuth
// @Param        id  path  int  true  "Event ID"
// @Success      200  {file}  file
// @Failure      403  {object}  response.ErrorBody
// @Failure      404  {object}  response.ErrorBody
// @Router       /api/reports/events/{id}/attendance.csv [get]
func (h *ReportHandler) AttendanceCSV(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid event id", nil)
		return
	}

	callerID := middleware.UserIDFromCtx(c)

	report, err := h.uc.GetAttendanceReport(callerID, id)
	if err != nil {
		response.Err(c, err)
		return
	}

	filename := fmt.Sprintf("attendance_%d_%s.csv", id, time.Now().Format("20060102"))
	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", "attachment; filename="+filename)

	w := csv.NewWriter(c.Writer)
	defer w.Flush()

	// Metadata header.
	w.Write([]string{"# Event", report.EventTitle})
	w.Write([]string{"# Date", report.EventDate.Format("2006-01-02")})
	w.Write([]string{"# Capacity", fmt.Sprintf("%d", report.Capacity)})
	w.Write([]string{""})

	// Data header.
	w.Write([]string{"Name", "Email", "School", "City", "Grade", "Status", "Checked In At", "Applied At"})

	for _, row := range report.Rows {
		grade := ""
		if row.Grade > 0 {
			grade = fmt.Sprintf("%d", row.Grade)
		}
		checkedIn := ""
		if row.CheckedInAt != nil {
			checkedIn = row.CheckedInAt.Format(time.RFC3339)
		}
		w.Write([]string{
			row.UserName, row.UserEmail, row.School, row.City, grade,
			row.Status, checkedIn, row.AppliedAt.Format(time.RFC3339),
		})
	}

	c.Status(http.StatusOK)
}

// OrganizerSummary godoc
// @Summary      Organizer summary report
// @Description  Returns aggregated stats for all events belonging to the authenticated organizer: participant counts, fill rate, check-in rate.
// @Tags         reports
// @Produce      json
// @Security     BearerAuth
// @Param        date_from  query  string  false  "Start date filter (RFC3339)"
// @Param        date_to    query  string  false  "End date filter (RFC3339)"
// @Success      200  {object}  app.OrganizerSummary
// @Failure      403  {object}  response.ErrorBody
// @Router       /api/reports/organizer/summary [get]
func (h *ReportHandler) OrganizerSummary(c *gin.Context) {
	callerID := middleware.UserIDFromCtx(c)

	var dateFrom, dateTo *time.Time
	if v := c.Query("date_from"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			dateFrom = &t
		}
	}
	if v := c.Query("date_to"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			dateTo = &t
		}
	}

	summary, err := h.uc.GetOrganizerSummary(callerID, dateFrom, dateTo)
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, summary)
}

// OrganizerSummaryCSV godoc
// @Summary      Organizer summary report (CSV)
// @Description  Downloads the organizer summary as CSV.
// @Tags         reports
// @Produce      text/csv
// @Security     BearerAuth
// @Param        date_from  query  string  false  "Start date filter (RFC3339)"
// @Param        date_to    query  string  false  "End date filter (RFC3339)"
// @Success      200  {file}  file
// @Router       /api/reports/organizer/summary.csv [get]
func (h *ReportHandler) OrganizerSummaryCSV(c *gin.Context) {
	callerID := middleware.UserIDFromCtx(c)

	var dateFrom, dateTo *time.Time
	if v := c.Query("date_from"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			dateFrom = &t
		}
	}
	if v := c.Query("date_to"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			dateTo = &t
		}
	}

	summary, err := h.uc.GetOrganizerSummary(callerID, dateFrom, dateTo)
	if err != nil {
		response.Err(c, err)
		return
	}

	filename := fmt.Sprintf("organizer_summary_%s.csv", time.Now().Format("20060102"))
	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", "attachment; filename="+filename)

	w := csv.NewWriter(c.Writer)
	defer w.Flush()

	w.Write([]string{
		"Event ID", "Title", "Date", "Capacity",
		"Registered", "Approved", "Checked In", "Completed",
		"Rejected", "Waitlisted", "Cancelled",
		"Fill Rate %", "Check-in Rate %",
	})

	for _, e := range summary.Events {
		w.Write([]string{
			fmt.Sprintf("%d", e.EventID),
			e.Title,
			e.DateStart.Format("2006-01-02"),
			fmt.Sprintf("%d", e.Capacity),
			fmt.Sprintf("%d", e.Registered),
			fmt.Sprintf("%d", e.Approved),
			fmt.Sprintf("%d", e.CheckedIn),
			fmt.Sprintf("%d", e.Completed),
			fmt.Sprintf("%d", e.Rejected),
			fmt.Sprintf("%d", e.Waitlisted),
			fmt.Sprintf("%d", e.Cancelled),
			fmt.Sprintf("%.1f", e.FillRate),
			fmt.Sprintf("%.1f", e.CheckinRate),
		})
	}

	// Totals row.
	w.Write([]string{
		"", "TOTAL", "", "",
		fmt.Sprintf("%d", summary.TotalRegistered),
		"", fmt.Sprintf("%d", summary.TotalCheckedIn), "",
		"", "", "",
		fmt.Sprintf("%.1f", summary.AvgFillRate), "",
	})

	c.Status(http.StatusOK)
}
