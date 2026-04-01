package middleware

import (
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gin-gonic/gin"
)

// Metrics collects basic request counters and latency for observability.
// This is a lightweight in-process implementation suitable for diploma demo.
// For production, replace with Prometheus client_golang or OpenTelemetry.
type Metrics struct {
	totalRequests  atomic.Int64
	totalErrors    atomic.Int64
	latencyBuckets sync.Map // string(bucket) → *atomic.Int64
	statusCounts   sync.Map // string(statusCode) → *atomic.Int64
	startTime      time.Time
}

// NewMetrics creates a new metrics collector.
func NewMetrics() *Metrics {
	return &Metrics{startTime: time.Now()}
}

// Middleware returns a gin middleware that records request metrics.
func (m *Metrics) Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()

		m.totalRequests.Add(1)

		status := c.Writer.Status()
		if status >= 400 {
			m.totalErrors.Add(1)
		}

		// Count by status code.
		key := strconv.Itoa(status)
		val, _ := m.statusCounts.LoadOrStore(key, &atomic.Int64{})
		val.(*atomic.Int64).Add(1)

		// Latency bucket (for simple histogram).
		latency := time.Since(start)
		bucket := latencyBucket(latency)
		bval, _ := m.latencyBuckets.LoadOrStore(bucket, &atomic.Int64{})
		bval.(*atomic.Int64).Add(1)
	}
}

// Handler returns a gin handler for GET /metrics.
func (m *Metrics) Handler() gin.HandlerFunc {
	return func(c *gin.Context) {
		statuses := make(map[string]int64)
		m.statusCounts.Range(func(k, v any) bool {
			statuses[k.(string)] = v.(*atomic.Int64).Load()
			return true
		})

		buckets := make(map[string]int64)
		m.latencyBuckets.Range(func(k, v any) bool {
			buckets[k.(string)] = v.(*atomic.Int64).Load()
			return true
		})

		c.JSON(200, gin.H{
			"uptime_seconds":  int(time.Since(m.startTime).Seconds()),
			"total_requests":  m.totalRequests.Load(),
			"total_errors":    m.totalErrors.Load(),
			"status_counts":   statuses,
			"latency_buckets": buckets,
		})
	}
}

func latencyBucket(d time.Duration) string {
	switch {
	case d < 50*time.Millisecond:
		return "<50ms"
	case d < 200*time.Millisecond:
		return "50-200ms"
	case d < 500*time.Millisecond:
		return "200-500ms"
	case d < time.Second:
		return "500ms-1s"
	default:
		return ">1s"
	}
}
