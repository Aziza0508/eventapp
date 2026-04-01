package response

import (
	"errors"
	"net/http"

	"eventapp/internal/domain"

	"github.com/gin-gonic/gin"
)

// ErrorBody is the standard error envelope.
type ErrorBody struct {
	Error APIError `json:"error"`
}

// APIError carries a machine-readable code and human-readable message.
type APIError struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

// OK writes a 200 response.
func OK(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, data)
}

// Created writes a 201 response.
func Created(c *gin.Context, data interface{}) {
	c.JSON(http.StatusCreated, data)
}

// Err maps a domain error to the correct HTTP status and writes the error envelope.
func Err(c *gin.Context, err error) {
	var appErr *domain.AppError
	if errors.As(err, &appErr) {
		status := codeToStatus(appErr.Code)
		c.AbortWithStatusJSON(status, ErrorBody{Error: APIError{
			Code:    appErr.Code,
			Message: appErr.Message,
		}})
		return
	}
	// Unexpected error — do not leak internals
	c.AbortWithStatusJSON(http.StatusInternalServerError, ErrorBody{Error: APIError{
		Code:    "INTERNAL_ERROR",
		Message: "an unexpected error occurred",
	}})
}

// ValidationErr writes a 400 with field-level details.
func ValidationErr(c *gin.Context, message string, details interface{}) {
	c.AbortWithStatusJSON(http.StatusBadRequest, ErrorBody{Error: APIError{
		Code:    "VALIDATION_ERROR",
		Message: message,
		Details: details,
	}})
}

func codeToStatus(code string) int {
	switch code {
	case "NOT_FOUND":
		return http.StatusNotFound
	case "ALREADY_EXISTS", "CONFLICT":
		return http.StatusConflict
	case "FORBIDDEN", "ACCOUNT_PENDING":
		return http.StatusForbidden
	case "UNAUTHORIZED", "INVALID_TOKEN", "TOKEN_EXPIRED", "TOKEN_REVOKED":
		return http.StatusUnauthorized
	case "VALIDATION_ERROR", "CAPACITY_EXCEEDED", "INVALID_STATUS_TRANSITION":
		return http.StatusBadRequest
	default:
		return http.StatusInternalServerError
	}
}
