package dto

import (
	"time"

	"eventapp/internal/domain"
)

// CreateEventRequest is the body for POST /api/events.
type CreateEventRequest struct {
	Title            string             `json:"title"             binding:"required"`
	Description      string             `json:"description"`
	Category         string             `json:"category"`
	Tags             []string           `json:"tags"`
	Format           domain.EventFormat `json:"format"`
	City             string             `json:"city"`
	Address          string             `json:"address"`
	Latitude         *float64           `json:"latitude"`
	Longitude        *float64           `json:"longitude"`
	OrganizerContact string             `json:"organizer_contact"`
	AdditionalInfo   string             `json:"additional_info"`
	DateStart        time.Time          `json:"date_start"        binding:"required"`
	DateEnd          *time.Time         `json:"date_end"`
	RegDeadline      *time.Time         `json:"reg_deadline"`
	Capacity         int                `json:"capacity"`
	IsFree           *bool              `json:"is_free"`
	Price            float64            `json:"price"`
}

// UpdateEventRequest is the body for PUT /api/events/:id.
type UpdateEventRequest struct {
	Title            string             `json:"title"`
	Description      string             `json:"description"`
	Category         string             `json:"category"`
	Tags             []string           `json:"tags"`
	Format           domain.EventFormat `json:"format"`
	City             string             `json:"city"`
	Address          string             `json:"address"`
	Latitude         *float64           `json:"latitude"`
	Longitude        *float64           `json:"longitude"`
	OrganizerContact string             `json:"organizer_contact"`
	AdditionalInfo   string             `json:"additional_info"`
	DateStart        time.Time          `json:"date_start"`
	DateEnd          *time.Time         `json:"date_end"`
	RegDeadline      *time.Time         `json:"reg_deadline"`
	Capacity         int                `json:"capacity"`
	IsFree           *bool              `json:"is_free"`
	Price            *float64           `json:"price"`
	PosterURL        string             `json:"poster_url"`
}

// EventListFilter holds query parameters for GET /api/events.
type EventListFilter struct {
	City     string `form:"city"`
	Category string `form:"category"`
	Format   string `form:"format"`
	Search   string `form:"search"`
	Tags     string `form:"tags"`
	IsFree   string `form:"is_free"`
	DateFrom string `form:"date_from"`
	DateTo   string `form:"date_to"`
	Page     int    `form:"page"`
	Limit    int    `form:"limit"`
}

// EventListResponse is the paginated response for GET /api/events.
type EventListResponse struct {
	Data  []domain.Event `json:"data"`
	Total int64          `json:"total"`
	Page  int            `json:"page"`
	Limit int            `json:"limit"`
}

// EventDetailResponse enriches the event with computed fields.
type EventDetailResponse struct {
	domain.Event
	FreeSeats  int  `json:"free_seats"`
	IsFavorite bool `json:"is_favorite"`
}
