package metrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestCounter(t *testing.T) {
	reg := NewRegistry()
	c := reg.NewCounter("test_counter", "A test counter")

	c.Inc()
	c.Inc()
	c.Add(5)

	if c.total.Load() != 7 {
		t.Errorf("expected 7, got %d", c.total.Load())
	}
}

func TestCounterWithLabels(t *testing.T) {
	reg := NewRegistry()
	c := reg.NewCounter("test_labeled", "A labeled counter", "method")

	c.Inc("GET")
	c.Inc("POST")
	c.Inc("GET")

	c.mu.RLock()
	getKey := `method="GET"`
	postKey := `method="POST"`
	if c.values[getKey] != 2 {
		t.Errorf("expected GET=2, got %d", c.values[getKey])
	}
	if c.values[postKey] != 1 {
		t.Errorf("expected POST=1, got %d", c.values[postKey])
	}
	c.mu.RUnlock()
}

func TestGauge(t *testing.T) {
	reg := NewRegistry()
	g := reg.NewGauge("test_gauge", "A test gauge")

	g.Set(42)
	if g.value.Load() != 42 {
		t.Errorf("expected 42, got %d", g.value.Load())
	}

	g.Inc()
	if g.value.Load() != 43 {
		t.Errorf("expected 43, got %d", g.value.Load())
	}

	g.Dec()
	if g.value.Load() != 42 {
		t.Errorf("expected 42, got %d", g.value.Load())
	}
}

func TestHistogram(t *testing.T) {
	reg := NewRegistry()
	h := reg.NewHistogram("test_histogram", "A test histogram", []float64{1, 5, 10})

	h.Observe(0.5)
	h.Observe(3)
	h.Observe(7)
	h.Observe(15)

	if h.total.Load() != 4 {
		t.Errorf("expected 4 observations, got %d", h.total.Load())
	}

	h.mu.RLock()
	if h.counts[1] != 1 {
		t.Errorf("expected bucket 1=1, got %d", h.counts[1])
	}
	if h.counts[5] != 2 {
		t.Errorf("expected bucket 5=2, got %d", h.counts[5])
	}
	if h.counts[10] != 3 {
		t.Errorf("expected bucket 10=3, got %d", h.counts[10])
	}
	h.mu.RUnlock()
}

func TestRegistryServeHTTP(t *testing.T) {
	reg := NewRegistry()
	reg.NewGauge("test_up", "Test gauge").Set(1)
	c := reg.NewCounter("test_requests", "Test counter", "method")
	c.Inc("GET")

	req := httptest.NewRequest("GET", "/metrics", nil)
	w := httptest.NewRecorder()

	reg.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	body := w.Body.String()
	if !strings.Contains(body, "ivali_process_uptime_seconds") {
		t.Error("missing uptime metric")
	}
	if !strings.Contains(body, "test_up 1") {
		t.Error("missing test_up gauge")
	}
	if !strings.Contains(body, `test_requests{method="GET"} 1`) {
		t.Error("missing test_requests counter with labels")
	}
}

func TestCollector(t *testing.T) {
	reg := NewRegistry()
	collector := NewCollector(reg)

	collector.CommandStarted("test")
	time.Sleep(10 * time.Millisecond)
	collector.CommandFinished("test", false)

	collector.CommandCount.mu.RLock()
	testKey := `command="test"`
	if collector.CommandCount.values[testKey] != 1 {
		t.Errorf("expected 1 command, got %d", collector.CommandCount.values[testKey])
	}
	collector.CommandCount.mu.RUnlock()

	collector.CommandStarted("fail_cmd")
	collector.CommandFinished("fail_cmd", true)

	collector.CommandErrors.mu.RLock()
	failKey := `command="fail_cmd"`
	if collector.CommandErrors.values[failKey] != 1 {
		t.Errorf("expected 1 error, got %d", collector.CommandErrors.values[failKey])
	}
	collector.CommandErrors.mu.RUnlock()
}

func TestServer(t *testing.T) {
	srv := NewServer(":0")
	if srv.Collector() == nil {
		t.Error("expected non-nil collector")
	}
}
