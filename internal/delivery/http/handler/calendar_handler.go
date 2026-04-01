package handler

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"eventapp/internal/app"
	"eventapp/internal/delivery/http/response"

	"github.com/gin-gonic/gin"
)

// CalendarHandler generates ICS calendar files for events.
type CalendarHandler struct {
	eventUC *app.EventUsecase
}

func NewCalendarHandler(eventUC *app.EventUsecase) *CalendarHandler {
	return &CalendarHandler{eventUC: eventUC}
}

// GetICS godoc
// @Summary      Download ICS calendar file for an event
// @Description  Returns an .ics file that can be imported into any calendar app
// @Tags         calendar
// @Produce      text/calendar
// @Security     BearerAuth
// @Param        id  path  int  true  "Event ID"
// @Success      200  {file}  file
// @Failure      404  {object}  response.ErrorBody
// @Router       /api/events/{id}/calendar.ics [get]
func (h *CalendarHandler) GetICS(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid event id", nil)
		return
	}

	event, err := h.eventUC.GetEvent(id)
	if err != nil {
		response.Err(c, err)
		return
	}

	// Build ICS content (RFC 5545).
	var b strings.Builder
	b.WriteString("BEGIN:VCALENDAR\r\n")
	b.WriteString("VERSION:2.0\r\n")
	b.WriteString("PRODID:-//EventApp//EN\r\n")
	b.WriteString("CALSCALE:GREGORIAN\r\n")
	b.WriteString("METHOD:PUBLISH\r\n")
	b.WriteString("BEGIN:VEVENT\r\n")
	b.WriteString(fmt.Sprintf("UID:event-%d@eventapp.local\r\n", event.ID))
	b.WriteString(fmt.Sprintf("DTSTAMP:%s\r\n", formatICSTime(time.Now())))
	b.WriteString(fmt.Sprintf("DTSTART:%s\r\n", formatICSTime(event.DateStart)))
	if event.DateEnd != nil {
		b.WriteString(fmt.Sprintf("DTEND:%s\r\n", formatICSTime(*event.DateEnd)))
	}
	b.WriteString(fmt.Sprintf("SUMMARY:%s\r\n", escapeICS(event.Title)))
	if event.Description != "" {
		b.WriteString(fmt.Sprintf("DESCRIPTION:%s\r\n", escapeICS(event.Description)))
	}
	location := event.City
	if event.Address != "" {
		if location != "" {
			location += ", "
		}
		location += event.Address
	}
	if location != "" {
		b.WriteString(fmt.Sprintf("LOCATION:%s\r\n", escapeICS(location)))
	}
	if event.Organizer != nil {
		b.WriteString(fmt.Sprintf("ORGANIZER;CN=%s:mailto:%s\r\n",
			escapeICS(event.Organizer.FullName), event.Organizer.Email))
	}
	b.WriteString("STATUS:CONFIRMED\r\n")
	b.WriteString("END:VEVENT\r\n")
	b.WriteString("END:VCALENDAR\r\n")

	filename := fmt.Sprintf("event_%d.ics", event.ID)
	c.Header("Content-Type", "text/calendar; charset=utf-8")
	c.Header("Content-Disposition", "attachment; filename="+filename)
	c.String(http.StatusOK, b.String())
}

func formatICSTime(t time.Time) string {
	return t.UTC().Format("20060102T150405Z")
}

func escapeICS(s string) string {
	s = strings.ReplaceAll(s, "\\", "\\\\")
	s = strings.ReplaceAll(s, ";", "\\;")
	s = strings.ReplaceAll(s, ",", "\\,")
	s = strings.ReplaceAll(s, "\n", "\\n")
	return s
}
