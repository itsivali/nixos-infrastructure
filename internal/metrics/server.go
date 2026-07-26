package metrics

import (
	"context"
	"fmt"
	"net/http"
	"runtime"
	"time"
)

type Server struct {
	registry  *Registry
	collector *Collector
	server    *http.Server
}

func NewServer(addr string) *Server {
	reg := NewRegistry()
	collector := NewCollector(reg)

	mux := http.NewServeMux()
	mux.Handle("/metrics", reg)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"healthy"}`))
	})

	return &Server{
		registry:  reg,
		collector: collector,
		server: &http.Server{
			Addr:    addr,
			Handler: mux,
		},
	}
}

func (s *Server) Collector() *Collector {
	return s.collector
}

func (s *Server) Start() error {
	go s.updateRuntimeMetrics()
	return s.server.ListenAndServe()
}

func (s *Server) Shutdown(ctx context.Context) error {
	return s.server.Shutdown(ctx)
}

func (s *Server) updateRuntimeMetrics() {
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		var memStats runtime.MemStats
		runtime.ReadMemStats(&memStats)
		s.collector.MemoryAlloc.Set(int64(memStats.Alloc))
		s.collector.MemorySys.Set(int64(memStats.Sys))
		s.collector.GoRoutines.Set(int64(runtime.NumGoroutine()))
	}
}

func Start(addr string) (*Server, error) {
	srv := NewServer(addr)
	if err := srv.Start(); err != nil {
		return nil, fmt.Errorf("starting metrics server: %w", err)
	}
	return srv, nil
}
