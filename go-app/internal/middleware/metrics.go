package middleware

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
)

var (
	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "Duration of HTTP requests in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint", "status_code"},
	)

	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status_code"},
	)

	activeConnections = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "http_active_connections",
			Help: "Number of active HTTP connections",
		},
	)
)

func init() {
	prometheus.MustRegister(httpRequestDuration)
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(activeConnections)
}

func MetricsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		activeConnections.Inc()

		c.Next()

		duration := time.Since(start)
		statusCode := strconv.Itoa(c.Writer.Status())
		endpoint := c.FullPath()
		if endpoint == "" {
			endpoint = "unknown"
		}

		httpRequestDuration.WithLabelValues(c.Request.Method, endpoint, statusCode).Observe(duration.Seconds())
		httpRequestsTotal.WithLabelValues(c.Request.Method, endpoint, statusCode).Inc()
		activeConnections.Dec()
	}
}