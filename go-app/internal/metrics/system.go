package metrics

import (
	"runtime"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

var (
	goroutinesGauge = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "benchmark_goroutines_active",
			Help: "Number of active goroutines",
		},
	)

	memoryUsageGauge = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "benchmark_memory_usage_bytes",
			Help: "Memory usage in bytes by type",
		},
		[]string{"type"},
	)

	gcDurationHistogram = prometheus.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "benchmark_gc_duration_seconds",
			Help:    "Time spent in garbage collection",
			Buckets: prometheus.DefBuckets,
		},
	)

	dbConnectionsGauge = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "database_connections",
			Help: "Number of database connections",
		},
		[]string{"state"},
	)
)

func init() {
	prometheus.MustRegister(goroutinesGauge)
	prometheus.MustRegister(memoryUsageGauge)
	prometheus.MustRegister(gcDurationHistogram)
	prometheus.MustRegister(dbConnectionsGauge)
}

func StartSystemMetricsCollection() {
	go func() {
		ticker := time.NewTicker(15 * time.Second)
		defer ticker.Stop()

		for range ticker.C {
			collectSystemMetrics()
		}
	}()
}

func collectSystemMetrics() {
	goroutinesGauge.Set(float64(runtime.NumGoroutine()))

	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)

	memoryUsageGauge.WithLabelValues("heap_alloc").Set(float64(memStats.HeapAlloc))
	memoryUsageGauge.WithLabelValues("heap_sys").Set(float64(memStats.HeapSys))
	memoryUsageGauge.WithLabelValues("heap_idle").Set(float64(memStats.HeapIdle))
	memoryUsageGauge.WithLabelValues("heap_inuse").Set(float64(memStats.HeapInuse))
	memoryUsageGauge.WithLabelValues("stack_inuse").Set(float64(memStats.StackInuse))
	memoryUsageGauge.WithLabelValues("stack_sys").Set(float64(memStats.StackSys))

	gcDurationHistogram.Observe(float64(memStats.PauseTotalNs) / 1e9)
}

func UpdateDatabaseConnectionMetrics(active, idle, maxOpen int) {
	dbConnectionsGauge.WithLabelValues("active").Set(float64(active))
	dbConnectionsGauge.WithLabelValues("idle").Set(float64(idle))
	dbConnectionsGauge.WithLabelValues("max_open").Set(float64(maxOpen))
}