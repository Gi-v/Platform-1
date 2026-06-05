package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// ── Prometheus metrics ───────────────────────────────────────────────────────
var (
	httpRequests = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total HTTP requests",
	}, []string{"method", "path", "status"})

	httpDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "HTTP request duration",
		Buckets: prometheus.DefBuckets,
	}, []string{"method", "path"})
)

// ── Models ───────────────────────────────────────────────────────────────────
type Item struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}

type Response struct {
	Data    any    `json:"data,omitempty"`
	Error   string `json:"error,omitempty"`
	Message string `json:"message,omitempty"`
}

// ── In-memory store (replace with DB in prod) ────────────────────────────────
var store = map[string]*Item{
	"1": {ID: "1", Name: "example-item", CreatedAt: time.Now()},
}

// ── Handlers ─────────────────────────────────────────────────────────────────
func healthz(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]string{"status": "ok", "service": serviceName()})
}

func readyz(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]string{"status": "ready"})
}

func listItems(w http.ResponseWriter, r *http.Request) {
	items := make([]*Item, 0, len(store))
	for _, v := range store {
		items = append(items, v)
	}
	json.NewEncoder(w).Encode(Response{Data: items})
}

func createItem(w http.ResponseWriter, r *http.Request) {
	var item Item
	if err := json.NewDecoder(r.Body).Decode(&item); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(Response{Error: "invalid json"})
		return
	}
	item.ID = fmt.Sprintf("%d", time.Now().UnixNano())
	item.CreatedAt = time.Now()
	store[item.ID] = &item
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(Response{Data: item, Message: "created"})
}

// ── Middleware ────────────────────────────────────────────────────────────────
func instrument(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &statusWriter{w, http.StatusOK}
		next(rw, r)
		dur := time.Since(start).Seconds()
		status := fmt.Sprintf("%d", rw.status)
		httpRequests.WithLabelValues(r.Method, r.URL.Path, status).Inc()
		httpDuration.WithLabelValues(r.Method, r.URL.Path).Observe(dur)
	}
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (s *statusWriter) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

func jsonMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("X-Service", serviceName())
		next(w, r)
	}
}

func chain(h http.HandlerFunc, mw ...func(http.HandlerFunc) http.HandlerFunc) http.HandlerFunc {
	for i := len(mw) - 1; i >= 0; i-- {
		h = mw[i](h)
	}
	return h
}

func serviceName() string {
	if n := os.Getenv("SERVICE_NAME"); n != "" {
		return n
	}
	return "microservice"
}

// ── Main ─────────────────────────────────────────────────────────────────────
func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", chain(healthz, jsonMiddleware, instrument))
	mux.HandleFunc("/readyz",  chain(readyz,  jsonMiddleware, instrument))
	mux.HandleFunc("/metrics", promhttp.Handler().ServeHTTP)
	mux.HandleFunc("/api/items",     chain(listItems,   jsonMiddleware, instrument))
	mux.HandleFunc("/api/items/new", chain(createItem,  jsonMiddleware, instrument))

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		slog.Info("server started", "port", port, "service", serviceName())
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "err", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	slog.Info("shutting down gracefully")

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("shutdown error", "err", err)
	}
}
