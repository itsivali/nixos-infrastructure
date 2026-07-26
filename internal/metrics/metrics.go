package metrics

import (
	"fmt"
	"net/http"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type Counter struct {
	name      string
	help      string
	labelKeys []string
	mu        sync.RWMutex
	values    map[string]int64
	total     atomic.Int64
}

type Gauge struct {
	name  string
	help  string
	value atomic.Int64
}

type Histogram struct {
	name    string
	help    string
	buckets []float64
	mu      sync.RWMutex
	counts  map[float64]int64
	total   atomic.Int64
	sum     atomic.Int64
}

type Registry struct {
	counters   map[string]*Counter
	gauges     map[string]*Gauge
	histograms map[string]*Histogram
	mu         sync.RWMutex
	startTime  time.Time
}

func NewRegistry() *Registry {
	return &Registry{
		counters:   make(map[string]*Counter),
		gauges:     make(map[string]*Gauge),
		histograms: make(map[string]*Histogram),
		startTime:  time.Now(),
	}
}

func (r *Registry) NewCounter(name, help string, labels ...string) *Counter {
	r.mu.Lock()
	defer r.mu.Unlock()
	c := &Counter{name: name, help: help, labelKeys: labels, values: make(map[string]int64)}
	r.counters[name] = c
	return c
}

func (c *Counter) Inc(labels ...string) {
	c.Add(1, labels...)
}

func (c *Counter) Add(n int64, labels ...string) {
	key := formatLabels(c.labelKeys, labels)
	c.mu.Lock()
	c.values[key] += n
	c.mu.Unlock()
	c.total.Add(n)
}

func (r *Registry) NewGauge(name, help string) *Gauge {
	r.mu.Lock()
	defer r.mu.Unlock()
	g := &Gauge{name: name, help: help}
	r.gauges[name] = g
	return g
}

func (g *Gauge) Set(v int64) {
	g.value.Store(v)
}

func (g *Gauge) Inc() {
	g.value.Add(1)
}

func (g *Gauge) Dec() {
	g.value.Add(-1)
}

func (r *Registry) NewHistogram(name, help string, buckets []float64) *Histogram {
	r.mu.Lock()
	defer r.mu.Unlock()
	if len(buckets) == 0 {
		buckets = []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10}
	}
	h := &Histogram{name: name, help: help, buckets: buckets, counts: make(map[float64]int64)}
	r.histograms[name] = h
	return h
}

func (h *Histogram) Observe(v float64) {
	h.mu.Lock()
	for _, b := range h.buckets {
		if v <= b {
			h.counts[b]++
		}
	}
	h.mu.Unlock()
	h.total.Add(1)
	h.sum.Add(int64(v * 1000))
}

func (r *Registry) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")

	r.mu.RLock()
	defer r.mu.RUnlock()

	var sb strings.Builder

	sb.WriteString("# HELP ivali_process_uptime_seconds Process uptime in seconds.\n")
	sb.WriteString("# TYPE ivali_process_uptime_seconds gauge\n")
	sb.WriteString(fmt.Sprintf("ivali_process_uptime_seconds %f\n", time.Since(r.startTime).Seconds()))

	for _, name := range sortedKeys(r.gauges) {
		g := r.gauges[name]
		sb.WriteString(fmt.Sprintf("# HELP %s %s\n", g.name, g.help))
		sb.WriteString(fmt.Sprintf("# TYPE %s gauge\n", g.name))
		sb.WriteString(fmt.Sprintf("%s %d\n", g.name, g.value.Load()))
	}

	for _, name := range sortedKeys(r.counters) {
		c := r.counters[name]
		sb.WriteString(fmt.Sprintf("# HELP %s %s\n", c.name, c.help))
		sb.WriteString(fmt.Sprintf("# TYPE %s counter\n", c.name))
		c.mu.RLock()
		if len(c.labelKeys) == 0 {
			sb.WriteString(fmt.Sprintf("%s %d\n", c.name, c.total.Load()))
		} else {
			for _, key := range sortedKeys(c.values) {
				val := c.values[key]
				sb.WriteString(fmt.Sprintf("%s{%s} %d\n", c.name, key, val))
			}
		}
		c.mu.RUnlock()
	}

	for _, name := range sortedKeys(r.histograms) {
		h := r.histograms[name]
		sb.WriteString(fmt.Sprintf("# HELP %s %s\n", h.name, h.help))
		sb.WriteString(fmt.Sprintf("# TYPE %s histogram\n", h.name))
		h.mu.RLock()
		var cumulative int64
		for _, b := range h.buckets {
			cumulative += h.counts[b]
			sb.WriteString(fmt.Sprintf("%s_bucket{le=\"%g\"} %d\n", h.name, b, cumulative))
		}
		sb.WriteString(fmt.Sprintf("%s_bucket{le=\"+Inf\"} %d\n", h.name, h.total.Load()))
		sb.WriteString(fmt.Sprintf("%s_sum %d\n", h.name, h.sum.Load()))
		sb.WriteString(fmt.Sprintf("%s_count %d\n", h.name, h.total.Load()))
		h.mu.RUnlock()
	}

	_, _ = w.Write([]byte(sb.String()))
}

func formatLabels(keys, values []string) string {
	if len(keys) == 0 {
		return ""
	}
	pairs := make([]string, 0, len(keys))
	for i, k := range keys {
		v := ""
		if i < len(values) {
			v = values[i]
		}
		pairs = append(pairs, fmt.Sprintf("%s=%q", k, v))
	}
	return strings.Join(pairs, ",")
}

func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

var DefaultRegistry = NewRegistry()
