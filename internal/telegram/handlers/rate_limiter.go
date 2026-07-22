package handlers

import (
	"sync"
	"time"
)

// RateLimiter enforces a sliding-window rate limit per user.
// It tracks command timestamps in a map keyed by user ID and evicts
// entries that have fallen outside the window on each access.
type RateLimiter struct {
	mu       sync.Mutex
	windows  map[int64]*window
	maxCount int
	window   time.Duration
}

// window holds the timestamps of commands issued within the sliding window.
type window struct {
	timestamps []time.Time
}

// NewRateLimiter creates a RateLimiter that allows maxCount commands per
// user within the given sliding window duration.
func NewRateLimiter(maxCount int, windowDuration time.Duration) *RateLimiter {
	return &RateLimiter{
		windows:  make(map[int64]*window),
		maxCount: maxCount,
		window:   windowDuration,
	}
}

// NewDefaultRateLimiter creates a RateLimiter configured for 30 commands
// per minute per user, which is the production default.
func NewDefaultRateLimiter() *RateLimiter {
	return NewRateLimiter(30, time.Minute)
}

// Allow checks whether the user is within the rate limit.
// It records the current timestamp if allowed and returns true,
// or returns false without recording if the limit is exceeded.
func (rl *RateLimiter) Allow(userID int64) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	w := rl.getOrCreate(userID)
	rl.evict(w, now)

	if len(w.timestamps) >= rl.maxCount {
		return false
	}

	w.timestamps = append(w.timestamps, now)
	return true
}

// Remaining returns the number of commands the user can still issue
// within the current sliding window.
func (rl *RateLimiter) Remaining(userID int64) int {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	w := rl.getOrCreate(userID)
	rl.evict(w, now)

	remaining := rl.maxCount - len(w.timestamps)
	if remaining < 0 {
		return 0
	}
	return remaining
}

// Reset clears all rate-limit state for a specific user.
func (rl *RateLimiter) Reset(userID int64) {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	delete(rl.windows, userID)
}

// getOrCreate returns the window for a user, creating it if necessary.
func (rl *RateLimiter) getOrCreate(userID int64) *window {
	w, ok := rl.windows[userID]
	if !ok {
		w = &window{}
		rl.windows[userID] = w
	}
	return w
}

// evict removes timestamps that are older than the sliding window.
func (rl *RateLimiter) evict(w *window, now time.Time) {
	cutoff := now.Add(-rl.window)
	i := 0
	for i < len(w.timestamps) && w.timestamps[i].Before(cutoff) {
		i++
	}
	if i > 0 {
		w.timestamps = w.timestamps[i:]
	}
}
