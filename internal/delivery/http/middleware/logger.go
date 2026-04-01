package middleware

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const CtxRequestID = "request_id"

// RequestID injects a unique request ID into every request.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := uuid.NewString()
		c.Set(CtxRequestID, id)
		c.Header("X-Request-ID", id)
		c.Next()
	}
}

// Logger logs each request with timing and user context.
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path

		c.Next()

		reqID, _ := c.Get(CtxRequestID)
		userID, _ := c.Get(CtxUserID)
		latency := time.Since(start)

		log.Printf("[%s] %s %s | status=%d latency=%s user=%v",
			reqID, c.Request.Method, path,
			c.Writer.Status(), latency, userID,
		)
	}
}
