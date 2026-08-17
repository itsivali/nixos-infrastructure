package observability

import "os"

const (
	// DefaultPrometheusPort is the default Prometheus HTTP API port.
	DefaultPrometheusPort = 9090

	// DefaultGrafanaPort is the default Grafana web UI port.
	DefaultGrafanaPort = 3000

	// DefaultLokiPort is the default Loki HTTP API port.
	DefaultLokiPort = 3100

	// DefaultNodeExporterPort is the default Prometheus Node Exporter port.
	DefaultNodeExporterPort = 9100

	// DefaultNixOSExporterPort is the default NixOS Exporter port.
	DefaultNixOSExporterPort = 9101

	// DefaultAlertmanagerPort is the default Alertmanager port.
	DefaultAlertmanagerPort = 9093
)

// PrometheusURL returns the Prometheus base URL from the environment or default.
func PrometheusURL() string {
	if v := os.Getenv("PROMETHEUS_URL"); v != "" {
		return v
	}
	return "http://127.0.0.1:9090"
}

// GrafanaURL returns the Grafana base URL from the environment or default.
func GrafanaURL() string {
	if v := os.Getenv("GRAFANA_URL"); v != "" {
		return v
	}
	return "http://127.0.0.1:3000/grafana/"
}

// LokiURL returns the Loki base URL from the environment or default.
func LokiURL() string {
	if v := os.Getenv("LOKI_URL"); v != "" {
		return v
	}
	return "http://127.0.0.1:3100"
}
