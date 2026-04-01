package domain

import "errors"

// AppError is a typed application error that carries an HTTP-friendly code.
type AppError struct {
	Code    string
	Message string
	Err     error
}

func (e *AppError) Error() string { return e.Message }
func (e *AppError) Unwrap() error { return e.Err }

// Sentinel errors — usecases return these; HTTP layer maps them to status codes.
var (
	ErrNotFound        = &AppError{Code: "NOT_FOUND", Message: "resource not found"}
	ErrAlreadyExists   = &AppError{Code: "ALREADY_EXISTS", Message: "resource already exists"}
	ErrForbidden       = &AppError{Code: "FORBIDDEN", Message: "access denied"}
	ErrUnauthorized    = &AppError{Code: "UNAUTHORIZED", Message: "authentication required"}
	ErrValidation      = &AppError{Code: "VALIDATION_ERROR", Message: "validation failed"}
	ErrConflict        = &AppError{Code: "CONFLICT", Message: "conflict"}
	ErrStatusTransition = &AppError{Code: "INVALID_STATUS_TRANSITION", Message: "invalid status transition"}
	ErrAccountPending   = &AppError{Code: "ACCOUNT_PENDING", Message: "account is pending approval"}
	ErrTokenRevoked     = &AppError{Code: "TOKEN_REVOKED", Message: "refresh token has been revoked"}
	ErrTokenExpired     = &AppError{Code: "TOKEN_EXPIRED", Message: "token has expired"}
)

// Is allows errors.Is to match AppError by Code.
func Is(target, err error) bool {
	var t, e *AppError
	if errors.As(target, &t) && errors.As(err, &e) {
		return t.Code == e.Code
	}
	return false
}

// New creates a new AppError wrapping a cause.
func NewAppError(code, message string, cause error) *AppError {
	return &AppError{Code: code, Message: message, Err: cause}
}
