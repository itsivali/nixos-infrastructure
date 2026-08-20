package services

import (
	"context"
	"fmt"
	"strings"
)

// MonitoringService provides monitoring and observability queries.
type MonitoringService struct {
	runner *Runner
}

// NewMonitoringService creates a new MonitoringService.
func NewMonitoringService(runner *Runner) *MonitoringService {
	return &MonitoringService{runner: runner}
}

// ServiceStatuses returns the status of monitoring services.
func (s *MonitoringService) ServiceStatuses() map[string]string {
	return s.ServiceStatusesWithContext(context.Background())
}

// ServiceStatusesWithContext returns the status of monitoring services with a parent context.
func (s *MonitoringService) ServiceStatusesWithContext(ctx context.Context) map[string]string {
	services := map[string]string{
		"prometheus": "Prometheus",
		"grafana":    "Grafana",
		"loki":       "Loki",
		"alloy":      "Alloy",
		"falco":      "Falco",
	}
	result := make(map[string]string, len(services))
	for svc := range services {
		status := strings.TrimSpace(s.runner.RunWithContext(ctx,
			fmt.Sprintf("systemctl is-active %s 2>/dev/null || echo inactive", svc), 2))
		result[svc] = status
	}
	return result
}

// PrometheusQuery queries a Prometheus instant query.
func (s *MonitoringService) PrometheusQuery(query string) string {
	return strings.TrimSpace(s.runner.Run(
		fmt.Sprintf("curl -s 'http://127.0.0.1:9090/api/v1/query?query=%s' 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null", query), 10))
}

// PrometheusServices queries Prometheus for service up/down status.
func (s *MonitoringService) PrometheusServices() string {
	return s.runner.Run(
		"curl -s 'http://127.0.0.1:9090/api/v1/query?query=up' 2>/dev/null | jq -r '.data.result[] | \"`\" + .metric.job + \"`: \" + .value[1]' 2>/dev/null || echo 'Prometheus not available'", 10)
}

// CPUUsage returns CPU usage from Prometheus.
func (s *MonitoringService) CPUUsage() string {
	return s.PrometheusQuery("100-(avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m]))*100)")
}

// MemoryUsage returns memory usage from Prometheus.
func (s *MonitoringService) MemoryUsage() string {
	return s.PrometheusQuery("(1-(node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes))*100")
}

// DiskUsage returns disk usage from Prometheus.
func (s *MonitoringService) DiskUsage() string {
	return s.PrometheusQuery("(1-(node_filesystem_avail_bytes{mountpoint=\"/\"}/node_filesystem_size_bytes{mountpoint=\"/\"}))*100")
}

// SystemLoad returns system load from Prometheus.
func (s *MonitoringService) SystemLoad() string {
	return s.PrometheusQuery("node_load1")
}
