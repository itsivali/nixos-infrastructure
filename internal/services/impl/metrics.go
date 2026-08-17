package impl

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/services"
)

// PrometheusMetrics implements services.MetricsProvider by querying a local
// Prometheus HTTP API. It replaces the curl-to-Prometheus pattern used in
// TelegramServices.MonitoringService.
type PrometheusMetrics struct {
	endpoint string // e.g. http://127.0.0.1:9090
	client   *http.Client
}

// NewPrometheusMetrics creates a metrics provider targeting the given Prometheus endpoint.
func NewPrometheusMetrics(endpoint string) *PrometheusMetrics {
	return &PrometheusMetrics{
		endpoint: strings.TrimRight(endpoint, "/"),
		client:   &http.Client{Timeout: 10 * time.Second},
	}
}

type promResponse struct {
	Status string `json:"status"`
	Data   struct {
		ResultType string        `json:"resultType"`
		Result     []interface{} `json:"result"`
	} `json:"data"`
}

func (p *PrometheusMetrics) Query(ctx context.Context, promQL string) (float64, error) {
	req, err := http.NewRequestWithContext(ctx, "GET",
		p.endpoint+"/api/v1/query", nil)
	if err != nil {
		return 0, fmt.Errorf("build request: %w", err)
	}
	q := req.URL.Query()
	q.Set("query", promQL)
	req.URL.RawQuery = q.Encode()

	resp, err := p.client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("prometheus query: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	var pr promResponse
	if err := json.Unmarshal(body, &pr); err != nil {
		return 0, fmt.Errorf("parse response: %w", err)
	}
	if pr.Status != "success" {
		return 0, fmt.Errorf("prometheus returned status %s", pr.Status)
	}
	if len(pr.Data.Result) == 0 {
		return 0, fmt.Errorf("no results for query: %s", promQL)
	}

	// Extract scalar value from first result
	if vec, ok := pr.Data.Result[0].([]interface{}); ok && len(vec) >= 2 {
		if valStr, ok := vec[1].(string); ok {
			return strconv.ParseFloat(valStr, 64)
		}
	}
	return 0, fmt.Errorf("unexpected result format")
}

func (p *PrometheusMetrics) ServiceStatuses(ctx context.Context) (map[string]services.ServiceHealth, error) {
	services_list := []string{"ivali-bot", "prometheus", "grafana", "loki"}
	result := make(map[string]services.ServiceHealth, len(services_list))

	for _, name := range services_list {
		query := fmt.Sprintf(`up{job="%s"}`, name)
		val, err := p.Query(ctx, query)
		health := services.ServiceHealth{Name: name}
		if err != nil {
			health.Healthy = false
			health.Message = err.Error()
		} else {
			health.Healthy = val > 0
			if health.Healthy {
				health.Message = "up"
			} else {
				health.Message = "down"
			}
		}
		result[name] = health
	}
	return result, nil
}

func (p *PrometheusMetrics) SystemMetrics(ctx context.Context) (*services.SystemMetrics, error) {
	m := &services.SystemMetrics{}

	queries := map[string]*float64{
		`100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`:                                       &m.CPUPercent,
		`100 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100)`:                              &m.MemoryPercent,
		`100 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100)`: &m.DiskPercent,
	}

	for q, target := range queries {
		if val, err := p.Query(ctx, q); err == nil {
			*target = val
		}
	}

	// Load average via /proc
	if out, err := exec.Command("cat", "/proc/loadavg").Output(); err == nil {
		fields := strings.Fields(string(out))
		for i := 0; i < 3 && i < len(fields); i++ {
			if v, err := strconv.ParseFloat(fields[i], 64); err == nil {
				m.LoadAverage[i] = v
			}
		}
	}

	// Uptime
	if out, err := exec.Command("cat", "/proc/uptime").Output(); err == nil {
		fields := strings.Fields(string(out))
		if len(fields) > 0 {
			if v, err := strconv.ParseFloat(fields[0], 64); err == nil {
				m.UptimeSeconds = int64(v)
			}
		}
	}

	return m, nil
}
