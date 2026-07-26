package metrics

import (
	"sync"
	"time"
)

type Collector struct {
	registry *Registry

	CommandCount    *Counter
	CommandErrors   *Counter
	CommandDuration *Histogram
	DeployCount     *Counter
	DeployErrors    *Counter
	HealthChecks    *Counter
	EventsEmitted   *Counter
	PluginsLoaded   *Gauge
	PluginsFailed   *Gauge
	StateComponents *Gauge
	StateHealthy    *Gauge
	StateUnhealthy  *Gauge
	GoRoutines      *Gauge
	MemoryAlloc     *Gauge
	MemorySys       *Gauge

	cmdMu     sync.Mutex
	cmdStarts map[string]time.Time
}

func NewCollector(reg *Registry) *Collector {
	return &Collector{
		registry:        reg,
		CommandCount:    reg.NewCounter("ivali_commands_total", "Total commands executed", "command"),
		CommandErrors:   reg.NewCounter("ivali_command_errors_total", "Total command errors", "command"),
		CommandDuration: reg.NewHistogram("ivali_command_duration_seconds", "Command duration in seconds", nil),
		DeployCount:     reg.NewCounter("ivali_deploys_total", "Total deploy attempts"),
		DeployErrors:    reg.NewCounter("ivali_deploy_errors_total", "Total deploy errors"),
		HealthChecks:    reg.NewCounter("ivali_health_checks_total", "Total health checks performed"),
		EventsEmitted:   reg.NewCounter("ivali_events_emitted_total", "Total events emitted", "type"),
		PluginsLoaded:   reg.NewGauge("ivali_plugins_loaded", "Number of loaded plugins"),
		PluginsFailed:   reg.NewGauge("ivali_plugins_failed", "Number of failed plugins"),
		StateComponents: reg.NewGauge("ivali_state_components", "Total registered components"),
		StateHealthy:    reg.NewGauge("ivali_state_healthy", "Healthy components"),
		StateUnhealthy:  reg.NewGauge("ivali_state_unhealthy", "Unhealthy components"),
		GoRoutines:      reg.NewGauge("ivali_goroutines", "Current number of goroutines"),
		MemoryAlloc:     reg.NewGauge("ivali_memory_alloc_bytes", "Memory allocated (bytes)"),
		MemorySys:       reg.NewGauge("ivali_memory_sys_bytes", "Memory obtained from OS (bytes)"),
		cmdStarts:       make(map[string]time.Time),
	}
}

func (c *Collector) CommandStarted(name string) {
	c.cmdMu.Lock()
	c.cmdStarts[name] = time.Now()
	c.cmdMu.Unlock()
}

func (c *Collector) CommandFinished(name string, failed bool) {
	c.CommandCount.Inc(name)
	if failed {
		c.CommandErrors.Inc(name)
	}
	c.cmdMu.Lock()
	start, ok := c.cmdStarts[name]
	delete(c.cmdStarts, name)
	c.cmdMu.Unlock()
	if ok {
		duration := time.Since(start).Seconds()
		c.CommandDuration.Observe(duration)
	}
}
