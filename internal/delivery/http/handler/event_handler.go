package handler

import (
	"strconv"
	"strings"
	"time"

	"eventapp/internal/app"
	"eventapp/internal/delivery/http/dto"
	"eventapp/internal/delivery/http/middleware"
	"eventapp/internal/delivery/http/response"
	"eventapp/internal/domain"

	"github.com/gin-gonic/gin"
)

// EventHandler handles event CRUD endpoints.
type EventHandler struct {
	uc   *app.EventUsecase
	favs *app.FavoriteUsecase
}

func NewEventHandler(uc *app.EventUsecase, favs *app.FavoriteUsecase) *EventHandler {
	return &EventHandler{uc: uc, favs: favs}
}

// Create godoc
// @Summary      Create a new event
// @Description  Only approved organizers may create events. A unique checkin_token is generated automatically.
// @Tags         events
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body  body      dto.CreateEventRequest  true  "Event payload"
// @Success      201   {object}  domain.Event
// @Failure      400   {object}  response.ErrorBody
// @Failure      403   {object}  response.ErrorBody
// @Router       /api/events [post]
func (h *EventHandler) Create(c *gin.Context) {
	var req dto.CreateEventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, err.Error(), nil)
		return
	}

	callerID := middleware.UserIDFromCtx(c)

	isFree := true
	if req.IsFree != nil {
		isFree = *req.IsFree
	}

	event, err := h.uc.CreateEvent(app.CreateEventInput{
		Title:            req.Title,
		Description:      req.Description,
		Category:         req.Category,
		Tags:             req.Tags,
		Format:           req.Format,
		City:             req.City,
		Address:          req.Address,
		Latitude:         req.Latitude,
		Longitude:        req.Longitude,
		OrganizerContact: req.OrganizerContact,
		AdditionalInfo:   req.AdditionalInfo,
		DateStart:        req.DateStart,
		DateEnd:          req.DateEnd,
		RegDeadline:      req.RegDeadline,
		Capacity:         req.Capacity,
		IsFree:           isFree,
		Price:            req.Price,
		PosterURL:        req.PosterURL,
		OrganizerID:      callerID,
	})
	if err != nil {
		response.Err(c, err)
		return
	}

	response.Created(c, event)
}

// List godoc
// @Summary      List events
// @Description  Returns a paginated, filterable list of events. Supports advanced filters.
// @Tags         events
// @Produce      json
// @Security     BearerAuth
// @Param        city      query  string  false  "Filter by city"
// @Param        category  query  string  false  "Filter by category"
// @Param        format    query  string  false  "Filter by format"
// @Param        search    query  string  false  "Search title/description"
// @Param        tags      query  string  false  "Comma-separated tags"
// @Param        is_free   query  string  false  "true or false"
// @Param        date_from query  string  false  "RFC3339 date"
// @Param        date_to   query  string  false  "RFC3339 date"
// @Param        page      query  int     false  "Page number"
// @Param        limit     query  int     false  "Page size"
// @Success      200  {object}  dto.EventListResponse
// @Router       /api/events [get]
func (h *EventHandler) List(c *gin.Context) {
	var q dto.EventListFilter
	if err := c.ShouldBindQuery(&q); err != nil {
		response.ValidationErr(c, err.Error(), nil)
		return
	}

	filter := domain.EventFilter{
		City:     q.City,
		Category: q.Category,
		Format:   domain.EventFormat(q.Format),
		Search:   q.Search,
		Page:     q.Page,
		Limit:    q.Limit,
	}

	// Parse tags
	if q.Tags != "" {
		for _, t := range strings.Split(q.Tags, ",") {
			t = strings.TrimSpace(t)
			if t != "" {
				filter.Tags = append(filter.Tags, t)
			}
		}
	}

	// Parse is_free
	if q.IsFree == "true" {
		f := true
		filter.IsFree = &f
	} else if q.IsFree == "false" {
		f := false
		filter.IsFree = &f
	}

	// Parse date range
	if q.DateFrom != "" {
		if t, err := time.Parse(time.RFC3339, q.DateFrom); err == nil {
			filter.DateFrom = &t
		}
	}
	if q.DateTo != "" {
		if t, err := time.Parse(time.RFC3339, q.DateTo); err == nil {
			filter.DateTo = &t
		}
	}

	events, total, err := h.uc.ListEvents(filter)
	if err != nil {
		response.Err(c, err)
		return
	}

	if filter.Limit == 0 {
		filter.Limit = 20
	}

	response.OK(c, dto.EventListResponse{
		Data:  events,
		Total: total,
		Page:  filter.Page,
		Limit: filter.Limit,
	})
}

// GetByID godoc
// @Summary      Get event by ID
// @Description  Returns event details including free seats and favorite status for the caller.
// @Tags         events
// @Produce      json
// @Security     BearerAuth
// @Param        id   path  int  true  "Event ID"
// @Success      200  {object}  dto.EventDetailResponse
// @Failure      404  {object}  response.ErrorBody
// @Router       /api/events/{id} [get]
func (h *EventHandler) GetByID(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid event id", nil)
		return
	}

	event, err := h.uc.GetEvent(id)
	if err != nil {
		response.Err(c, err)
		return
	}

	freeSeats, _ := h.uc.GetEventFreeSeats(id)

	isFav := false
	callerID := middleware.UserIDFromCtx(c)
	if h.favs != nil && callerID > 0 {
		isFav, _ = h.favs.IsFavorite(callerID, id)
	}

	response.OK(c, dto.EventDetailResponse{
		Event:      *event,
		FreeSeats:  freeSeats,
		IsFavorite: isFav,
	})
}

// Update godoc
// @Summary      Update event
// @Description  Only the approved organizer who created the event can update it.
// @Tags         events
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        id    path  int                     true  "Event ID"
// @Param        body  body  dto.UpdateEventRequest  true  "Updated fields"
// @Success      200  {object}  domain.Event
// @Failure      403  {object}  response.ErrorBody
// @Failure      404  {object}  response.ErrorBody
// @Router       /api/events/{id} [put]
func (h *EventHandler) Update(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid event id", nil)
		return
	}

	var req dto.UpdateEventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.ValidationErr(c, err.Error(), nil)
		return
	}

	callerID := middleware.UserIDFromCtx(c)

	event, err := h.uc.UpdateEvent(callerID, id, app.UpdateEventInput{
		Title:            req.Title,
		Description:      req.Description,
		Category:         req.Category,
		Tags:             req.Tags,
		Format:           req.Format,
		City:             req.City,
		Address:          req.Address,
		Latitude:         req.Latitude,
		Longitude:        req.Longitude,
		OrganizerContact: req.OrganizerContact,
		AdditionalInfo:   req.AdditionalInfo,
		DateStart:        req.DateStart,
		DateEnd:          req.DateEnd,
		RegDeadline:      req.RegDeadline,
		Capacity:         req.Capacity,
		IsFree:           req.IsFree,
		Price:            req.Price,
		PosterURL:        req.PosterURL,
	})
	if err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, event)
}

// Delete godoc
// @Summary      Delete event
// @Description  Only the approved organizer who created the event can delete it.
// @Tags         events
// @Produce      json
// @Security     BearerAuth
// @Param        id  path  int  true  "Event ID"
// @Success      200  {object}  map[string]string
// @Failure      403  {object}  response.ErrorBody
// @Failure      404  {object}  response.ErrorBody
// @Router       /api/events/{id} [delete]
func (h *EventHandler) Delete(c *gin.Context) {
	id, err := parseID(c)
	if err != nil {
		response.ValidationErr(c, "invalid event id", nil)
		return
	}

	callerID := middleware.UserIDFromCtx(c)

	if err := h.uc.DeleteEvent(callerID, id); err != nil {
		response.Err(c, err)
		return
	}

	response.OK(c, gin.H{"message": "event deleted"})
}

// parseID is a helper to parse uint path param :id.
func parseID(c *gin.Context) (uint, error) {
	v, err := strconv.ParseUint(c.Param("id"), 10, 64)
	return uint(v), err
}
