package middleware

import (
	"net/http"
	"strings"

	"eventapp/internal/delivery/http/response"
	"eventapp/internal/domain"

	"github.com/gin-gonic/gin"
)

// contextKey avoids string collision in gin context.
const (
	CtxUserID = "ctx_user_id"
	CtxRole   = "ctx_role"
)

// JWTValidator is a minimal interface for the middleware dependency.
type JWTValidator interface {
	Validate(token string) (uint, domain.UserRole, error)
}

// Auth returns a middleware that validates the JWT and injects userID + role into context.
func Auth(jwt JWTValidator) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.ErrorBody{
				Error: response.APIError{Code: "UNAUTHORIZED", Message: "Authorization header missing"},
			})
			return
		}

		tokenStr := strings.TrimPrefix(header, "Bearer ")
		tokenStr = strings.TrimSpace(tokenStr)

		userID, role, err := jwt.Validate(tokenStr)
		if err != nil {
			response.Err(c, err)
			return
		}

		c.Set(CtxUserID, userID)
		c.Set(CtxRole, role)
		c.Next()
	}
}

// RequireRole returns a middleware that aborts if the caller's role is not in the allowed list.
func RequireRole(roles ...domain.UserRole) gin.HandlerFunc {
	allowed := make(map[domain.UserRole]struct{}, len(roles))
	for _, r := range roles {
		allowed[r] = struct{}{}
	}
	return func(c *gin.Context) {
		roleVal, exists := c.Get(CtxRole)
		if !exists {
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.ErrorBody{
				Error: response.APIError{Code: "UNAUTHORIZED", Message: "not authenticated"},
			})
			return
		}
		role, ok := roleVal.(domain.UserRole)
		if !ok {
			c.AbortWithStatusJSON(http.StatusInternalServerError, response.ErrorBody{
				Error: response.APIError{Code: "INTERNAL_ERROR", Message: "role context error"},
			})
			return
		}
		if _, ok := allowed[role]; !ok {
			c.AbortWithStatusJSON(http.StatusForbidden, response.ErrorBody{
				Error: response.APIError{Code: "FORBIDDEN", Message: "insufficient permissions"},
			})
			return
		}
		c.Next()
	}
}

// UserIDFromCtx extracts the authenticated user's ID from the gin context.
func UserIDFromCtx(c *gin.Context) uint {
	v, _ := c.Get(CtxUserID)
	id, _ := v.(uint)
	return id
}

// RoleFromCtx extracts the authenticated user's role from the gin context.
func RoleFromCtx(c *gin.Context) domain.UserRole {
	v, _ := c.Get(CtxRole)
	r, _ := v.(domain.UserRole)
	return r
}
