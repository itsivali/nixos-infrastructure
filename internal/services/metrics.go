package services

import "context"

// MetricsProvider defines the interface for querying observability backends.
// This replaces the curl-to-Prometheus pattern in MonitoringService.
type MetricsProvider interface {
	// Query executes a PromQL query and returns a single scalar result.
	Query(ctx context.Context, promQL string) (float64, error)

	// ServiceStatuses returns the health status of all monitored services.
	ServiceStatuses(ctx context.Context) (map[string]ServiceHealth, error)

	// SystemMetrics returns current system resource metrics.
	SystemMetrics(ctx context.Context) (*SystemMetrics, error)
}

// ServiceHealth represents the health of a single service.
type ServiceHealth struct {
	Name    string
	Healthy bool
	Message string
}

// SystemMetrics contains current system resource usage.
type SystemMetrics struct {
	CPUPercent    float64
	MemoryPercent float64
	DiskPercent   float64
	LoadAverage   [3]float64
	UptimeSeconds int64
}
